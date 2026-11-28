# Troubleshooting

| Symptom | Check |
|---|---|
| Docker cannot reach the daemon | Start your Docker engine and confirm `docker info` succeeds. Continue with the local Python server while resolving it. |
| Training, Processing, or hosting quota error | Check the quota for that workload and instance type in the teaching account and region. Use the override for the corresponding workload from the [preflight](deployment-demo-playbook.md#preflight). |
| Studio does not show the execution | Open the workshop-created domain using `workshop-instructor`. Compare the account and Region with the execution ARN. |
| Studio Pipelines reports missing `sagemaker:Search` or `sagemaker:CreatePresignedDomainUrl` | Update the existing Studio CloudFormation stack with [the current Studio template](../studio.yaml), then reopen the workshop profile. The portal policy allows search across the teaching Region and presigned URLs for the workshop profile. |
| Studio Model Quality reports `s3:GetObject` denied | Update the existing Studio stack with the current [Studio template](../studio.yaml) and pass the `ArtifactBucket` output from the workshop assets stack. Reopen the model version. Studio can read the workshop's `evaluation.json` reports. |
| Studio Endpoints reports `sagemaker:DescribeEndpoint` denied | Update the existing Studio stack with [the current Studio template](../studio.yaml), using the same stack parameters. Reopen the workshop profile and go to **Deployments → Endpoints**. |
| Studio Playground reports `sagemaker:InvokeEndpoint` denied or Auto scaling reports `application-autoscaling:DescribeScalableTargets` missing | Apply the latest [Studio template](../studio.yaml) to the existing Studio stack and refresh the endpoint page. The workshop profile can invoke the workshop endpoint and read scaling settings in the workshop Region. |
| Pipeline execution fails | Open the failed step in Studio or run `aws sagemaker list-pipeline-execution-steps --pipeline-execution-arn <arn> --no-cli-pager`. Inspect the underlying training or Processing job failure reason and logs. |
| `RejectBelowThreshold` runs | Read the evaluation report and compare billing recall with the execution's `MinimumBillingRecall`. This execution produces no package. |
| Studio approval reports `sagemaker:UpdateModelPackage` denied | Update the Studio stack with the current [Studio template](../studio.yaml). Reopen `workshop-instructor` and approve the exact version in the workshop group. |
| GitHub Actions does not show **Run workflow** | Check that the dispatchable workflow is on the repository's default branch, `main`, and that the operator has write access. [Actions setup](model-registry-ci-cd.md#github-actions-setup) |
| GitHub IAM setup fails while configuring the provider | Confirm the teaching profile is in the intended account and can list, read, and configure the GitHub OIDC provider. If the earlier stack creation ended in `ROLLBACK_COMPLETE`, delete that failed `-github-iam` stack before rerunning setup. [IAM setup](model-registry-ci-cd.md#set-up-aws-access-once) |
| GitHub Actions cannot assume the deployment role | Check the account OIDC provider and audience, the role ARN, and the exact subject for the repository's `main` branch. Forks have their own subject. [AWS access setup](model-registry-ci-cd.md#set-up-aws-access-once) |
| GitHub deployment gets `AccessDenied` on `cloudformation:GetTemplateSummary` | Rerun the [GitHub IAM setup](model-registry-ci-cd.md#set-up-aws-access-once) with the current template. The AWS CLI reads the existing serving stack template before creating an update change set. Retry with the same approved package. |
| GitHub deployment fails on IAM role creation or `iam:PassRole` | Check that the `AWS_MODEL_EXECUTION_ROLE_ARN` repository variable matches the IAM setup stack output. For an endpoint deployed with an older template, see [migration for a legacy serving stack](#migrate-a-legacy-serving-stack). [Repository variables](model-registry-ci-cd.md#set-github-repository-variables) |
| GitHub deployment blocks promotion | Check that the exact versioned package is `Approved` and `Completed`. See the [approval steps](model-registry-ci-cd.md#review-and-approve-the-package). |
| Content check fails before SageMaker invocation | Confirm the Bedrock stack is deployed in live mode, the guardrail version is numbered, the Bedrock Region matches the guardrail, and the caller has `bedrock:ApplyGuardrail`. [Screening setup](guardrails.md#reference-the-bedrock-guardrail) |
| Rollback drill stops before updating | Confirm the baseline endpoint is `InService`, the second approved package has a different release version, and the Actions role can read the candidate alarm history. [Rollout prerequisites](model-registry-ci-cd.md#demonstrate-rollback) |
| Rollback drill fails during or after the update | Check the candidate alarm history, the current endpoint configuration and `modelVersion`, and the CloudFormation stack status. If the candidate became live without an alarm and you want to restore the baseline, dispatch its approved ARN with `rollback_demo` unchecked. |
| Endpoint uses an unexpected release | Compare the package's `ReleaseVersion`, S3 archive URI, and image digest with the deployed Model and the response's `modelVersion`. |
| SageMaker rejects the serving image with `Unsupported manifest media type` | Run the current launcher with a fresh release label, approve the new package, and dispatch its ARN. The old package pins the rejected image digest. For a failed first deployment in `ROLLBACK_COMPLETE`, delete only the failed serving stack and wait for deletion before dispatching again. [ECR manifest formats](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-manifest-formats.html) |
| GitHub sits at **Waiting for stack create/update to complete** after a resource failure | CloudFormation can still be rolling back. The workflow logs stack status changes while it waits. Let rollback reach a terminal status before retrying. Canceling the GitHub run stops the runner; check AWS separately for stack progress. |
| SageMaker denies `CreateEndpoint` or `UpdateEndpoint` on an endpoint configuration | Confirm the configuration carries the `WorkshopStack` tag and rerun the [GitHub IAM setup](model-registry-ci-cd.md#set-up-aws-access-once) with the current template. SageMaker authorizes the named endpoint and its configuration. [SageMaker IAM actions](https://docs.aws.amazon.com/service-authorization/latest/reference/list_sagemaker.html) |
| Model startup or ping failure | Check CloudFormation events and `/aws/sagemaker/Endpoints/<endpoint-name>`. Check the image architecture, archive contents, and package versions. |
| Access denied | Check profile and region with STS. Distinguish deployer `iam:PassRole`, the pipeline role's ability to start jobs and the job role's access to inputs and outputs, the serving role’s access to the model archive, and participant `sagemaker:InvokeEndpoint`. |
| `ModelError` on malformed input | SageMaker returns HTTP 424. Read the original status in the runtime error to identify the container’s HTTP 400. The intentional invalid fixture has a non-string `message`. |
| Registry stack is in `DELETE_FAILED` | Check the CloudFormation Events tab for `WorkshopModelPackageGroup`. If the group still contains packages, finish the [registry cleanup](costing.md#remove-the-registry-stack), then retry deletion before redeploying. |
| Studio stack cannot delete its VPC | Check that the workshop Studio domain has been deleted. Inspect the VPC for interfaces and leftover SageMaker NFS security groups. [Studio VPC cleanup](costing.md#if-the-studio-vpc-has-dependencies) |
| S3 bucket blocks teardown | Confirm the bucket is the assets stack output, the endpoint is gone, and the pipeline execution and its jobs have ended. Then follow [cleanup](costing.md#delete-after-the-final-invocation). |

## Migrate a legacy serving stack

This applies only to an endpoint already deployed with the older template where the serving stack owns its SageMaker execution role. Run the migration under your teaching AWS profile, which can remove that stack-owned IAM role. Export `AWS_MODEL_EXECUTION_ROLE_ARN` from the new IAM stack's `ModelExecutionRoleArn` output. Set `package_arn` to the previously approved baseline's full package ARN and run the following command.

```bash
WORKSHOP_ROLLBACK_DEMO=false bash scripts/deploy-approved.sh "$package_arn"
```

Verify the endpoint returns the baseline `modelVersion` before dispatching GitHub Actions again.
