# Troubleshooting

| Symptom | Check |
|---|---|
| Docker cannot reach the daemon | Start your Docker engine and confirm `docker info` succeeds. Continue with the local Python server while resolving it. |
| Training quota or capacity error | Check the SageMaker training-job quota separately from the endpoint quota. Set `WORKSHOP_TRAINING_INSTANCE_TYPE` to a supported AMD64 CPU instance with quota. |
| Training job fails or is stopped | Use the printed job name to inspect `TrainingJobStatus`, `FailureReason`, and CloudWatch logs. Check the input channel, training image, and training role before trying a fresh release tag. The script has skipped the serving stack update for this release. |
| Endpoint quota or capacity error | Check the real-time hosting quota for the instance type and region in the teaching account. Pick a supported AMD64 CPU type with quota. |
| Training completed but endpoint uses an unexpected release | Compare `ModelArtifacts.S3ModelArtifacts` with the deployed model’s `PrimaryContainer.ModelDataUrl`. Then check `modelVersion` in a successful response. Follow the [handoff checks](cloud-training.md#inspect-the-handoff). |
| Model startup or ping failure | Check CloudFormation events and `/aws/sagemaker/Endpoints/<endpoint-name>`. Check the image architecture, archive contents, and package versions. |
| Access denied | Check profile and region with STS. Distinguish deployer `iam:PassRole`, the training role’s access to the CSV and output prefix, the serving role’s access to the model archive, and participant `sagemaker:InvokeEndpoint`. |
| `ModelError` on malformed input | SageMaker returns HTTP 424. Read the original status in the runtime error to identify the container’s HTTP 400. The intentional invalid fixture has a non-string `message`. |
| S3 bucket blocks teardown | Confirm the bucket is the assets stack output, the endpoint is gone, and the training job has ended. Then follow [cleanup](costing.md#delete-after-the-final-invocation). |
