# Model artifact

The training script fits a TF-IDF and logistic regression pipeline from the Phase 1 synthetic CSV. Both training paths produce an archive with the same two files at the root:

| File | Contents |
|---|---|
| `complaint_classifier.joblib` | The fitted vectorizer and classifier, serialized together. |
| `model-version.txt` | The non-empty release version returned by the endpoint as `modelVersion`. |

| Training path | Archive publication |
|---|---|
| Local | The packaging script writes `artifacts/model.tar.gz`. Deployment uploads it to `models/<version>/<archive-sha256>/model.tar.gz` in the workshop bucket. |
| Managed | The training container writes both files to `/opt/ml/model`. SageMaker publishes a job-specific archive under `training-output/`, and deployment uses the exact URI returned by `ModelArtifacts.S3ModelArtifacts`. |

The serving stack sets the selected archive as `PrimaryContainer.ModelDataUrl` and references the serving image by digest. SageMaker extracts the archive under `/opt/ml/model` before starting the serving container.

The [managed training contract](05-managed-training.md) describes the input channel and verifies the archive handoff. Run training and serving with the pinned dependencies. Joblib deserialization can execute code. Use the workshop build as the source of the archive and limit write access to the publishing role. Use a different release tag for each new image in the immutable ECR repository.
