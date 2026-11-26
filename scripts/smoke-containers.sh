#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

scratch=$(mktemp -d "${TMPDIR:-/tmp}/workshop-container-check.XXXXXX")
scratch=$(cd "$scratch" && pwd -P)
container=""
cleanup() {
  if [[ -n "$container" ]]; then
    docker stop "$container" >/dev/null 2>&1 || true
  fi
  rm -rf -- "$scratch"
}
trap cleanup EXIT

mkdir -p "$scratch/model"
training_image=complaint-workshop:ci-training
serving_image=complaint-workshop:ci-serving
for target in training serving; do
  docker build --platform linux/amd64 --provenance=false --sbom=false \
    --target "$target" -t "complaint-workshop:ci-$target" .
done

docker run --rm --platform linux/amd64 \
  --mount "type=bind,source=$PWD/data,target=/opt/ml/input/data/train,readonly" \
  --mount "type=bind,source=$scratch/model,target=/opt/ml/model" \
  --env WORKSHOP_MODEL_VERSION=ci-smoke "$training_image" train


mkdir -p "$scratch/archive" "$scratch/evaluation"
tar -czf "$scratch/archive/model.tar.gz" -C "$scratch/model" \
  complaint_classifier.joblib model-version.txt
docker run --rm --platform linux/amd64 --entrypoint python \
  --mount "type=bind,source=$PWD/data,target=/opt/ml/processing/data,readonly" \
  --mount "type=bind,source=$scratch/archive,target=/opt/ml/processing/model,readonly" \
  --mount "type=bind,source=$scratch/evaluation,target=/opt/ml/processing/evaluation" \
  "$training_image" /opt/program/evaluate.py \
  --model /opt/ml/processing/model/model.tar.gz \
  --data /opt/ml/processing/data/complaints.csv \
  --report /opt/ml/processing/evaluation/evaluation.json

container=$(docker run --rm --platform linux/amd64 -d -p 127.0.0.1::8080 \
  --mount "type=bind,source=$scratch/model,target=/opt/ml/model,readonly" \
  "$serving_image" serve)
address=$(docker port "$container" 8080/tcp)
url="http://$address"
for attempt in {1..20}; do
  if curl -fsS --max-time 2 "$url/ping" > "$scratch/ping.json" 2>/dev/null; then
    break
  fi
  sleep 1
done
if [[ ! -s "$scratch/ping.json" ]]; then
  docker logs "$container" >&2 || true
  echo "Serving container did not become healthy." >&2
  exit 1
fi

curl -fsS --max-time 5 -H 'Content-Type: application/json' \
  --data-binary @events/complaint.json "$url/invocations" > "$scratch/insight.json"
original_status=$(curl -sS --max-time 5 -o "$scratch/rejected.json" -w '%{http_code}' \
  -H 'Content-Type: application/json' --data-binary @events/complaint-invalid.json \
  "$url/invocations")
test "$original_status" = 400

python3 - "$scratch" <<'PY'
import json
import sys
from pathlib import Path

outputs = Path(sys.argv[1])
health = json.loads((outputs / "ping.json").read_text())
insight = json.loads((outputs / "insight.json").read_text())
error = json.loads((outputs / "rejected.json").read_text())
assert health == {"status": "ok"}, health
assert insight["modelVersion"] == "ci-smoke", insight
assert insight["category"] in {"billing", "delivery", "service", "technical"}, insight
assert type(insight["score"]) in (int, float) and 0 <= insight["score"] <= 1, insight
assert error.get("error"), error
report = json.loads((outputs / "evaluation" / "evaluation.json").read_text())
metrics = report["multiclass_classification_metrics"]
assert report["modelVersion"] == "ci-smoke" and report["billing_test_count"] > 0, report
assert all(0 <= metrics[key]["value"] <= 1 for key in ("accuracy", "billing_recall")), metrics
print("Container contract passed: health, versioned inference, and HTTP 400 for malformed input.")
PY
