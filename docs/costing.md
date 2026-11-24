# Workshop cost and cleanup

Budget one shared SageMaker CPU training job and one shared real-time endpoint. Check the configured training and serving instance types separately using `WORKSHOP_TRAINING_INSTANCE_TYPE` and `WORKSHOP_INSTANCE_TYPE`.

| Cost item | How to estimate it |
|---|---|
| **Training job** | Use the regional training rate and the completed job’s `BillableTimeInSeconds` from `DescribeTrainingJob`. The job has a 15-minute runtime limit and releases its training compute when it finishes. A local-artifact run skips the AWS training job. |
| **Real-time endpoint** | Use the regional inference rate and the time the endpoint stays provisioned, including idle time. A four-hour rehearsal window plus a two-hour class with the endpoint present throughout is roughly six instance-hours. |
| **Guarded endpoint update** | Budget for both the baseline and candidate fleets during the blue/green overlap and for the CloudWatch metric alarm. |
| **Bedrock content check** | Estimate `ApplyGuardrail` by text units and the enabled filters. Requests that stop at the guardrail still incur any applicable screening charges. |
| **S3, ECR, CloudWatch** | Include CSV and model archive storage and requests, storage for the training and serving images, and training and serving log ingestion and retention. |

Record the region and the pricing date for your estimate. [SageMaker AI pricing](https://aws.amazon.com/sagemaker/ai/pricing/) · [S3 pricing](https://aws.amazon.com/s3/pricing/) · [ECR pricing](https://aws.amazon.com/ecr/pricing/) · [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/) · [Bedrock Guardrails pricing](https://aws.amazon.com/bedrock/pricing/) · [Training job billing field](https://docs.aws.amazon.com/sagemaker/latest/APIReference/API_DescribeTrainingJob.html)

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

Verify that the endpoint query returns an empty result and that the workshop training job and any guarded update have reached terminal states. If you interrupted the deploy script, check the job by its printed name before deleting the assets.

Find the bucket output for the assets stack:

```bash
aws cloudformation describe-stacks --stack-name "${stack}-assets" \
  --query "Stacks[0].Outputs[?OutputKey=='ArtifactBucket'].OutputValue | [0]" \
  --output text
```

After confirming it is the dedicated workshop bucket, replace the sample value and run:

```bash
bucket=verified-workshop-bucket-name
aws s3 rm "s3://$bucket" --recursive &&
  aws cloudformation delete-stack --stack-name "${stack}-assets" &&
  aws cloudformation wait stack-delete-complete --stack-name "${stack}-assets"
```

CloudFormation removes the ECR repository and both images. The shared SageMaker training log group follows the account’s log retention policy.
