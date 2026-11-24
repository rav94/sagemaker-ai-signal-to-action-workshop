#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

usage="Usage: bash scripts/deploy.sh MODEL_VERSION [--cloud-train]"
version="${1:?${usage}}"
training_mode="${2:-}"
if [[ "$#" -gt 2 || ( -n "$training_mode" && "$training_mode" != --cloud-train ) ]]; then
  echo "$usage" >&2
  exit 2
fi
: "${AWS_PROFILE:?Set AWS_PROFILE to the teaching sandbox profile}"
: "${AWS_REGION:?Set AWS_REGION to the teaching sandbox Region}"
: "${WORKSHOP_ACCOUNT_ID:?Set WORKSHOP_ACCOUNT_ID to the approved teaching account ID}"
export AWS_PAGER=""

stack="${WORKSHOP_STACK:-moratuwa-complaint-sagemaker}"
storage_stack="${stack}-assets"
instance_type="${WORKSHOP_INSTANCE_TYPE:-ml.m5.large}"

if [[ ! "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$ ]]; then
  echo "Use a release version of at most 121 letters, digits, dots, underscores or hyphens, starting with a letter or digit." >&2
  exit 2
fi

account=$(aws sts get-caller-identity --query Account --output text)
if [[ "$account" != "$WORKSHOP_ACCOUNT_ID" ]]; then
  echo "AWS caller account does not match the approved teaching account." >&2
  exit 2
fi

docker info >/dev/null

if [[ "$training_mode" != --cloud-train ]]; then
  bash scripts/package-model.sh "$version"
fi

aws cloudformation deploy --template-file bootstrap.yaml \
  --stack-name "$storage_stack" --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset

stack_output() {
  aws cloudformation describe-stacks --stack-name "$storage_stack" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue | [0]" --output text
}

bucket=$(stack_output ArtifactBucket)
repository_uri=$(stack_output ImageRepositoryUri)
repository_name="${repository_uri#*/}"

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

image_uri=$(publish_image serving "serve-$version")
if [[ "$training_mode" == --cloud-train ]]; then
  training_image_uri=$(publish_image training "train-$version")
  training_role_arn=$(stack_output TrainingRoleArn)
  artifact_uri=$(bash scripts/train-cloud.sh "$version" "$stack" "$bucket" \
    "$training_image_uri" "$training_role_arn")
  if [[ "$artifact_uri" != "s3://$bucket/training-output/"* ]]; then
    echo "Unexpected training artifact location: $artifact_uri" >&2
    exit 1
  fi
  artifact_key="${artifact_uri#s3://$bucket/}"
else
  artifact_digest=$(shasum -a 256 artifacts/model.tar.gz | cut -d ' ' -f 1)
  artifact_key="models/$version/$artifact_digest/model.tar.gz"
  aws s3 cp artifacts/model.tar.gz "s3://$bucket/$artifact_key"
fi

printf 'Published image: %s\nPublished model: s3://%s/%s\n' "$image_uri" "$bucket" "$artifact_key"

aws cloudformation deploy --template-file template.yaml --stack-name "$stack" \
  --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset \
  --parameter-overrides "ArtifactBucket=$bucket" "ArtifactKey=$artifact_key" \
  "ImageUri=$image_uri" "ImageRepositoryName=$repository_name" \
  "InstanceType=$instance_type" EnableDeploymentGuardrails=false

aws sagemaker describe-endpoint --endpoint-name "$stack" \
  --query '{Endpoint:EndpointName,Status:EndpointStatus}' --output table
