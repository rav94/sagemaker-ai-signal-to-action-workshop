#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Called after deploy.sh verifies the account and publishes the release assets.
group="$1"
version="$2"
image_uri="$3"
model_uri="$4"
instance_type="$5"

aws cloudformation deploy --template-file registry.yaml --stack-name "$group" \
  --no-fail-on-empty-changeset >&2

request=$(python3 - "$group" "$version" "$image_uri" "$model_uri" "$instance_type" <<'PY'
import json
import sys
import uuid

group, version, image_uri, model_uri, instance_type = sys.argv[1:]
print(json.dumps({
    "ModelPackageGroupName": group,
    "ModelPackageDescription": f"Workshop release {version}",
    "ModelApprovalStatus": "PendingManualApproval",
    "SkipModelValidation": "All",
    "ClientToken": str(uuid.uuid5(uuid.NAMESPACE_URL, f"{group}/{version}/{image_uri}/{model_uri}/{instance_type}")),
    "CustomerMetadataProperties": {"ReleaseVersion": version},
    "InferenceSpecification": {
        "Containers": [{"Image": image_uri, "ModelDataUrl": model_uri}],
        "SupportedContentTypes": ["application/json"],
        "SupportedResponseMIMETypes": ["application/json"],
        "SupportedRealtimeInferenceInstanceTypes": [instance_type],
    },
}))
PY
)

aws sagemaker create-model-package --cli-input-json "$request" \
  --query ModelPackageArn --output text
