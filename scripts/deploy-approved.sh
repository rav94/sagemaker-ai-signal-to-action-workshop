#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$#" != 1 ]]; then
  echo "Usage: bash scripts/deploy-approved.sh MODEL_PACKAGE_ARN" >&2
  exit 2
fi
package_arn="$1"
: "${AWS_REGION:?Set AWS_REGION to the teaching sandbox Region}"
: "${WORKSHOP_ACCOUNT_ID:?Set WORKSHOP_ACCOUNT_ID to the approved teaching account ID}"
export AWS_PAGER=""

stack="${WORKSHOP_STACK:-sagemaker-ai-signal-insight-action-workshop}"
registry_group="${stack}-registry"

account=$(aws sts get-caller-identity --query Account --output text)
if [[ "$account" != "$WORKSHOP_ACCOUNT_ID" ]]; then
  echo "AWS caller account does not match the approved teaching account." >&2
  exit 2
fi
package_number="${package_arn##*/}"
if [[ ! "$package_number" =~ ^[1-9][0-9]*$ ||
      "$package_arn" != arn:*:sagemaker:"$AWS_REGION":"$account":model-package/"$registry_group/$package_number" ]]; then
  echo "Use a versioned package ARN from the workshop model group in this account and Region." >&2
  exit 2
fi

release=$(aws sagemaker describe-model-package --model-package-name "$package_arn" \
  --query '[ModelApprovalStatus,ModelPackageStatus,InferenceSpecification.Containers[0].Image,InferenceSpecification.Containers[0].ModelDataUrl,CustomerMetadataProperties.ReleaseVersion,InferenceSpecification.SupportedRealtimeInferenceInstanceTypes[0]]' \
  --output text)
IFS=$'\t' read -r approval status image_uri model_uri version instance_type <<< "$release"
if [[ "$approval" != Approved || "$status" != Completed ]]; then
  printf 'Deployment blocked. The package must be Approved and Completed. Found approval=%s, status=%s.\n' \
    "$approval" "$status" >&2
  exit 3
fi

asset_output() {
  aws cloudformation describe-stacks --stack-name "${stack}-assets" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue | [0]" --output text
}
bucket=$(asset_output ArtifactBucket)
repository_uri=$(asset_output ImageRepositoryUri)
digest="${image_uri##*@sha256:}"
if [[ "$bucket" == None || -z "$bucket" || "$repository_uri" == None || -z "$repository_uri" ||
      "$image_uri" != "$repository_uri@sha256:"* || ! "$digest" =~ ^[0-9a-f]{64}$ ||
      "$model_uri" != "s3://$bucket/"*/model.tar.gz ||
      ! "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$ || ! "$instance_type" =~ ^ml\.[a-z0-9]+\.[a-z0-9]+$ ]]; then
  echo "Package is missing a release version, serving type, or pinned asset from this workshop." >&2
  exit 2
fi

printf 'Approved package: %s\nServing image: %s\nModel artifact: %s\n' "$package_arn" "$image_uri" "$model_uri"
source scripts/lib/deploy-endpoint.sh
deploy_workshop_endpoint "$stack" "$bucket" "${model_uri#s3://"$bucket"/}" \
  "$image_uri" "${repository_uri#*/}" "$instance_type"

result=$(mktemp "${TMPDIR:-/tmp}/workshop-approved-insight.XXXXXX")
trap 'rm -f -- "$result"' EXIT
aws sagemaker-runtime invoke-endpoint --endpoint-name "$stack" \
  --content-type application/json --body fileb://events/complaint.json "$result" >/dev/null
python3 - "$result" "$version" <<'PY'
import json
import sys
from pathlib import Path

result, version = sys.argv[1:]
insight = json.loads(Path(result).read_text())
if insight.get("modelVersion") != version:
    raise SystemExit(f"Smoke test expected modelVersion={version}, received {insight.get('modelVersion')}")
print(json.dumps(insight))
PY
