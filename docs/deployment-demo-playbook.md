# Deployment demo playbook

Prerequisites are AWS CLI v2, Docker with Linux AMD64 build support, Python 3.13 with the workshop requirements installed, and permission to deploy in an approved teaching sandbox. Verify the caller account, region, training-job quota, and real-time endpoint quota before deployment.

```bash
export AWS_PROFILE=teaching
export AWS_REGION=us-east-1
export WORKSHOP_ACCOUNT_ID=123456789012
aws sts get-caller-identity
bash scripts/deploy.sh phase1-cloud-v1 --cloud-train
```

Replace all example values with the approved sandbox settings. The script checks the account, provisions the asset stack, publishes both containers, and deploys the artifact produced by the [managed training job](cloud-training.md). To rehearse with locally trained weights, use `bash scripts/deploy.sh phase1-local-v1`. Set `WORKSHOP_INSTANCE_TYPE` if the teaching sandbox requires a different supported AMD64 CPU instance. Set `WORKSHOP_STACK` if you need a distinct endpoint and stack name. Use a fresh release tag for another build. If deployment stops after an image push, inspect CloudFormation events and use a fresh release tag or redeploy with the previously published digest and artifact key from the script output.

To grant participants inference access, scope `sagemaker:InvokeEndpoint` to the specific endpoint ARN and give them sandbox credentials through your normal identity system. Keep stack administration on the instructor role.

Run the [participant fixtures](participant-guide.md) once when ready. Use the [cleanup sequence](costing.md) after the final invocation.

[AWS endpoint deployment](https://docs.aws.amazon.com/sagemaker/latest/dg/realtime-endpoints-deploy-models.html)
