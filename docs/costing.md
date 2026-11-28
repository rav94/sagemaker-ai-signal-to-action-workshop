# Workshop cost and cleanup

Budget one CPU training job and one Processing job per pipeline execution, plus one shared real-time endpoint after promotion. The instance settings are `WORKSHOP_TRAINING_INSTANCE_TYPE`, `WORKSHOP_EVALUATION_INSTANCE_TYPE`, and `WORKSHOP_INSTANCE_TYPE`.

| Cost item | How to estimate it |
|---|---|
| **Training job** | Use the regional training rate and the completed job’s `BillableTimeInSeconds` from `DescribeTrainingJob`. The job has a 15-minute runtime limit and releases its training compute when it finishes. |
| **Pipeline evaluation** | Add the regional Processing rate and duration for one short evaluation job per pipeline execution. |
| **Real-time endpoint** | Use the regional inference rate and the time the endpoint stays provisioned, including idle time. A four-hour rehearsal window plus a two-hour class with the endpoint present throughout is roughly six instance-hours. |
| **Rollout drill** | Budget an additional pipeline execution for the second candidate, both serving instances during the blue/green overlap, and the temporary CloudWatch alarm. |
| **Optional content screening** | Add Bedrock Guardrails text units for the shared policy's content and sensitive information filters. [Bedrock Guardrails pricing](https://aws.amazon.com/bedrock/pricing/) |
| **Studio** | The stack creates the domain and profile for viewing. It skips home EFS and provisions no notebook compute. |
| **S3, ECR, CloudWatch** | Include storage and requests for the CSV, model archive, and evaluation report. Add ECR image storage and CloudWatch log ingestion and retention for each workload. |

Record the region and the pricing date for your estimate. [SageMaker AI pricing](https://aws.amazon.com/sagemaker/ai/pricing/) · [S3 pricing](https://aws.amazon.com/s3/pricing/) · [ECR pricing](https://aws.amazon.com/ecr/pricing/) · [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/) · [Training job billing field](https://docs.aws.amazon.com/sagemaker/latest/APIReference/API_DescribeTrainingJob.html)

## Delete after the final invocation

Use the same approved profile and region as deployment. Check the account with STS before deleting resources. The Bedrock workshop stack owns the shared guardrail. Keep that stack available through the Bedrock session and follow its cleanup guide afterward.

```bash
stack="${WORKSHOP_STACK:-sagemaker-ai-signal-insight-action-workshop}"
aws sts get-caller-identity
aws cloudformation delete-stack --stack-name "$stack"
aws cloudformation wait stack-delete-complete --stack-name "$stack"
aws sagemaker list-endpoints --name-contains "$stack" \
  --query "Endpoints[?EndpointName=='$stack']"
```

Verify that the endpoint query returns an empty result and that the pipeline's training and Processing jobs have reached terminal states. Confirm the pipeline execution status before deleting the assets.

### Remove the Studio stack

```bash
aws cloudformation delete-stack --stack-name "${stack}-studio"
aws cloudformation wait stack-delete-complete --stack-name "${stack}-studio"
```

#### If the Studio VPC has dependencies

In the Studio stack's **Resources** tab, confirm `StudioDomain` is `DELETE_COMPLETE` and copy the physical ID for `StudioVpc`. Use that VPC ID to check what remains:

```bash
vpc_id='<physical ID of StudioVpc>'
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$vpc_id" \
  --query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Description:Description,Status:Status}'
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" \
  --query 'SecurityGroups[].{Id:GroupId,Name:GroupName}'
```

If the deleted workshop domain left its `security-group-for-inbound-nfs-<domain-id>` and `security-group-for-outbound-nfs-<domain-id>` groups behind, confirm neither has an attached interface. Remove the outbound group's rules referencing the inbound group, then delete the inbound group and the outbound group. Leave the default group for VPC deletion. Retry the Studio stack deletion and wait for it to complete. If a network interface remains, use its description to identify and remove the owning resource first. [AWS VPC deletion guide](https://docs.aws.amazon.com/vpc/latest/userguide/delete-vpc.html)

### Remove the pipeline stack

Wait for the workshop pipeline executions to finish, or stop a running execution by its recorded ARN. After the executions have ended, remove the pipeline stack before removing the Model Package Group:

```bash
pipeline_stack="${stack}-pipeline"
aws cloudformation delete-stack --stack-name "$pipeline_stack"
aws cloudformation wait stack-delete-complete --stack-name "$pipeline_stack"
```

### Remove the registry stack

List the versions in the workshop Model Package Group after verifying endpoint deletion:

```bash
registry_stack="${stack}-registry"
aws sagemaker list-model-packages --model-package-group-name "$registry_stack" \
  --model-package-type Versioned --query 'ModelPackageSummaryList[].ModelPackageArn'
```

For each listed workshop version, set `package_arn` to its full ARN and run `aws sagemaker delete-model-package --model-package-name "$package_arn"`. SageMaker requires an empty model group. This command checks the package count before deleting the stack. [AWS model group deletion](https://docs.aws.amazon.com/sagemaker/latest/dg/model-registry-delete-model-group.html)

```bash
remaining=$(aws sagemaker list-model-packages --model-package-group-name "$registry_stack" \
  --model-package-type Versioned --query 'length(ModelPackageSummaryList)' --output text) &&
  test "$remaining" = 0 &&
  aws cloudformation delete-stack --stack-name "$registry_stack" &&
  aws cloudformation wait stack-delete-complete --stack-name "$registry_stack"
```

If the count is above zero, list the versions again and check whether deletion is still in progress. If the stack is already in `DELETE_FAILED`, check its events for the failing resource. Once the group is empty, retry the same stack deletion and wait for it to complete before redeploying. [View CloudFormation stack events](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/view-stack-events.html)

### Keep or remove GitHub deployment access

After deleting the serving endpoint stack, keep the `${stack}-github-iam` stack if you intend to reuse GitHub Actions. Run the IAM setup again if you recreate the assets stack and its artifact bucket or image repository changes. For final teardown, remove the dedicated IAM stack and its repository variables. The setup script configures the OIDC provider directly in account IAM. Deleting the workshop IAM stack removes its roles and leaves that provider available to other repositories. Delete the provider separately only after confirming no remaining IAM role trusts it. Once it is deleted, any role that still references it can no longer be assumed through GitHub OIDC. [GitHub Actions setup](model-registry-ci-cd.md#github-actions-setup) · [AWS provider deletion behavior](https://docs.aws.amazon.com/cli/latest/reference/iam/delete-open-id-connect-provider.html)

```bash
aws cloudformation delete-stack --stack-name "${stack}-github-iam"
aws cloudformation wait stack-delete-complete --stack-name "${stack}-github-iam"
```

### Remove the assets stack

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

CloudFormation removes the ECR repository and all workshop images it contains. The shared SageMaker training and Processing log groups follow the account’s log retention policy.
