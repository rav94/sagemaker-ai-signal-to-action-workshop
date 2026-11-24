# Troubleshooting

| Symptom | Check |
|---|---|
| Docker cannot reach the daemon | Start your Docker engine and confirm `docker info` succeeds. Continue with the local Python server while resolving it. |
| Endpoint quota or capacity error | Check the real-time hosting quota for the instance type and region in the teaching account. Pick a supported AMD64 CPU type with quota. |
| Model startup or ping failure | Check CloudFormation events and `/aws/sagemaker/Endpoints/<endpoint-name>`. Check the image architecture, archive contents, and package versions. |
| Access denied | Check profile and region with STS. Distinguish deployer `iam:PassRole` and execution role image/artifact access from participant `sagemaker:InvokeEndpoint`. |
| `ModelError` on malformed input | Read the serving container's original status in the runtime error. The intentional invalid fixture has a non-string `message`. |
| S3 bucket blocks teardown | Empty only the dedicated assets bucket after you verify its CloudFormation stack and endpoint deletion. |
