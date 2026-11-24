# Participant lab

Use the existing synthetic fixtures. Your instructor will share the endpoint name, region, and invocation access. If the class is running locally, follow the README and use the same request files.

## 1. Get an insight

```bash
mkdir -p artifacts
aws sagemaker-runtime invoke-endpoint \
  --endpoint-name "${WORKSHOP_STACK:-moratuwa-complaint-sagemaker}" \
  --content-type application/json \
  --body fileb://events/complaint.json artifacts/insight.json
cat artifacts/insight.json
```

Find the category, score, and deployed version. Repeat with `events/complaint-ambiguous.json`. Which labels could a human reasonably choose for that complaint?

## 2. Decide how to act

```bash
python src/action.py artifacts/insight.json --minimum-score 0.35
python src/action.py artifacts/insight.json --minimum-score 0.60
```

Use the billing fixture to observe a decision change between these thresholds. Then try the ambiguous fixture. Discuss how many more manual reviews a higher threshold might create and what labeled cases you would need to choose a threshold.

## 3. Inspect a rejected signal

Replace the invoke fixture with `events/complaint-invalid.json` and use `artifacts/rejected.json` as a separate output path. Inspect the error and explain why the action stage requires a valid insight. For the local lab, repeat the README curl request with that fixture and `-i` to see the container status.

If a shared endpoint is unavailable, use the local serving process or run the action exercise on `events/insight-example.json`. That example is a supplied fixture.
