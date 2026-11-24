#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?Usage: bash scripts/package-model.sh MODEL_VERSION}"
if [[ ! "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "Use letters, digits, dots, underscores or hyphens for MODEL_VERSION." >&2
  exit 2
fi

"${WORKSHOP_PYTHON:-python}" src/train.py
printf '%s\n' "$version" > artifacts/model-version.txt
tar -czf artifacts/model.tar.gz -C artifacts complaint_classifier.joblib model-version.txt
