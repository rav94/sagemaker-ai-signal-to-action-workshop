# Workshop cost and cleanup

Budget one shared SageMaker CPU training job and one shared real-time endpoint. Both default to `ml.m5.large`, with independent quota and instance settings.

| Cost item | How to estimate it |
|---|---|
| **Training job** | Use the regional training rate and the job's actual billed duration. The job has a 15-minute runtime limit and releases its training compute when it finishes. A local-artifact run skips the AWS training job. |
| **Real-time endpoint** | Use the regional inference rate and the time the endpoint stays provisioned, including idle time. A four-hour rehearsal window plus a two-hour class with the endpoint present throughout is roughly six instance-hours. |
| **S3, ECR, CloudWatch** | Include CSV and model archive storage and requests, storage for the training and serving images, and training and serving log ingestion and retention. |

Record the region and the pricing date for your estimate. [SageMaker AI pricing](https://aws.amazon.com/sagemaker/ai/pricing/) · [S3 pricing](https://aws.amazon.com/s3/pricing/) · [ECR pricing](https://aws.amazon.com/ecr/pricing/) · [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/)

## Delete after the final invocation

Use the same approved profile and region as deployment. Check the account with STS before deleting resources.

```bash
stack="${WORKSHOP_STACK:-moratuwa-complaint-sagemaker}"
aws sts get-caller-identity
aws cloudformation delete-stack --stack-name "$stack"
aws cloudformation wait stack-delete-complete --stack-name "$stack"
aws sagemaker list-endpoints --name-contains "$stack" \
  --query "Endpoints[?EndpointName=='$stack']"
```

Verify that the endpoint query returns an empty result and that the workshop training job has reached a terminal state. If you interrupted the deploy script, check the job by its printed name before deleting the assets.

Find the bucket output for the assets stack:

```bash
aws cloudformation describe-stacks --stack-name "${stack}-assets" \
  --query "Stacks[0].Outputs[?OutputKey=='ArtifactBucket'].OutputValue | [0]" \
  --output text
```

Confirm it is the dedicated workshop bucket. Empty it with `aws s3 rm s3://<workshop-bucket> --recursive`, then delete the `<endpoint-stack>-assets` stack and wait for deletion to complete. CloudFormation removes the workshop ECR repository and its images. The shared SageMaker training log group is outside these stacks and follows the account's log retention policy.
