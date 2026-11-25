#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

usage="Usage: bash scripts/deploy.sh MODEL_VERSION [--cloud-train] [--register-only]"
version="${1:?${usage}}"
shift
training_mode=local
register_only=false
for option in "$@"; do
  case "$option" in
    --cloud-train) training_mode=cloud ;;
    --register-only) register_only=true ;;
    *) echo "$usage" >&2; exit 2 ;;
  esac
done
: "${AWS_PROFILE:?Set AWS_PROFILE to the teaching sandbox profile}"
: "${AWS_REGION:?Set AWS_REGION to the teaching sandbox Region}"
: "${WORKSHOP_ACCOUNT_ID:?Set WORKSHOP_ACCOUNT_ID to the approved teaching account ID}"
export AWS_PAGER=""

stack="${WORKSHOP_STACK:-sagemaker-ai-signal-insight-action-workshop}"
storage_stack="${stack}-assets"
registry_stack="${stack}-registry"
instance_type="${WORKSHOP_INSTANCE_TYPE:-ml.t2.medium}"

if [[ ! "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$ ]]; then
  echo "Use a release version of at most 121 letters, digits, dots, underscores or hyphens, starting with a letter or digit." >&2
  exit 2
fi

if [[ "$register_only" == true && "${#registry_stack}" -gt 63 ]]; then
  echo "Choose WORKSHOP_STACK of at most 54 characters for the registry path." >&2
  exit 2
fi

account=$(aws sts get-caller-identity --query Account --output text)
if [[ "$account" != "$WORKSHOP_ACCOUNT_ID" ]]; then
  echo "AWS caller account does not match the approved teaching account." >&2
  exit 2
fi

docker info >/dev/null

if [[ "$training_mode" == local ]]; then
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
if [[ "$training_mode" == cloud ]]; then
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
  archive="${WORKSHOP_MODEL_DIR:-artifacts}/model.tar.gz"
  artifact_digest=$(shasum -a 256 "$archive" | cut -d ' ' -f 1)
  artifact_key="models/$version/$artifact_digest/model.tar.gz"
  aws s3 cp "$archive" "s3://$bucket/$artifact_key"
fi

printf 'Published image: %s\nPublished model: s3://%s/%s\n' "$image_uri" "$bucket" "$artifact_key"

if [[ "$register_only" == true ]]; then
  package_arn=$(bash scripts/register-model.sh "$registry_stack" "$version" \
    "$image_uri" "s3://$bucket/$artifact_key" "$instance_type")
  if [[ "$package_arn" != arn:*:sagemaker:"$AWS_REGION":"$account":model-package/"$registry_stack/"* ]]; then
    echo "Unexpected registered model package ARN: $package_arn" >&2
    exit 1
  fi
  printf 'Model package ARN: %s\nApproval: PendingManualApproval\n' "$package_arn"
  exit 0
fi

source scripts/lib/deploy-endpoint.sh
deploy_workshop_endpoint "$stack" "$bucket" "$artifact_key" "$image_uri" "$repository_name" "$instance_type"
