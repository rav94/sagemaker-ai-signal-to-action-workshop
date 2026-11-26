"""Deterministic split shared by training and pipeline evaluation."""

import csv

from sklearn.model_selection import train_test_split


def split_complaints(path):
    with path.open(newline="", encoding="utf-8") as data:
        rows = list(csv.DictReader(data))
    texts = [row["text"] for row in rows]
    labels = [row["label"] for row in rows]
    return train_test_split(texts, labels, test_size=0.25, random_state=42, stratify=labels)
