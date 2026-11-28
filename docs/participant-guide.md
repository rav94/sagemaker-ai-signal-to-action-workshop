# Participant lab

Follow the instructor during the live demo. To run the AWS lab later, use the repo root, AWS CLI v2 with credentials that can invoke the endpoint, and your instructor's Region and endpoint name. Python is needed for the routing exercise. To practice without an AWS endpoint, use the [local lab](../README.md#run-the-local-lab) with the same fixtures.

## 1. Trace the training artifact

Follow the [Studio walkthrough](deployment-demo-playbook.md#inspect-the-run-in-studio) using the instructor’s execution ARN. Find the training artifact, evaluation report, and approved model package. Match the package’s release version to the endpoint response. If your role only allows invocation, follow along as the instructor runs the inspection commands.

## 2. Get an insight

```bash
mkdir -p artifacts
endpoint='sagemaker-ai-signal-insight-action-workshop' # Replace if your instructor shares a different name.
aws sagemaker-runtime invoke-endpoint \
  --endpoint-name "$endpoint" \
  --content-type application/json \
  --body fileb://events/complaint.json artifacts/aws-billing-insight.json &&
  cat artifacts/aws-billing-insight.json
```

Use the instructor's AWS Region for both invoke commands. Find the category, score, and deployed version. Check that `modelVersion` matches the release your instructor deployed. Keep the billing result for the threshold exercise.

## 3. Decide how to act

```bash
python src/action.py artifacts/aws-billing-insight.json --minimum-score 0.35
python src/action.py artifacts/aws-billing-insight.json --minimum-score 0.60
```

Continue with this file after the invoke command succeeds. The billing fixture should route to `billing` at `0.35` and go to `manual_review` at `0.60`. Then invoke with `events/complaint-ambiguous.json` and save that result separately. Which labels could a human reasonably choose for it? Discuss how many more manual reviews a higher threshold might create and what labeled cases you would need to choose a threshold.

## 4. Inspect a rejected signal

Send the malformed fixture in a separate invocation:

```bash
aws sagemaker-runtime invoke-endpoint \
  --endpoint-name "$endpoint" \
  --content-type application/json \
  --body fileb://events/complaint-invalid.json artifacts/aws-rejected.json
```

Expect the command to fail with `ModelError`. The container returned HTTP 400. The AWS service wraps that as HTTP 424 and includes the original status in the error details. For the local lab, send the same fixture with `curl -i` to see the container status directly. [AWS InvokeEndpoint errors](https://docs.aws.amazon.com/sagemaker/latest/APIReference/API_runtime_InvokeEndpoint.html#API_runtime_InvokeEndpoint_Errors)

## Observe content screening

In the instructor's [content screening lab](guardrails.md), compare an ordinary billing complaint with a second billing complaint that includes a synthetic email address. Watch for the inference JSON on the cleared request and the caller's intervention message when it skips the endpoint. Running the screening lab yourself requires access to the shared Bedrock guardrail and the SageMaker endpoint.

## Observe the rollout

During the instructor's [rollback drill](model-registry-ci-cd.md#demonstrate-rollback), use a fresh response after the alarm to check that the endpoint serves the baseline `modelVersion` again.
