#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Called by deploy.sh after its account check and image publication.
stack="$1"
version="$2"
bucket="$3"
repository="$4"
training_image="$5"
serving_image="$6"
job_role="$7"
serving_type="$8"
training_type="${WORKSHOP_TRAINING_INSTANCE_TYPE:-ml.t3.large}"
evaluation_type="${WORKSHOP_EVALUATION_INSTANCE_TYPE:-ml.t3.medium}"
group="${stack}-registry"
pipeline="${stack}-pipeline"

definition=$(mktemp "${TMPDIR:-/tmp}/workshop-pipeline.XXXXXX")
trap 'rm -f -- "$definition"' EXIT
data_digest=$(shasum -a 256 data/complaints.csv | cut -d ' ' -f 1)
data_uri="s3://$bucket/training-data/$data_digest/complaints.csv"
python3 scripts/pipeline-definition.py "$bucket" "$data_uri" "$training_image" \
  "$serving_image" "$job_role" "$group" "$version" "$training_type" "$evaluation_type" \
  "$serving_type" > "$definition"
definition_digest=$(shasum -a 256 "$definition" | cut -d ' ' -f 1)
definition_key="pipelines/$version/$definition_digest.json"

aws s3 cp data/complaints.csv "$data_uri"
aws s3 cp "$definition" "s3://$bucket/$definition_key"
aws cloudformation deploy --template-file registry.yaml --stack-name "$group" \
  --no-fail-on-empty-changeset
aws cloudformation deploy --template-file pipeline.yaml --stack-name "$pipeline" \
  --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset \
  --parameter-overrides "ArtifactBucket=$bucket" "DefinitionKey=$definition_key" \
  "JobRoleArn=$job_role" "PackageGroup=$group" "ImageRepositoryName=$repository"

printf 'Pipeline: %s\n' "$pipeline"
aws sagemaker start-pipeline-execution --pipeline-name "$pipeline" \
  --pipeline-execution-description "Workshop candidate $version" \
  --query PipelineExecutionArn --output text
