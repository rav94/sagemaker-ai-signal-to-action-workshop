# Model artifact

The training script uses the Phase 1 synthetic CSV, a stratified split, and a fitted TF-IDF plus logistic regression pipeline. The archive contains `complaint_classifier.joblib` and `model-version.txt` at its root. SageMaker extracts it under `/opt/ml/model`. The deployment pins the ECR image digest and puts the archive at an S3 key containing the archive checksum.

Run training and serving with the pinned dependencies. Joblib deserialization can execute code. Use the workshop build as the source of the archive and limit write access to the publishing role. Use a different release tag for each new image in the immutable ECR repository.
