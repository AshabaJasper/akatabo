"""Exports the category model for the phone, and the parity vectors for the Dart test.

Writes
  app/assets/smart/category_model.json            the model (SYNTHETIC training data)
  app/test/smart/fixtures/category_vectors.json   inputs and the probabilities Python gives

Numbers are rounded to SIG_DIGITS significant digits to keep the file small. The fixture
probabilities are computed from the rounded file (ExportedModel below), so the Dart test
checks the phone against exactly what ships; a pytest checks the rounding barely moves
sklearn's own probabilities.

Run from ml/:  python -m category.export
"""

from __future__ import annotations

import json
import math
from collections import Counter
from pathlib import Path

from .features import AMOUNT_EDGES, HOUR_EDGES, NGRAM_MAX, NGRAM_MIN, amount_bucket, char_wb_ngrams, hour_bucket, normalise
from .personal import PersonalLayer, blend
from .train import C, SEED, train_final

ROOT = Path(__file__).resolve().parents[2]
MODEL_PATH = ROOT / "app" / "assets" / "smart" / "category_model.json"
FIXTURE_PATH = ROOT / "app" / "test" / "smart" / "fixtures" / "category_vectors.json"
FORMAT = "akatabo.category.v1"
SIG_DIGITS = 6


def _r(x: float) -> float:
    return float(f"{x:.{SIG_DIGITS}g}")


def model_dict(vec, clf) -> dict:
    vocab = sorted(vec.vocabulary_.items(), key=lambda kv: kv[1])
    assert [i for _, i in vocab] == list(range(len(vocab)))
    return {
        "format": FORMAT,
        "synthetic": True,
        "note": "Trained on SYNTHETIC entries from ml/common/synth.py; not real-world data.",
        "seed": SEED,
        "c": C,
        "ngram": [NGRAM_MIN, NGRAM_MAX],
        "classes": [str(c) for c in clf.classes_],
        "vocabulary": [g for g, _ in vocab],
        "idf": [_r(v) for v in vec.idf_],
        "amountEdges": list(AMOUNT_EDGES),
        "hourEdges": list(HOUR_EDGES),
        "coef": [[_r(v) for v in row] for row in clf.coef_],
        "intercept": [_r(v) for v in clf.intercept_],
    }


class ExportedModel:
    """Computes probabilities from the exported JSON alone, in the order the Dart code does."""

    def __init__(self, d: dict) -> None:
        self.classes = d["classes"]
        self.index = {g: i for i, g in enumerate(d["vocabulary"])}
        self.idf = d["idf"]
        self.coef = d["coef"]
        self.intercept = d["intercept"]
        self.n_min, self.n_max = d["ngram"]
        self.amount_edges = d["amountEdges"]
        self.hour_edges = d["hourEdges"]

    def probabilities(self, description: str, amount: int, hour: int) -> dict[str, float]:
        counts = Counter(g for g in char_wb_ngrams(normalise(description), self.n_min, self.n_max) if g in self.index)
        x = {self.index[g]: n * self.idf[self.index[g]] for g, n in counts.items()}
        norm = math.sqrt(sum(v * v for v in x.values()))
        if norm > 0:
            x = {j: v / norm for j, v in x.items()}
        v = len(self.index)
        a = v + amount_bucket(amount)
        h = v + len(self.amount_edges) + 1 + hour_bucket(hour)
        logits = []
        for k in range(len(self.classes)):
            row = self.coef[k]
            z = self.intercept[k]
            for j in sorted(x):
                z += row[j] * x[j]
            z += row[a] + row[h]
            logits.append(z)
        top = max(logits)
        exps = [math.exp(z - top) for z in logits]
        s = sum(exps)
        return {c: e / s for c, e in zip(self.classes, exps)}


# Inputs for the parity test: typos, Luganda, unknown words, empty text, bucket edges.
PARITY_INPUTS: list[tuple[str, int, int]] = [
    ("Nakasero market", 15000, 9), ("nakasero mkt", 12000, 17), ("Kalerwe market veg", 9800, 8),
    ("matooke", 20000, 18), ("posho and beans", 5000, 12), ("emmere", 4500, 13), ("pozho", 5000, 12),
    ("Quality Supermarket", 42000, 19), ("grocries", 38000, 18), ("Cafe Javas", 9000, 11),
    ("boda to work", 4000, 7), ("bodaboda home", 3500, 19), ("matatu to Ntinda", 2500, 8),
    ("Shell fuel", 60000, 9), ("petrol for car", 75000, 18), ("MTN airtime", 5000, 20),
    ("airtme top up", 2000, 21), ("Umeme prepaid", 30000, 10), ("yaka electricity", 25000, 9),
    ("NWSC water", 20000, 10), ("Smile internet", 80000, 9), ("skul fees", 250000, 10),
    ("Kampala Parents school", 300000, 11), ("exercise books", 18000, 14), ("MoMo to mother", 100000, 8),
    ("Mama upkeep", 150000, 19), ("paracetamol", 3000, 16), ("chemist", 12000, 17),
    ("hair salon", 15000, 14), ("house rent", 600000, 9), ("DStv subscription", 45000, 20),
    ("Netflix", 35000, 2), ("Jubilee insurance", 120000, 9), ("", 5000, 12),
    ("!!!", 1000, 0), ("Groceries, Nakasero  market", 1000000, 23), ("nyama ya mbuzi", 999, 5),
    ("new payee 4821", 2000, 6), ("ÉCOLE fees", 200000, 22), ("Kikuubo chips", 1999, 14),
    ("taxi fare", 500, 6), ("a", 100000, 13),
]

# A small history for the blend fixtures: a correction on a known payee and a person's own
# category ("cat.custom.work") that the model has never seen.
BLEND_HISTORY: list[tuple[str, str]] = [
    ("Nakasero market", "cat.food"), ("Nakasero market", "cat.food"), ("Nakasero market", "cat.family"),
    ("boda to work", "cat.custom.work"), ("boda to office", "cat.custom.work"),
    ("MTN airtime", "cat.bills"), ("posho lunch", "cat.food"), ("Java House", "cat.other"),
]
BLEND_INPUTS: list[tuple[str, int, int]] = [
    ("Nakasero market", 15000, 9), ("nakasero mkt", 15000, 9), ("boda to work", 4000, 7),
    ("boda to town", 4000, 8), ("MTN bundles", 5000, 20), ("Java House", 9000, 11),
    ("Umeme prepaid", 30000, 10), ("", 5000, 12),
]


def fixtures(model: ExportedModel) -> dict:
    cases = []
    for d, a, h in PARITY_INPUTS:
        p = model.probabilities(d, a, h)
        cases.append({"description": d, "amount": a, "hour": h, "probs": p, "top": max(p, key=p.get)})
    layer = PersonalLayer()
    for d, c in BLEND_HISTORY:
        layer.add(d, c)
    blended = []
    for d, a, h in BLEND_INPUTS:
        p = blend(model.probabilities(d, a, h), layer, d)
        blended.append({"description": d, "amount": a, "hour": h, "probs": p, "top": max(p, key=p.get)})
    return {
        "synthetic": True,
        "note": "Probabilities from ml/category/export.py on the exported (rounded) model.",
        "model": cases,
        "blend": {"history": [{"description": d, "categoryId": c} for d, c in BLEND_HISTORY], "cases": blended},
    }


def main() -> None:
    vec, clf = train_final()
    d = model_dict(vec, clf)
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    MODEL_PATH.write_text(json.dumps(d, separators=(",", ":")), encoding="utf-8", newline="\n")
    FIXTURE_PATH.parent.mkdir(parents=True, exist_ok=True)
    FIXTURE_PATH.write_text(json.dumps(fixtures(ExportedModel(d)), indent=1, ensure_ascii=False), encoding="utf-8", newline="\n")
    print(f"wrote {MODEL_PATH.relative_to(ROOT)} ({MODEL_PATH.stat().st_size // 1024} KB)")
    print(f"wrote {FIXTURE_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
