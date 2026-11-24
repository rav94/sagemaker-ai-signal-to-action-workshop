from pathlib import Path
import sys
import joblib

ROOT = Path(__file__).resolve().parents[1]
artifact = ROOT / "artifacts/complaint_classifier.joblib"
if not artifact.exists():
    raise SystemExit("Train the model first: python src/train.py")

model = joblib.load(artifact)  # Only load trusted artifacts.
texts = sys.argv[1:] or [
    "I was charged twice for the same order",
    "The dashboard crashes whenever I upload data",
    "My delivery is late and the tracking number is invalid",
    "The help desk agent was rude",
]
for complaint, prediction, probabilities in zip(
    texts, model.predict(texts), model.predict_proba(texts)
):
    top = max(probabilities)
    print(f"{complaint}\n  -> {prediction} (model probability: {top:.2%})")
