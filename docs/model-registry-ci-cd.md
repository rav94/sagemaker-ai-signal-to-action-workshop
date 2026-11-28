# Model Registry and CI/CD

GitHub CI tests the containers on pull requests and pushes to `main`. SageMaker Pipelines builds the model candidate. An instructor reviews the evidence and approves a specific Registry package. Approval updates the package status. The separate GitHub Actions workflow starts on manual dispatch and promotes that package to the endpoint.

## GitHub Actions setup

[Workshop CI](../.github/workflows/ci.yml) builds the training and serving images, trains and evaluates in local containers on the runner, and checks health, versioned inference, and malformed input. It runs with GitHub read access and requires Docker rather than AWS credentials.

[Deploy approved SageMaker release](../.github/workflows/deploy-approved.yml) uses GitHub OIDC for short-lived AWS credentials. Confirm the current workflow and its deploy script are on the GitHub repository's default branch, `main`.

### Set up AWS access once

Use the [workshop launcher](deployment-demo-playbook.md#launch-the-workshop) to create the assets stack if needed. Run the IAM setup with the same AWS profile, account, and Region. The [setup script](../scripts/setup-github-iam.sh) checks the account and looks up the workshop assets. It creates the account's GitHub OIDC provider for `https://token.actions.githubusercontent.com` if missing and ensures `sts.amazonaws.com` is an audience. If the provider already exists, the script keeps its other audiences. Use the teaching identity that deploys the workshop IAM stack. For the provider step, it needs `iam:ListOpenIDConnectProviders` and `iam:GetOpenIDConnectProvider`, plus `iam:CreateOpenIDConnectProvider` or `iam:AddClientIDToOpenIDConnectProvider` if setup needs to make a change. [AWS identity provider setup](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)

The [GitHub deployment IAM template](../github-deploy-iam.yaml) references that provider and creates the deployment role for GitHub Actions and the execution role for SageMaker. The GitHub role can read the approved package, apply the serving stack, invoke the endpoint, and verify rollback. It can pass the execution role only to SageMaker. The execution role can load workshop model archives and serve both fleets during the rollback drill.

Supply the exact OIDC subject for the repository that runs the workflow. This is the value for the instructor's repository:

```bash
github_subject='repo:rav94@9110053/sagemaker-ai-signal-to-action-workshop@1470484524:ref:refs/heads/main'
```

For a GitHub fork or new repository that uses immutable subjects, replace `OWNER/REPO` below. GitHub includes the owner and repository IDs for repositories created after July 15, 2026 and for repositories that have opted in. For an older repo still using the original subject format, set `github_subject='repo:OWNER/REPO:ref:refs/heads/main'`. A local clone of the same GitHub repository uses the same subject. [GitHub OIDC subject formats](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws#configuring-the-role-and-trust-policy)

```bash
github_subject=$(gh api repos/OWNER/REPO \
  --jq '"repo:\(.owner.login)@\(.owner.id)/\(.name)@\(.id):ref:refs/heads/main"')
```

Run this from the repo root with the subject you set above. The script prints the stack outputs for GitHub. You can rerun it with the same subject for later rehearsals.

```bash
bash scripts/setup-github-iam.sh "$github_subject"
```

If an earlier attempt left `${WORKSHOP_STACK:-sagemaker-ai-signal-insight-action-workshop}-github-iam` in `ROLLBACK_COMPLETE`, delete that failed IAM stack and wait for deletion before running setup again. [Troubleshooting](troubleshooting.md)

### Set GitHub repository variables

Open **Settings → Secrets and variables → Actions → Variables** in the repository that runs the workflow. Add these repository variables from the setup stack's outputs. [GitHub variable setup](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-variables#creating-configuration-variables-for-a-repository)

| Variable | Stack output |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | `GitHubDeployRoleArn` |
| `AWS_MODEL_EXECUTION_ROLE_ARN` | `ModelExecutionRoleArn` |
| `AWS_REGION` | `WorkshopRegion` |
| `WORKSHOP_ACCOUNT_ID` | `WorkshopAccountId` |
| `WORKSHOP_STACK` | `WorkshopStack`. Optional when the template default is used. |

For the first endpoint deployment, finish adding these repository variables, then [find the model package ARN](#find-the-model-package-arn).

## Find the model package ARN

In Studio, open **Pipelines → your workshop pipeline → Executions**. Select the run that built the release you want to deploy and check that `RegisterCandidate` succeeded. Use the version registered by that step.

From the AWS CLI, paste the **pipeline execution ARN** printed by `scripts/deploy.sh`. The command below retrieves the **model package ARN** registered by that execution and saves it in `package_arn` for the next commands.

```bash
execution_arn='<pipeline execution ARN printed by scripts/deploy.sh>'
package_arn=$(aws sagemaker list-pipeline-execution-steps \
  --pipeline-execution-arn "$execution_arn" \
  --query "PipelineExecutionSteps[?StepName=='RegisterCandidate' && StepStatus=='Succeeded'].Metadata.RegisterModel.Arn | [0]" \
  --output text --no-cli-pager) && printf '%s\n' "$package_arn"
```

The package ARN ends in `model-package/<workshop-stack>-registry/<version-number>`. If the command returns `None`, check the execution and the `RegisterCandidate` step before proceeding. Use the full package ARN as the GitHub workflow's `model_package_arn` input. [AWS CLI step metadata](https://docs.aws.amazon.com/cli/latest/reference/sagemaker/list-pipeline-execution-steps.html)

## Review and approve the package

Use the exact [versioned model package ARN](#find-the-model-package-arn) from your execution. In the Sagemaker AI console, Go to Model -> Custom Models -> Select the associated model and go to model version's **Evaluate → Model Quality** card in Studio to review the report. Confirm that the package is `Completed` and awaiting approval. Record its release version.

```bash
aws sagemaker describe-model-package --model-package-name "$package_arn" \
  --query '{Approval:ModelApprovalStatus,Status:ModelPackageStatus,Version:CustomerMetadataProperties.ReleaseVersion}'
```

With the workshop's `workshop-instructor` profile, open the exact model version in Studio. In its **Deploy** card, open **Pending Approval** and choose **Approved**. The instructor Studio role can approve versions in the workshop group. You can also approve the same ARN with the teaching AWS CLI profile.

```bash
aws sagemaker update-model-package \
  --model-package-arn "$package_arn" \
  --model-approval-status Approved \
  --approval-description "Workshop sandbox evaluation reviewed"
```

For the first endpoint deployment, run the workflow from GitHub Actions. Open **Actions → Deploy approved SageMaker release → Run workflow**, select `main`, paste the ARN, and leave `rollback_demo` unchecked for the baseline. The job checks that the package is `Approved` and `Completed`, applies the serving CloudFormation stack with its exact S3 archive and ECR image digest, and invokes the endpoint to verify `modelVersion`. In the run log, verify **Assume the teaching account deployment role** succeeded and the endpoint returned the expected `modelVersion`. Run the [inference walkthrough](participant-guide.md) after it succeeds.

## Demonstrate rollback

Deploy the first approved package and verify its `modelVersion`. Train and approve a second release with a fresh label, such as `phase1-rollout-v2`, using the [same AWS walkthrough](deployment-demo-playbook.md). Check the hosting quota for both fleets to run at once. The drill requires the previous candidate alarm to be absent. If a drill left that alarm behind, deploy the approved baseline with `rollback_demo` unchecked so CloudFormation removes it.

Dispatch **Deploy approved SageMaker release** with the second package ARN and check **rollback_demo**. The same workflow records the live baseline, sends probe requests during the update, and enables SageMaker's all-at-once blue/green policy. When the candidate is ready, SageMaker sends it 100% of traffic and keeps the baseline fleet available with a ten-minute fleet termination wait (`TerminationWaitInSeconds`). This gives CloudWatch time to publish and evaluate the candidate metrics.

The candidate-specific CloudWatch `ModelLatency` alarm uses an intentionally low **1 µs** threshold so the probes can trigger the drill. In the workflow log, look for the alarm's `ALARM` transition, the restored baseline endpoint configuration, and a fresh response with the original `modelVersion`. The CloudFormation update is expected to fail and finish in `UPDATE_ROLLBACK_COMPLETE`. The workflow succeeds after it verifies that stack status, the alarm, and the restored endpoint. [Rollout diagram](architecture/README.md#bluegreen-rollout-and-rollback) · [AWS all-at-once rollout](https://docs.aws.amazon.com/sagemaker/latest/dg/deployment-guardrails-blue-green-all-at-once.html) · [AWS alarm configuration](https://docs.aws.amazon.com/sagemaker/latest/dg/deployment-guardrails-configuration.html)

If the candidate finishes deploying without an alarm, the drill reports failure and the candidate can still be live. Check the serving `modelVersion`. To restore the original release, dispatch its approved ARN with `rollback_demo` unchecked.

See [workshop cleanup](costing.md) for the registry stack and package versions.

[AWS Model Registry](https://docs.aws.amazon.com/sagemaker/latest/dg/model-registry.html) · [Model approval](https://docs.aws.amazon.com/sagemaker/latest/dg/model-registry-approve.html)
