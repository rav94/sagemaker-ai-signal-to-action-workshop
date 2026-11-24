#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$#" != 2 ]]; then
  echo "Usage: bash scripts/guarded-update.sh CANDIDATE_VERSION LATENCY_THRESHOLD_US" >&2
  exit 2
fi
version="$1"
threshold="$2"
if [[ ! "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$ || ! "$threshold" =~ ^[1-9][0-9]*$ ]]; then
  echo "Provide a valid release version and a positive latency threshold in microseconds." >&2
  exit 2
fi

: "${AWS_PROFILE:?Set AWS_PROFILE to the teaching sandbox profile}"
: "${AWS_REGION:?Set AWS_REGION to the teaching sandbox Region}"
: "${WORKSHOP_ACCOUNT_ID:?Set WORKSHOP_ACCOUNT_ID to the approved teaching account ID}"
: "${WORKSHOP_STACK:?Set WORKSHOP_STACK to the existing workshop serving stack name}"
export AWS_PAGER=""

account=$(aws sts get-caller-identity --query Account --output text)
if [[ "$account" != "$WORKSHOP_ACCOUNT_ID" ]]; then
  echo "AWS caller account does not match the approved teaching account." >&2
  exit 2
fi

stack_parameter() {
  aws cloudformation describe-stacks --stack-name "$WORKSHOP_STACK" \
    --query "Stacks[0].Parameters[?ParameterKey=='$1'].ParameterValue | [0]" --output text
}

endpoint=$(aws cloudformation describe-stacks --stack-name "$WORKSHOP_STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='EndpointName'].OutputValue | [0]" --output text)
if [[ "$endpoint" != "$WORKSHOP_STACK" ]]; then
  echo "The selected stack must be the workshop serving stack." >&2
  exit 2
fi

endpoint_details=$(aws sagemaker describe-endpoint --endpoint-name "$endpoint" \
  --query '[EndpointStatus,EndpointConfigName]' --output text)
IFS=$'\t' read -r endpoint_status baseline_config <<< "$endpoint_details"
if [[ "$endpoint_status" != InService || -z "$baseline_config" ]]; then
  echo "The baseline endpoint must be InService before the guarded update." >&2
  exit 2
fi

bucket=$(stack_parameter ArtifactBucket)
baseline_key=$(stack_parameter ArtifactKey)
image_uri=$(stack_parameter ImageUri)
repository_name=$(stack_parameter ImageRepositoryName)
instance_type=$(stack_parameter InstanceType)
if [[ -z "$bucket" || "$bucket" == None || -z "$baseline_key" || "$baseline_key" == None ||
      "$image_uri" != *@sha256:* || -z "$repository_name" || "$repository_name" == None ||
      -z "$instance_type" || "$instance_type" == None ]]; then
  echo "The selected stack is missing the workshop deployment parameters." >&2
  exit 2
fi
if [[ "$baseline_key" == "models/$version/"* ]]; then
  echo "Choose a candidate version different from the baseline version." >&2
  exit 2
fi

model_dir=$(mktemp -d "${TMPDIR:-/tmp}/workshop-candidate.XXXXXX")
trap 'rm -rf -- "$model_dir"' EXIT
WORKSHOP_MODEL_DIR="$model_dir" bash scripts/package-model.sh "$version"
artifact_digest=$(shasum -a 256 "$model_dir/model.tar.gz" | cut -d ' ' -f 1)
candidate_key="models/$version/$artifact_digest/model.tar.gz"
aws s3 cp "$model_dir/model.tar.gz" "s3://$bucket/$candidate_key"

printf 'Baseline endpoint configuration: %s\nCandidate version: %s\nRollback alarm: %s-candidate-model-latency\n' \
  "$baseline_config" "$version" "$WORKSHOP_STACK"

deployment_exit=0
aws cloudformation deploy --template-file template.yaml --stack-name "$WORKSHOP_STACK" \
  --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset \
  --parameter-overrides "ArtifactBucket=$bucket" "ArtifactKey=$candidate_key" \
  "ImageUri=$image_uri" "ImageRepositoryName=$repository_name" "InstanceType=$instance_type" \
  EnableDeploymentGuardrails=true "RollbackArtifactKey=$baseline_key" \
  "RollbackLatencyThresholdUs=$threshold" || deployment_exit=$?

aws sagemaker describe-endpoint --endpoint-name "$endpoint" \
  --query '{Status:EndpointStatus,Config:EndpointConfigName,Failure:FailureReason}' --output table
if [[ "$deployment_exit" != 0 ]]; then
  echo "The update failed. Check stack events and alarm history, then compare the endpoint to the baseline configuration printed above." >&2
fi
exit "$deployment_exit"
