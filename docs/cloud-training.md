# Train the complaint classifier on SageMaker AI

Run this after training once locally. Students will recognize the dataset, the TF-IDF pipeline, the evaluation report, and the fitted model file. The new piece is how a managed training job moves data and model artifacts between the container and S3.

[See the training-to-endpoint architecture](architecture/README.md#managed-training-to-real-time-deployment). The training and serving images are separate targets of the same Dockerfile.

## Run one shared job

Follow the sandbox preflight in the [deployment playbook](deployment-demo-playbook.md). Training jobs and real-time endpoints have separate instance quotas. Run one instructor job for the cohort and use a new release version if you rerun the build.

```bash
bash scripts/deploy.sh phase1-cloud-v1 --cloud-train
```

The script publishes the `training` and `serving` image targets to ECR, then prints the training job name and dataset URI. The training image uses a `train` data channel in File mode, so SageMaker places the CSV at `/opt/ml/input/data/train/complaints.csv`. The training process writes the fitted pipeline and version to `/opt/ml/model`. At the end of the job, SageMaker puts the archive in S3 and releases the training compute. The deploy script reads `ModelArtifacts.S3ModelArtifacts` from the completed job and passes that exact archive to the real-time endpoint stack.

[AWS training inputs](https://docs.aws.amazon.com/sagemaker/latest/dg/your-algorithms-training-algo-running-container.html) · [AWS training output](https://docs.aws.amazon.com/sagemaker/latest/dg/your-algorithms-training-algo-output.html)

## Inspect the handoff

In the same sandbox profile and region, set `job` to the name printed by the deploy script. Check the training job from another terminal.

```bash
job='<printed training job name>'
aws sagemaker describe-training-job --training-job-name "$job" \
  --query '{Status:TrainingJobStatus,Data:InputDataConfig[0].DataSource.S3DataSource.S3Uri,Model:ModelArtifacts.S3ModelArtifacts}'

aws logs tail /aws/sagemaker/TrainingJobs \
  --log-stream-name-prefix "$job/" --since 1h
```

After the endpoint reaches `InService`, read the artifact configured on its model:

```bash
endpoint="${WORKSHOP_STACK:-moratuwa-complaint-sagemaker}"
config=$(aws sagemaker describe-endpoint --endpoint-name "$endpoint" \
  --query EndpointConfigName --output text)
model=$(aws sagemaker describe-endpoint-config --endpoint-config-name "$config" \
  --query 'ProductionVariants[0].ModelName' --output text)
aws sagemaker describe-model --model-name "$model" \
  --query PrimaryContainer.ModelDataUrl --output text
```

Match the URI against the completed training job’s `Model` output, then invoke the endpoint using the [participant lab](participant-guide.md). For the example release, check that the response contains `"modelVersion": "phase1-cloud-v1"`.

If the job is still provisioning during the workshop, show its status and use the completed rehearsal job and endpoint for the remainder of the exercise. With the tiny dataset, the lifecycle is more useful to teach than the compute time.
