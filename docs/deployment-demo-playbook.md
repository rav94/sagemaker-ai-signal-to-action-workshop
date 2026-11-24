# Deployment demo playbook

## Preflight

Use AWS CLI v2, Docker with Linux AMD64 build support, and a teaching sandbox. For the local training exercise or local-artifact fallback, activate the Python 3.13 environment from the [README](../README.md).

- Confirm that the AWS profile resolves to the intended account and region.
- Check the SageMaker AI **training job quota** for `WORKSHOP_TRAINING_INSTANCE_TYPE` and the **real-time endpoint quota** for `WORKSHOP_INSTANCE_TYPE`. Both default to `ml.m5.large` and are checked separately.
- The instructor role needs permission to publish to ECR and S3, deploy both CloudFormation stacks, create and inspect a training job, and pass the training and serving execution roles. Participant invoke permissions can be limited to the shared endpoint.

```bash
export AWS_PROFILE=teaching
export AWS_REGION=us-east-1
export WORKSHOP_ACCOUNT_ID=123456789012
aws sts get-caller-identity
docker info --format '{{.ServerVersion}}'
```

Replace the example profile, region, and account ID with the approved sandbox settings. Set `WORKSHOP_STACK` only if you need a distinct endpoint and stack name. The script checks the caller account before it provisions resources.

## Run managed training and deployment

```bash
bash scripts/deploy.sh phase1-cloud-v1 --cloud-train
```

1. The assets stack creates the S3 bucket, ECR repository, and training execution role.
2. The script publishes the training and serving images to ECR and submits a training job with one CPU instance.
3. Once the job reports `Completed`, the script reads its S3 artifact URI and deploys one real-time endpoint using that archive and the serving image.
4. Check `InService`, [verify the artifact handoff](cloud-training.md#inspect-the-handoff), and run the [participant fixtures](participant-guide.md).

Record the job name and the published model URI. Use a fresh release version for another build because ECR tags are immutable. If the training job fails, see [troubleshooting](troubleshooting.md) before retrying. If the job completed but the serving stack failed, keep the printed model URI and image digest so you can retry the serving stack with those same assets.

## Rehearse with local training

If the training quota or preparation time blocks the managed run, use the local-artifact path with the same AWS settings:

```bash
source .venv/bin/activate
bash scripts/deploy.sh phase1-local-v1
```

This mode trains locally, uploads the resulting model archive, and publishes the serving image. Use the same invocation exercises. For the managed-training walkthrough, use an earlier completed job and matching endpoint capture if you have one.

After class, [delete the endpoint and assets stacks](costing.md).

[AWS SageMaker quotas](https://docs.aws.amazon.com/general/latest/gr/sagemaker.html) · [AWS real-time deployment](https://docs.aws.amazon.com/sagemaker/latest/dg/realtime-endpoints-deploy-models.html)
