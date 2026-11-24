from pathlib import Path
import csv
import joblib
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, confusion_matrix

ROOT = Path(__file__).resolve().parents[1]
with (ROOT / "data/complaints.csv").open(newline="") as f:
    rows = list(csv.DictReader(f))

texts = [row["text"] for row in rows]
labels = [row["label"] for row in rows]
X_train, X_test, y_train, y_test = train_test_split(
    texts, labels, test_size=0.25, random_state=42, stratify=labels
)

model = Pipeline([
    ("tfidf", TfidfVectorizer(ngram_range=(1, 2))),
    ("classifier", LogisticRegression(max_iter=1000, random_state=42)),
])
model.fit(X_train, y_train)
predictions = model.predict(X_test)
print(f"Train: {len(X_train)} | Test: {len(X_test)}")
print(classification_report(y_test, predictions, zero_division=0))
print("Confusion matrix (labels sorted alphabetically):")
print(model.classes_)
print(confusion_matrix(y_test, predictions, labels=model.classes_))

artifact = ROOT / "artifacts/complaint_classifier.joblib"
artifact.parent.mkdir(parents=True, exist_ok=True)
joblib.dump(model, artifact)
print(f"Saved model to: {artifact}")
