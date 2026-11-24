# Participant lab

Use the existing synthetic fixtures. Your instructor will share the endpoint name, region, and invocation access. If the class is running locally, follow the README and use the same request files.

## 1. Trace the training artifact

Follow the [managed training lab](cloud-training.md) using the instructor’s shared job name. Find the dataset URI, the training job status, and the output model URI. Match that output to the model attached to the endpoint. If your role only allows invocation, follow along as the instructor runs the inspection commands.

## 2. Get an insight

```bash
mkdir -p artifacts
aws sagemaker-runtime invoke-endpoint \
  --endpoint-name "${WORKSHOP_STACK:-moratuwa-complaint-sagemaker}" \
  --content-type application/json \
  --body fileb://events/complaint.json artifacts/insight.json
cat artifacts/insight.json
```

Find the category, score, and deployed version. Check that `modelVersion` matches the release your instructor deployed. Keep the billing result for the threshold exercise.

## 3. Decide how to act

```bash
python src/action.py artifacts/insight.json --minimum-score 0.35
python src/action.py artifacts/insight.json --minimum-score 0.60
```

Use the billing fixture to observe a decision change between these thresholds. Then invoke with `events/complaint-ambiguous.json` and save that result separately. Which labels could a human reasonably choose for it? Discuss how many more manual reviews a higher threshold might create and what labeled cases you would need to choose a threshold.

## 4. Inspect a rejected signal

Replace the invoke fixture with `events/complaint-invalid.json` and use `artifacts/rejected.json` as a separate output path. Inspect the error and explain why the action stage requires a valid insight. For the local lab, repeat the README curl request with that fixture and `-i` to see the container status.

If a shared endpoint is unavailable, use the local serving process or run the action exercise on `events/insight-example.json`. That example is a supplied fixture.
