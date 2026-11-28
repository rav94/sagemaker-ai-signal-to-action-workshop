# AWS deployment walkthrough

## Preflight

Use AWS CLI v2, Docker with Buildx and Linux AMD64 build support, and Python 3.13. Use your teaching AWS profile and keep the same account and Region in the CLI, Studio, and GitHub Actions. The launcher checks the account before provisioning. If the values are already loaded, keep them.

```bash
export AWS_PROFILE=your-teaching-profile
export AWS_REGION=us-east-1
export WORKSHOP_ACCOUNT_ID=123456789012
aws sts get-caller-identity
docker info --format '{{.ServerVersion}}'
docker buildx version
```

- Check the independent quotas for training (`ml.t3.large`), Processing (`ml.t3.medium`), and real-time hosting (`ml.t2.medium`). Use `WORKSHOP_TRAINING_INSTANCE_TYPE`, `WORKSHOP_EVALUATION_INSTANCE_TYPE`, or `WORKSHOP_INSTANCE_TYPE` if a default has no quota. [AWS SageMaker quotas](https://docs.aws.amazon.com/general/latest/gr/sagemaker.html)
- The teaching identity needs to provision the workshop's CloudFormation stacks, publish to S3 and ECR, start and inspect the pipeline, and open a Studio profile. Studio launch in IAM mode uses `sagemaker:CreatePresignedDomainUrl` on the profile. [AWS Studio launch guide](https://docs.aws.amazon.com/sagemaker/latest/dg/studio-updated-launch.html)
- Confirm the [GitHub Actions workflow](model-registry-ci-cd.md#github-actions-setup) is on the remote `main` branch. Set up its AWS role after the launcher creates the assets stack.

## Launch the workshop

Use a fresh release label if you have already published images for `phase1-pipeline-v1`. ECR tags are immutable.

```bash
bash scripts/deploy.sh phase1-pipeline-v1
```

The launcher provisions the dedicated Studio domain and profile, publishes the versioned S3 and ECR inputs, creates or updates the native pipeline, and starts an execution. Buildx publishes single-platform Docker Schema 2 images, and the launcher verifies the stored manifest type in ECR before starting the run. The command prints the Studio domain, profile, pipeline name, and execution ARN.

The Studio workspace provides the graph and Registry metadata. A passing execution ends at candidate registration. You deploy the endpoint in the GitHub Actions step after approval.

## Inspect the run in Studio

In the SageMaker AI console, open **Domains**, choose the printed workshop domain, then **Open Studio → workshop-instructor → Launch personal Studio**. In Studio, open **Pipelines → your workshop pipeline → Executions** and select the run. [AWS execution graph guide](https://docs.aws.amazon.com/sagemaker/latest/dg/pipelines-studio-view-execution.html)

| Step | Evidence to inspect |
|---|---|
| `TrainModel` | The training job writes a versioned `model.tar.gz` to S3. |
| `EvaluateModel` | The Processing job uses that archive, scores the 16 held-out rows, and writes `evaluation.json` to S3. After registration, view the report in the model version's **Evaluate → Model Quality** card in Studio. |
| `CheckBillingRecall` | Reads billing recall from `evaluation.json` and passes when it is at least `MinimumBillingRecall`, which defaults to `0.50`. |
| `RegisterCandidate` | A pass produces a versioned `PendingManualApproval` package. Copy the exact package ARN. |
| `RejectBelowThreshold` | A miss fails the execution before registration. |

The local check found **13/16 correct overall** and **2/4 actual billing cases caught**. Billing recall is `2 ÷ 4 = 0.50`, so this candidate meets the default gate exactly. Read the live report for your run. The gate controls registration. The inference score threshold controls routing for an individual complaint. Four billing cases are too few to support a production release decision.

## Deploy the baseline

Model Registry is the handoff from model building to the separate production-style deployment workflow. GitHub Actions takes the exact approved package version and uses its registered assets. [Why separate build and deployment?](mlops.md#why-separate-model-building-and-deployment)

1. For the first rehearsal, [run GitHub IAM setup and set repository variables](model-registry-ci-cd.md#github-actions-setup). Reuse this setup for later deployments.
2. [Find the versioned model package ARN](model-registry-ci-cd.md#find-the-model-package-arn) for the successful `RegisterCandidate` step.
3. Confirm the package is `Completed` and review the evaluation report. In Studio, select **Approved** from the **Pending Approval** dropdown in the version's **Deploy** card. [Review and approve](model-registry-ci-cd.md#review-and-approve-the-package)
4. In **GitHub Actions → Deploy approved SageMaker release → Run workflow**, select `main`, paste the ARN into `model_package_arn`, leave **`rollback_demo` unchecked**, and run the workflow.
5. Open **Deploy and verify the approved model package** in the run log. Confirm the endpoint is `InService` and save the verified baseline `modelVersion` and approved ARN for the drill.

In Studio, open **Deployments → Endpoints** and choose the workshop endpoint to check its status, instance type, and endpoint configuration. Use **Playground** to send the JSON from [the complaint fixture](../events/complaint.json). **Auto scaling** lets you inspect scaling settings. The workshop endpoint uses one fixed instance. [View endpoint details in Studio](https://docs.aws.amazon.com/sagemaker/latest/dg/manage-endpoints-studio.html)

## Screen a complaint before inference

With the baseline endpoint `InService`, run the [content screening lab](guardrails.md) using the guardrail ID and published version from the separate Bedrock workshop. Show one complaint that reaches SageMaker and one that the caller stops after the content check.

## Demonstrate blue/green rollback

Keep the baseline endpoint running. Check real-time hosting quota for both fleets to overlap, and verify the [deployment role can manage and read the CloudWatch alarm](model-registry-ci-cd.md#github-actions-setup).

```bash
bash scripts/deploy.sh phase1-rollout-v2
```

1. Open the second execution in Studio. After it passes the gate, copy the new `RegisterCandidate` package ARN and approve it the same way as the baseline.
2. Run **Deploy approved SageMaker release** again on `main`. Paste the second ARN into `model_package_arn` and check **`rollback_demo`**.
3. In the run log, find **Baseline modelVersion**, **Candidate modelVersion**, and the latency alarm name. SageMaker shifts **100% of traffic** to the candidate. The workflow sends probes while the baseline fleet stays available during the configured ten-minute fleet termination wait.
4. Show that the candidate alarm entered `ALARM`, CloudFormation reached `UPDATE_ROLLBACK_COMPLETE`, and the original configuration is back in `InService`. The workflow prints **Rollback verified** after a fresh inference returns the baseline `modelVersion`.

The CloudFormation update failure is expected in a successful drill. The workflow reports success after it verifies the alarm, completed stack rollback, and restored baseline. [Rollback diagram](architecture/README.md#bluegreen-rollout-and-rollback) · [Troubleshooting](troubleshooting.md) · [Cleanup](costing.md#delete-after-the-final-invocation)
