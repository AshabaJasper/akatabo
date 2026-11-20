"""Trains the category model on SYNTHETIC entries (ml/common/synth.py). Seeded and
deterministic: the same seed gives the same vocabulary and coefficients.

Run from ml/:  python -m category.train
"""

from __future__ import annotations

import numpy as np
from sklearn.linear_model import LogisticRegression

from common.synth import make_dataset

from .features import design_matrix, make_vectoriser, normalise

SEED = 7
C = 4.0


def category_rows(seed: int = SEED) -> list[dict]:
    """The synthetic rows the category model learns from. Injected anomalies are left out:
    they borrow descriptions from the everyday templates without their template id, so they
    would leak merchants across the template split (they exist for the unusual model)."""
    return [r for r in make_dataset(seed) if not r["is_anomaly"]]


def fit(rows: list[dict]):
    vec = make_vectoriser()
    vec.fit([normalise(r["description"]) for r in rows])
    X = design_matrix(vec, [r["description"] for r in rows], [r["amount"] for r in rows], [r["hour"] for r in rows])
    y = np.array([r["category_id"] for r in rows])
    clf = LogisticRegression(C=C, max_iter=5000, solver="lbfgs", random_state=0)
    clf.fit(X, y)
    return vec, clf


def predict_proba(vec, clf, descriptions, amounts, hours) -> np.ndarray:
    return clf.predict_proba(design_matrix(vec, descriptions, amounts, hours))


def train_final(seed: int = SEED):
    return fit(category_rows(seed))


if __name__ == "__main__":
    rows = category_rows()
    vec, clf = fit(rows)
    print(f"trained on {len(rows)} synthetic rows; vocabulary {len(vec.vocabulary_)}; classes {list(clf.classes_)}")
