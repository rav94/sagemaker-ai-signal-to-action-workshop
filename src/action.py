"""Apply a classroom routing policy to a validated insight."""

import argparse
import json
from pathlib import Path


CATEGORIES = {"billing", "delivery", "service", "technical"}


def decide(insight, minimum_score):
    if not isinstance(insight, dict):
        raise ValueError("insight must be a JSON object")
    category = insight.get("category")
    score = insight.get("score")
    model_version = insight.get("modelVersion")
    if not isinstance(category, str) or category not in CATEGORIES:
        raise ValueError("invalid category")
    if type(score) not in (int, float) or not 0 <= score <= 1:
        raise ValueError("invalid score")
    if not isinstance(model_version, str) or not model_version.strip():
        raise ValueError("invalid model version")
    if not 0 <= minimum_score <= 1:
        raise ValueError("minimum score must be between 0 and 1")

    should_review = score < minimum_score
    return {
        "simulatedAction": "manual_review" if should_review else "route_to_category",
        "queue": "review" if should_review else category,
        "modelVersion": model_version,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("insight", type=Path)
    parser.add_argument("--minimum-score", type=float, default=0.40)
    args = parser.parse_args()
    try:
        result = decide(json.loads(args.insight.read_text()), args.minimum_score)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Action rejected: {error}\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
