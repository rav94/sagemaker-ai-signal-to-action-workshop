# Participant lab

Use the existing synthetic fixtures. Your instructor will share the endpoint name, region, and invocation access. For a local session, use the [README quick start](../README.md#run-the-local-lab) and the same request fixtures.

## 1. Trace the training artifact

Follow the [managed training lab](cloud-training.md) using the instructor’s shared job name. Find the dataset URI, the training job status, and the output model URI. Match that output to the model attached to the endpoint. If your role only allows invocation, follow along as the instructor runs the inspection commands.

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

## 5. Inspect the safeguards

Follow the [guardrails lab](guardrails.md) after verifying the baseline endpoint. Compare the endpoint configuration and model version before and after the instructor's guarded rollout. Then screen a normal complaint and a synthetic email complaint. Confirm that the normal case can return an insight and the intervention stops before inference. If your role lacks content-check or deployment privileges, use the instructor's captured run.

If a shared endpoint is unavailable, use the local serving process or run the action exercise on `events/insight-example.json`. That example is a supplied fixture.
