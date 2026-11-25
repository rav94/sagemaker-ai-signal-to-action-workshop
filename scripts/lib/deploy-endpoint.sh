# Shared CloudFormation serving deployment for direct and approved releases.
deploy_workshop_endpoint() {
  local stack="$1" bucket="$2" artifact_key="$3" image_uri="$4" repository_name="$5" instance_type="$6"

  aws cloudformation deploy --template-file template.yaml --stack-name "$stack" \
    --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset \
    --parameter-overrides "ArtifactBucket=$bucket" "ArtifactKey=$artifact_key" \
    "ImageUri=$image_uri" "ImageRepositoryName=$repository_name" \
    "InstanceType=$instance_type" EnableDeploymentGuardrails=false

  aws sagemaker describe-endpoint --endpoint-name "$stack" \
    --query '{Endpoint:EndpointName,Status:EndpointStatus}' --output table
}
