#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$#" != 1 || ! "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$ ]]; then
  echo "Usage: bash scripts/deploy.sh RELEASE_VERSION" >&2
  exit 2
fi
version="$1"
: "${AWS_PROFILE:?Set AWS_PROFILE to the teaching sandbox profile}"
: "${AWS_REGION:?Set AWS_REGION to the teaching sandbox Region}"
: "${WORKSHOP_ACCOUNT_ID:?Set WORKSHOP_ACCOUNT_ID to the approved teaching account ID}"
export AWS_PAGER=""

stack="${WORKSHOP_STACK:-sagemaker-ai-signal-insight-action-workshop}"
if [[ ! "$stack" =~ ^[A-Za-z][A-Za-z0-9-]{0,53}$ ]]; then
  echo "Choose a CloudFormation base stack name of at most 54 characters." >&2
  exit 2
fi
assets_stack="$stack-assets"
registry_stack="$stack-registry"
pipeline_stack="$stack-pipeline"
studio_stack="$stack-studio"

account=$(aws sts get-caller-identity --query Account --output text)
if [[ "$account" != "$WORKSHOP_ACCOUNT_ID" ]]; then
  echo "AWS caller account does not match the approved teaching account." >&2
  exit 2
fi
docker info >/dev/null

# Provision the artifact bucket before granting Studio access to evaluation reports.
aws cloudformation deploy --template-file bootstrap.yaml --stack-name "$assets_stack" \
  --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset

asset_output() {
  aws cloudformation describe-stacks --stack-name "$assets_stack" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue | [0]" --output text
}

bucket=$(asset_output ArtifactBucket)
repository_uri=$(asset_output ImageRepositoryUri)
repository_name="${repository_uri#*/}"
job_role=$(asset_output TrainingRoleArn)
aws cloudformation deploy --template-file studio.yaml --stack-name "$studio_stack" \
  --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset \
  --parameter-overrides "WorkshopStackName=$stack" "ArtifactBucket=$bucket"
aws ecr get-login-password | docker login --username AWS --password-stdin "${repository_uri%%/*}"

publish_image() {
  local target="$1" tag="$2" digest
  docker build --platform linux/amd64 --provenance=false --sbom=false \
    --target "$target" -t "$repository_uri:$tag" . >&2 || return
  docker push "$repository_uri:$tag" >&2 || return
  digest=$(aws ecr describe-images --repository-name "$repository_name" \
    --image-ids "imageTag=$tag" --query 'imageDetails[0].imageDigest' --output text) || return
  printf '%s@%s\n' "$repository_uri" "$digest"
}
training_image=$(publish_image training "train-$version")
serving_image=$(publish_image serving "serve-$version")

# Publish the immutable inputs and install the native SageMaker graph.
definition=$(mktemp "${TMPDIR:-/tmp}/workshop-pipeline.XXXXXX")
trap 'rm -f -- "$definition"' EXIT
data_digest=$(shasum -a 256 data/complaints.csv | cut -d ' ' -f 1)
data_uri="s3://$bucket/training-data/$data_digest/complaints.csv"
python3 scripts/pipeline-definition.py "$bucket" "$data_uri" "$training_image" \
  "$serving_image" "$job_role" "$registry_stack" "$version" \
  "${WORKSHOP_TRAINING_INSTANCE_TYPE:-ml.t3.large}" \
  "${WORKSHOP_EVALUATION_INSTANCE_TYPE:-ml.t3.medium}" \
  "${WORKSHOP_INSTANCE_TYPE:-ml.t2.medium}" > "$definition"
definition_digest=$(shasum -a 256 "$definition" | cut -d ' ' -f 1)
definition_key="pipelines/$version/$definition_digest.json"
aws s3 cp data/complaints.csv "$data_uri"
aws s3 cp "$definition" "s3://$bucket/$definition_key"
aws cloudformation deploy --template-file registry.yaml --stack-name "$registry_stack" \
  --no-fail-on-empty-changeset
aws cloudformation deploy --template-file pipeline.yaml --stack-name "$pipeline_stack" \
  --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset \
  --parameter-overrides "ArtifactBucket=$bucket" "DefinitionKey=$definition_key" \
  "JobRoleArn=$job_role" "PackageGroup=$registry_stack" "ImageRepositoryName=$repository_name"

printf 'Studio domain: %s\nStudio profile: workshop-instructor\nPipeline: %s\n' \
  "$studio_stack" "$pipeline_stack"
aws sagemaker start-pipeline-execution --pipeline-name "$pipeline_stack" \
  --pipeline-execution-description "Workshop candidate $version" \
  --query PipelineExecutionArn --output text
