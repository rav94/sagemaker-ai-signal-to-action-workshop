# Workshop architecture

## Managed training to real-time deployment

![SageMaker managed training and deployment overview](training-to-endpoint.png)

[Editable Draw.io source](serving.drawio) · [Open the overview PNG](training-to-endpoint.png)

The deployment script builds two Linux AMD64 images from the same Dockerfile. Its `training` target packages `src/train.py` and its `serving` target packages `src/serve.py`. They share a Python base and pinned packages. The managed path publishes tags `train-<release>` and `serve-<release>` to the workshop ECR repository. The training job and serving stack reference the respective image digests. Both enable network isolation.

| Stage | Inputs | Output |
|---|---|---|
| **Managed training** | ECR training image and a checksum-addressed CSV in S3. The `train` channel provides the CSV in File mode. | Evaluation output in CloudWatch and a job-specific S3 archive containing `complaint_classifier.joblib` and `model-version.txt`. |
| **Artifact handoff** | The completed job's `ModelArtifacts.S3ModelArtifacts` value. | The deployment script uses that S3 object as the SageMaker Model's `PrimaryContainer.ModelDataUrl`. |
| **Real-time deployment** | ECR serving image and the selected S3 model archive. | A SageMaker Model, EndpointConfig, and IAM-authenticated Endpoint. |
| **Local fallback** | The same dataset and training script run on a laptop. | The packaging script writes the same archive layout. Deployment uploads it to a checksum-addressed S3 key and uses the same serving stack. |

A SageMaker training job runs to completion and releases its compute. The provisioned real-time endpoint remains available for inference until you remove it. The [managed training lab](../cloud-training.md) shows how to verify the artifact URI on both sides of the handoff. [AWS training output](https://docs.aws.amazon.com/sagemaker/latest/dg/your-algorithms-training-algo-output.html) · [AWS real-time deployment](https://docs.aws.amazon.com/sagemaker/latest/dg/realtime-endpoints-deploy-models.html)

## Inference request

![Signal, insight, and action request flow](inference-request.png)

[Open the request flow PNG](inference-request.png)

The caller signs an `InvokeEndpoint` request to the SageMaker Runtime API. SageMaker sends it to `POST /invocations` in the serving container on port `8080`. The container loads the fitted pipeline from `/opt/ml/model` at startup. The response contains a category, score, and model version. The caller can then use the local action CLI to simulate routing or human review. The serving contract is the same whether the artifact was trained locally or on SageMaker. [Inference contract](../../specs/02-inference-contract.md) · [AWS InvokeEndpoint API](https://docs.aws.amazon.com/sagemaker/latest/APIReference/API_runtime_InvokeEndpoint.html)

## Release and content safeguards

![Blue/green rollout and automatic rollback for a SageMaker endpoint](sagemaker-guarded-update.png)

The optional [guarded update](../guardrails.md#1-protect-a-sagemaker-endpoint-update) attaches a candidate model-latency alarm to SageMaker's blue/green deployment policy. The alarm watches the new endpoint configuration and can trigger rollback to the prior fleet.

![Bedrock ApplyGuardrail decision before SageMaker inference](bedrock-content-screening.png)

The [guarded caller](../guardrails.md#2-use-bedrock-applyguardrail-in-front-of-sagemaker) calls Bedrock ApplyGuardrail before invoking the endpoint. It forwards the complaint to SageMaker when the published guardrail returns `NONE`. In this lab, every intervention or check failure stops the request. The [guardrails contract](../../specs/06-guardrails.md) describes the status codes and the evidence to capture.

## Stack ownership and identities

| Where | What it owns or can do |
|---|---|
| [Assets stack](../../bootstrap.yaml) | Private S3 artifact bucket, immutable-tag ECR repository, and SageMaker training execution role. |
| [Serving stack](../../template.yaml) | SageMaker serving execution role, endpoint log group with seven-day retention, Model, EndpointConfig, and Endpoint, plus the candidate alarm when the guarded update is enabled. |
| [Deployment script](../../scripts/deploy.sh) and [training helper](../../scripts/train-cloud.sh) | Build and publish the images, submit and wait for the training job, and pass its model archive to the serving stack. The training job is submitted through the SageMaker API. |
| Instructor/deployer identity | Publishes assets, deploys stacks, submits and inspects jobs, and passes the SageMaker execution roles. |
| Training execution role | SageMaker uses it to read the training data and image, write training output to S3, and publish training logs and metrics. |
| Serving execution role | SageMaker uses it to read the selected archive and serving image and publish serving logs and metrics. |
| Participant identity | Calls `sagemaker:InvokeEndpoint` on the shared endpoint. An instructor can run the architecture inspection commands for participants with invoke-only access. |

See [the deployment playbook](../deployment-demo-playbook.md) for launch order, [costing](../costing.md) for teardown, and [MLOps design](../mlops.md) for the production release exercise.
