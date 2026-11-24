# Model artifact

The training script uses the Phase 1 synthetic CSV, a stratified split, and a fitted TF-IDF plus logistic regression pipeline. The archive contains `complaint_classifier.joblib` and `model-version.txt` at its root. SageMaker extracts it under `/opt/ml/model`. The deployment pins the ECR image digests. Local packaging uploads the archive at a key containing its checksum. Managed training uploads a job-specific archive under `training-output/` and deployment uses the URI returned by SageMaker. Both archive paths use the same two filenames.

Run training and serving with the pinned dependencies. Joblib deserialization can execute code. Use the workshop build as the source of the archive and limit write access to the publishing role. Use a different release tag for each new image in the immutable ECR repository.
