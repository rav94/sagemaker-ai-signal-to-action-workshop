#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Called by deploy.sh after the account check and assets stack deployment.
version="$1"
stack="$2"
bucket="$3"
image_uri="$4"
role_arn="$5"
instance_type="${WORKSHOP_TRAINING_INSTANCE_TYPE:-ml.t3.large}"

job_name="${stack:0:34}-train-$(date -u +%Y%m%d%H%M%S)-$RANDOM"
data_digest=$(shasum -a 256 data/complaints.csv | cut -d ' ' -f 1)
data_uri="s3://$bucket/training-data/$data_digest/complaints.csv"
aws s3 cp data/complaints.csv "$data_uri" >&2

printf 'Training job: %s\nTraining data: %s\n' "$job_name" "$data_uri" >&2
aws sagemaker create-training-job \
  --training-job-name "$job_name" \
  --role-arn "$role_arn" \
  --algorithm-specification "TrainingImage=$image_uri,TrainingInputMode=File" \
  --input-data-config "ChannelName=train,DataSource={S3DataSource={S3DataType=S3Prefix,S3Uri=$data_uri,S3DataDistributionType=FullyReplicated}}" \
  --output-data-config "S3OutputPath=s3://$bucket/training-output" \
  --resource-config "InstanceType=$instance_type,InstanceCount=1,VolumeSizeInGB=10" \
  --stopping-condition MaxRuntimeInSeconds=900 \
  --environment "WORKSHOP_MODEL_VERSION=$version" \
  --enable-network-isolation >&2

if ! aws sagemaker wait training-job-completed-or-stopped --training-job-name "$job_name" >&2; then
  aws sagemaker describe-training-job --training-job-name "$job_name" \
    --query '{Status:TrainingJobStatus,Reason:FailureReason}' --output table >&2
  exit 1
fi

status=$(aws sagemaker describe-training-job --training-job-name "$job_name" \
  --query TrainingJobStatus --output text)
if [[ "$status" != Completed ]]; then
  printf 'Training job %s ended with status %s.\n' "$job_name" "$status" >&2
  exit 1
fi

aws sagemaker describe-training-job --training-job-name "$job_name" \
  --query ModelArtifacts.S3ModelArtifacts --output text
