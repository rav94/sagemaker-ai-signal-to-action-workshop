# Deployment demo playbook

## Preflight

Use AWS CLI v2, Docker with Linux AMD64 build support, and a teaching sandbox. For the local training exercise or local-artifact fallback, activate the Python 3.13 environment from the [README](../README.md).

- Confirm that the AWS profile resolves to the intended account and region.
- Check separate quotas for training (`ml.t3.large`), evaluation Processing (`ml.t3.medium`), and real-time hosting (`ml.t2.medium`).
- The instructor role needs to publish to ECR and S3, deploy the workshop stacks, pass the pipeline and job roles, and start and inspect the pipeline execution. Participant roles can be limited to inspection and inference.

```bash
export AWS_PROFILE="your-teaching-profile"
export AWS_REGION=us-east-1
aws sts get-caller-identity
# After confirming the account above, replace this example ID.
export WORKSHOP_ACCOUNT_ID=123456789012
docker info --format '{{.ServerVersion}}'
```

Replace the example profile, region, and account ID with the approved sandbox settings. Set `WORKSHOP_STACK` only if you need a distinct endpoint and stack name. The script checks the caller account before it provisions resources.

## Run the pipeline and promote a model

1. Start the [native SageMaker Pipeline](sagemaker-pipeline.md) and inspect the training output, evaluation report, and gate.
2. Review the pending candidate in the [Registry lab](model-registry-ci-cd.md). Demonstrate the blocked promotion, approve it, then deploy through GitHub Actions or the terminal.
3. Verify `InService` and the release version using the [participant fixtures](participant-guide.md).

Before the [guardrails lab](guardrails.md), record the baseline endpoint configuration and check quota for overlapping fleets. Use the [direct training walkthrough](cloud-training.md) if you want to inspect each training API call separately.

## Rehearse with local training

If the training quota or preparation time blocks the managed run, use the local-artifact path with the same AWS settings:

```bash
source .venv/bin/activate
bash scripts/deploy.sh phase1-local-v1
```

This mode trains locally, uploads the resulting model archive, and publishes the serving image. Use the same invocation exercises. For the Studio walkthrough, use a completed pipeline execution from rehearsal if you have one.

After class, [delete the endpoint and assets stacks](costing.md).

[AWS SageMaker quotas](https://docs.aws.amazon.com/general/latest/gr/sagemaker.html) · [AWS real-time deployment](https://docs.aws.amazon.com/sagemaker/latest/dg/realtime-endpoints-deploy-models.html)
