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
      "$model_uri" != "s3://$bucket/training-output/"*/model.tar.gz ||
      ! "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$ || ! "$instance_type" =~ ^ml\.[a-z0-9]+\.[a-z0-9]+$ ]]; then
  echo "Package is missing a release version, serving type, or pinned asset from this workshop." >&2
  exit 2
fi

printf 'Approved package: %s\nServing image: %s\nModel artifact: %s\n' "$package_arn" "$image_uri" "$model_uri"
artifact_key="${model_uri#s3://"$bucket"/}"

watch_stack_status() {
  local status previous=""
  while :; do
    if status=$(aws cloudformation describe-stacks --stack-name "$stack" \
        --cli-connect-timeout 5 --cli-read-timeout 5 --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null) && [[ -n "$status" && "$status" != "$previous" ]]; then
      printf 'CloudFormation stack status: %s\n' "$status" >&2
      previous="$status"
    fi
    sleep 10 </dev/null >/dev/null 2>&1
  done
}

stop_stack_watch() {
  if [[ -n "$stack_watch_pid" ]]; then
    kill "$stack_watch_pid" 2>/dev/null || true
    wait "$stack_watch_pid" 2>/dev/null || true
    stack_watch_pid=""
  fi
}

deploy_endpoint() {
  local deploy_status=0
  if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
    watch_stack_status &
    stack_watch_pid=$!
  fi
  aws cloudformation deploy --template-file template.yaml --stack-name "$stack" \
    --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset \
    --parameter-overrides "ArtifactBucket=$bucket" "ArtifactKey=$artifact_key" \
    "ImageUri=$image_uri" "ImageRepositoryName=${repository_uri#*/}" "InstanceType=$instance_type" \
    "ExistingModelExecutionRoleArn=${AWS_MODEL_EXECUTION_ROLE_ARN:-}" "$@" || deploy_status=$?
  stop_stack_watch
  return "$deploy_status"
}

scratch=$(mktemp -d "${TMPDIR:-/tmp}/workshop-approved.XXXXXX")
probe_pid=""
stack_watch_pid=""
stop_probes() {
  if [[ -n "$probe_pid" ]]; then
    kill "$probe_pid" 2>/dev/null || true
    wait "$probe_pid" 2>/dev/null || true
    probe_pid=""
  fi
}
cleanup() {
  stop_stack_watch
  stop_probes
  rm -rf -- "$scratch"
}
trap cleanup EXIT

invoke() {
  aws sagemaker-runtime invoke-endpoint --endpoint-name "$stack" \
    --cli-connect-timeout 5 --cli-read-timeout 10 \
    --content-type application/json --body fileb://events/complaint.json "$1" >/dev/null
}

verify_release() {
  invoke "$scratch/insight.json"
  python3 - "$scratch/insight.json" "$1" <<'PY'
import json
import sys
from pathlib import Path

result, expected = sys.argv[1:]
insight = json.loads(Path(result).read_text())
if insight.get("modelVersion") != expected:
    raise SystemExit(f"Smoke test expected modelVersion={expected}, received {insight.get('modelVersion')}")
print(json.dumps(insight))
PY
}

if [[ "${WORKSHOP_ROLLBACK_DEMO:-false}" != true ]]; then
  deploy_endpoint EnableDeploymentGuardrails=false RollbackArtifactKey= || {
    aws cloudformation describe-stack-events --stack-name "$stack" --max-items 30 \
      --query "StackEvents[?ResourceStatus=='CREATE_FAILED' || ResourceStatus=='UPDATE_FAILED'].[LogicalResourceId,ResourceStatus,ResourceStatusReason]" \
      --output table || true
    exit 1
  }
  aws sagemaker describe-endpoint --endpoint-name "$stack" \
    --query '{Endpoint:EndpointName,Status:EndpointStatus}' --output table
  verify_release "$version"
  exit
fi

# A drill must start from a working endpoint owned by the workshop serving stack.
endpoint_state() {
  aws sagemaker describe-endpoint --endpoint-name "$stack" \
    --query '[EndpointStatus,EndpointConfigName]' --output text
}
baseline_state=$(endpoint_state)
IFS=$'\t' read -r status baseline_config <<< "$baseline_state"
baseline_assets=$(aws cloudformation describe-stacks --stack-name "$stack" \
  --query "Stacks[0].[(Parameters[?ParameterKey=='ArtifactBucket'].ParameterValue | [0]), (Parameters[?ParameterKey=='ArtifactKey'].ParameterValue | [0])]" \
  --output text)
IFS=$'\t' read -r baseline_bucket baseline_key <<< "$baseline_assets"
if [[ "$status" != InService || -z "$baseline_config" || "$baseline_config" == None ||
      "$baseline_bucket" != "$bucket" || "$baseline_key" != training-output/*/model.tar.gz ||
      "$baseline_key" == "$artifact_key" ]]; then
  echo "The rollback drill requires a workshop endpoint InService on a different approved release." >&2
  exit 2
fi
invoke "$scratch/baseline.json"
baseline_version=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["modelVersion"])' "$scratch/baseline.json")
if [[ ! "$baseline_version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$ || "$baseline_version" == "$version" ]]; then
  echo "Select a candidate with a different release version from the baseline." >&2
  exit 2
fi

alarm="$stack-candidate-model-latency"
alarm_count=$(aws cloudwatch describe-alarms --alarm-names "$alarm" \
  --query 'length(MetricAlarms)' --output text)
if [[ "$alarm_count" != 0 ]]; then
  echo "Rollback drill requires a fresh candidate alarm. Deploy the approved baseline with rollback_demo unchecked first." >&2
  exit 2
fi
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
alarm_history() {
  aws cloudwatch describe-alarm-history --alarm-name "$alarm" --history-item-type StateUpdate \
    --start-date "$started" --output json
}
# Check that the workflow can retrieve the rollback evidence before changing traffic.
alarm_history >/dev/null
printf 'Baseline config: %s\nBaseline modelVersion: %s\nCandidate modelVersion: %s\nRollback alarm: %s\n' \
  "$baseline_config" "$baseline_version" "$version" "$alarm"

(
  previous=""
  while true; do
    if invoke "$scratch/probe.json" 2>/dev/null; then
      observed=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["modelVersion"])' "$scratch/probe.json")
      if [[ "$observed" != "$previous" ]]; then
        printf 'Probe modelVersion: %s\n' "$observed"
        previous="$observed"
      fi
    fi
    sleep 5
  done
) &
probe_pid=$!

deployment_status=0
deploy_endpoint EnableDeploymentGuardrails=true "RollbackArtifactKey=$baseline_key" || deployment_status=$?
stop_probes
if [[ "$deployment_status" == 0 ]]; then
  echo "Rollback drill failed: the endpoint update completed without a verified rollback." >&2
  aws cloudwatch describe-alarms --alarm-names "$alarm" \
    --query 'MetricAlarms[].{State:StateValue,Updated:StateUpdatedTimestamp,Reason:StateReason}' \
    --output json >&2 || true
  printf 'Current endpoint status and config: %s\n' "$(endpoint_state)" >&2
  exit 1
fi

alarm_history > "$scratch/alarm-history.json"
python3 - "$scratch/alarm-history.json" <<'PY'
import json
import sys
from pathlib import Path

history = json.loads(Path(sys.argv[1]).read_text())
for item in history["AlarmHistoryItems"]:
    change = json.loads(item["HistoryData"])
    if change.get("newState", {}).get("stateValue") == "ALARM":
        print(f"Candidate latency alarm entered ALARM at {item['Timestamp']}")
        break
else:
    raise SystemExit("Rollback drill could not verify a candidate latency alarm during this run.")
PY

stack_status=$(aws cloudformation describe-stacks --stack-name "$stack" \
  --query 'Stacks[0].StackStatus' --output text)
if [[ "$stack_status" != UPDATE_ROLLBACK_COMPLETE ]]; then
  printf 'Rollback drill failed: expected UPDATE_ROLLBACK_COMPLETE, found %s.\n' "$stack_status" >&2
  exit 1
fi
if [[ "$(endpoint_state)" != "$baseline_state" ]]; then
  echo "Rollback drill failed: the endpoint configuration did not return to the baseline in service." >&2
  exit 1
fi
verify_release "$baseline_version"
printf 'Rollback verified: %s is InService on %s and returned %s.\n' "$stack" "$baseline_config" "$baseline_version"
