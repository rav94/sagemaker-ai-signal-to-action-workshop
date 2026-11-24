#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?Usage: bash scripts/package-model.sh MODEL_VERSION}"
if [[ ! "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "Use letters, digits, dots, underscores or hyphens for MODEL_VERSION." >&2
  exit 2
fi

artifact_dir="${WORKSHOP_MODEL_DIR:-artifacts}"
WORKSHOP_MODEL_DIR="$artifact_dir" WORKSHOP_MODEL_VERSION="$version" \
  "${WORKSHOP_PYTHON:-python}" src/train.py
tar -czf "$artifact_dir/model.tar.gz" -C "$artifact_dir" \
  complaint_classifier.joblib model-version.txt
