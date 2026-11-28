# Participant lab

Use the existing synthetic fixtures. Your instructor will share the endpoint name, region, and invocation access. For a local session, use the [README quick start](../README.md#run-the-local-lab) and the same request fixtures.

## 1. Trace the training artifact

Follow the [Studio walkthrough](deployment-demo-playbook.md#inspect-the-run-in-studio) using the instructor’s execution ARN. Find the training artifact, evaluation report, and approved model package. Match the package’s release version to the endpoint response. If your role only allows invocation, follow along as the instructor runs the inspection commands.

## 2. Get an insight

```bash
mkdir -p artifacts
endpoint="${WORKSHOP_STACK:-sagemaker-ai-signal-insight-action-workshop}"
aws sagemaker-runtime invoke-endpoint \
  --endpoint-name "$endpoint" \
  --content-type application/json \
  --body fileb://events/complaint.json artifacts/aws-billing-insight.json &&
  cat artifacts/aws-billing-insight.json
```

Find the category, score, and deployed version. Check that `modelVersion` matches the release your instructor deployed. Keep the billing result for the threshold exercise.

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
