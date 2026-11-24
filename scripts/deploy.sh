#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?Usage: bash scripts/deploy.sh MODEL_VERSION}"
: "${AWS_PROFILE:?Set AWS_PROFILE to the teaching sandbox profile}"
: "${AWS_REGION:?Set AWS_REGION to the teaching sandbox Region}"
: "${WORKSHOP_ACCOUNT_ID:?Set WORKSHOP_ACCOUNT_ID to the approved teaching account ID}"
export AWS_PAGER=""

stack="${WORKSHOP_STACK:-moratuwa-complaint-sagemaker}"
storage_stack="${stack}-assets"
instance_type="${WORKSHOP_INSTANCE_TYPE:-ml.m5.large}"

if [[ ! "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,126}$ ]]; then
  echo "Use a valid ECR release tag of at most 127 characters." >&2
  exit 2
fi

account=$(aws sts get-caller-identity --query Account --output text)
if [[ "$account" != "$WORKSHOP_ACCOUNT_ID" ]]; then
  echo "AWS caller account does not match the approved teaching account." >&2
  exit 2
fi

bash scripts/package-model.sh "$version"
docker build --platform linux/amd64 --provenance=false --sbom=false \
  -t "complaint-workshop:$version" .

aws cloudformation deploy --template-file bootstrap.yaml \
  --stack-name "$storage_stack" --no-fail-on-empty-changeset

stack_output() {
  aws cloudformation describe-stacks --stack-name "$storage_stack" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue | [0]" --output text
}

bucket=$(stack_output ArtifactBucket)
repository_uri=$(stack_output ImageRepositoryUri)
repository_name="${repository_uri#*/}"
image_tag="$repository_uri:$version"

aws ecr get-login-password | docker login --username AWS --password-stdin "${repository_uri%%/*}"
docker tag "complaint-workshop:$version" "$image_tag"
docker push "$image_tag"
digest=$(aws ecr describe-images --repository-name "$repository_name" \
  --image-ids "imageTag=$version" --query 'imageDetails[0].imageDigest' --output text)

artifact_digest=$(shasum -a 256 artifacts/model.tar.gz | cut -d ' ' -f 1)
artifact_key="models/$version/$artifact_digest/model.tar.gz"
aws s3 cp artifacts/model.tar.gz "s3://$bucket/$artifact_key"
printf 'Published image: %s@%s\nPublished model: s3://%s/%s\n' \
  "$repository_uri" "$digest" "$bucket" "$artifact_key"

aws cloudformation deploy --template-file template.yaml --stack-name "$stack" \
  --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset \
  --parameter-overrides "ArtifactBucket=$bucket" "ArtifactKey=$artifact_key" \
  "ImageUri=$repository_uri@$digest" "ImageRepositoryName=$repository_name" \
  "InstanceType=$instance_type"

aws sagemaker describe-endpoint --endpoint-name "$stack" \
  --query '{Endpoint:EndpointName,Status:EndpointStatus}' --output table
