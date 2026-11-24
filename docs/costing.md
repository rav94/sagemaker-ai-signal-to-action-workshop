# Workshop cost and cleanup

Budget one `ml.m5.large` real-time instance in the selected region, or substitute the approved CPU instance. Record the dated regional serving rate before deployment. A four-hour rehearsal window plus a two-hour class with the endpoint present throughout is roughly six instance-hours. Use the actual hosting duration for the final estimate, including idle time. Add S3 storage and requests, ECR image storage, and CloudWatch Logs ingestion and short-term retention. Student CLI invocations share the single teaching endpoint.

[SageMaker AI pricing](https://aws.amazon.com/sagemaker/ai/pricing/) · [S3 pricing](https://aws.amazon.com/s3/pricing/) · [ECR pricing](https://aws.amazon.com/ecr/pricing/) · [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/)

## Delete after the final invocation

Use the same approved profile and region as deployment. Check the account with STS before running deletion commands.

```bash
stack="${WORKSHOP_STACK:-moratuwa-complaint-sagemaker}"
aws sts get-caller-identity
aws cloudformation delete-stack --stack-name "$stack"
aws cloudformation wait stack-delete-complete --stack-name "$stack"
aws sagemaker list-endpoints --name-contains "$stack" \
  --query "Endpoints[?EndpointName=='$stack']"
```

After verifying the result is empty, look up `ArtifactBucket` in the `<endpoint-stack>-assets` stack. Confirm that it is the workshop-only bucket. Empty that bucket with `aws s3 rm s3://<workshop-bucket> --recursive`, then delete the assets stack and wait for it to finish. CloudFormation removes the workshop ECR repository and its images.
