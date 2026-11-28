# Managed training and evaluation contract

Run `bash scripts/deploy.sh RELEASE` to provision Studio, publish the inputs, apply the assets, registry, and pipeline stacks, and start a SageMaker execution. The launcher returns the pipeline execution ARN. SageMaker orchestrates the steps in [the pipeline definition](../scripts/pipeline-definition.py).

| Step | Inputs and outputs |
|---|---|
| `TrainModel` | Uses the Linux AMD64 `training` image by ECR digest. SageMaker stages the checksum-addressed CSV at `/opt/ml/input/data/train/complaints.csv` through the `train` File-mode channel. Training fits TF-IDF and logistic regression on the training split and writes the [artifact files](03-model-artifact.md) to `/opt/ml/model`. SageMaker uploads the archive under `training-output/`. |
| `EvaluateModel` | Uses the same image with the evaluation entry point. Reads the exact archive from `ModelArtifacts.S3ModelArtifacts` and the same CSV. Reconstructs the deterministic stratified split and scores the 16 held-out complaints. Publishes `evaluation-output/<execution-id>/evaluation.json` with overall accuracy, billing recall, counts, and the model version. |
| `CheckBillingRecall` | Reads `multiclass_classification_metrics.billing_recall.value` from the `EvaluationReport` property file and compares it to the execution's `MinimumBillingRecall`. The default is `0.50`. |
| `RegisterCandidate` | Runs when billing recall is at or above the threshold. Creates a versioned package under the [registered release contract](07-registry-release.md). |
| `RejectBelowThreshold` | Runs when billing recall is below the threshold. Fails the execution before registration. |

Training uses one `ml.t3.large` by default and Processing uses one `ml.t3.medium`. Both jobs have a 900-second runtime limit. Override the defaults with `WORKSHOP_TRAINING_INSTANCE_TYPE` and `WORKSHOP_EVALUATION_INSTANCE_TYPE`. SageMaker uses the pipeline role to orchestrate the jobs and the workload role to stage inputs and write outputs.

## Acceptance criteria

- A passing execution produces an evaluation report and a `PendingManualApproval` package. The package uses the training step's exact archive URI. The checked-in fixture has 48 training complaints, 16 holdout complaints, and four billing cases in the holdout.
- A failed training or Processing job prevents registration. A below-threshold run reaches the explicit failure step and creates no package for that execution.
- Endpoint changes require a separate promotion of an approved and completed package. A signed invocation returns the registered release version.
- The [local lab](../README.md#run-the-local-lab) produces the same archive layout and prints its evaluation report.

[Studio walkthrough](../docs/deployment-demo-playbook.md#inspect-the-run-in-studio) · [AWS pipeline property files](https://docs.aws.amazon.com/sagemaker/latest/dg/build-and-manage-propertyfile.html)
