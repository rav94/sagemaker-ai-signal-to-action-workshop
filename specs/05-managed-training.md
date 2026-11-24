# Managed training contract

The cloud-training mode runs the existing TF-IDF and logistic regression pipeline in one SageMaker AI training job. The training CSV and image are explicit job inputs. The training job and real-time endpoint use separate execution roles and compute.

| Contract | Expected value |
|---|---|
| Training image | Docker `training` target for Linux AMD64, published to ECR and selected by digest. |
| Data channel | `train` in File mode, sourced from the checksum-addressed CSV in the workshop bucket. |
| Container input | `/opt/ml/input/data/train/complaints.csv` |
| Container output | `/opt/ml/model/complaint_classifier.joblib` and `/opt/ml/model/model-version.txt` |
| Job output | SageMaker writes the archive under the workshop bucket's `training-output/` prefix. |
| Model version | The release version passed into the training job and returned by inference. |

## Acceptance criteria

- The script submits the job and requires status `Completed` before deploying its model. A failed or stopped job prevents endpoint creation or update.
- The serving stack uses the S3 URI from `ModelArtifacts.S3ModelArtifacts`.
- A signed invocation on the shared endpoint returns a category, score, and the training release's `modelVersion`.
- Training locally still works and produces the [same archive layout](03-model-artifact.md).

Local container verification is recorded in the [packaging tasks](../tasks/01-package.md). The live sandbox checks are tracked in the [deployment tasks](../tasks/02-deploy.md).
