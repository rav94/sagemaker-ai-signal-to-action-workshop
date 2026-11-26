"""Evaluate a trained artifact with the held-out complaint split."""

import argparse
import json
from pathlib import Path
import tarfile

import joblib
from sklearn.metrics import accuracy_score, classification_report

from dataset import split_complaints


def archive_member(archive, name):
    for member in archive.getmembers():
        if member.isfile() and member.name.removeprefix("./") == name:
            return archive.extractfile(member)
    raise ValueError(f"Missing {name} in model archive")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    with tarfile.open(args.model, "r:gz") as archive:
        with archive_member(archive, "complaint_classifier.joblib") as model_file:
            model = joblib.load(model_file)
        with archive_member(archive, "model-version.txt") as version_file:
            version = version_file.read().decode().strip()

    _, texts, _, labels = split_complaints(args.data)
    predictions = model.predict(texts)
    report = classification_report(labels, predictions, output_dict=True, zero_division=0)
    result = {
        "modelVersion": version,
        "test_count": len(labels),
        "billing_test_count": int(report["billing"]["support"]),
        "multiclass_classification_metrics": {
            "accuracy": {"value": accuracy_score(labels, predictions)},
            "billing_recall": {"value": report["billing"]["recall"]},
        },
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
