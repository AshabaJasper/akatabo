"""Evaluates the tuned unusual-payment score on the held-out SYNTHETIC seed 7.

Every number this prints is measured on synthetic data with injected anomalies
(common.synth.inject_anomalies). None of it is real-world performance.

Baselines, run on the same rows with the same 20-entry category gate:
  amount_only     the robust amount z alone (no hour, no payee), threshold set to the
                  setting's threshold (the same scale as the full score)
  three_x_median  flag when the amount is over 3 times the category's median amount

Run from ml/: python -m unusual.evaluate
"""

from __future__ import annotations

import json
from pathlib import Path

from common.synth import make_dataset
from regular.payee import median
from unusual.data import TEST_SEED, entries_of
from unusual.metrics import Counts, count
from unusual.score import SETTINGS, Params, combine, signals

HERE = Path(__file__).resolve().parent


def load_params() -> Params:
    raw = json.loads((HERE / "tuned.json").read_text(encoding="utf-8"))["params"]
    return Params(
        min_category_history=raw["minCategoryHistory"],
        min_payee_history=raw["minPayeeHistory"],
        mad_scale=raw["madScale"],
        mad_floor=raw["madFloor"],
        amount_reason_z=raw["amountReasonZ"],
        hour_share_min=raw["hourShareMin"],
        hour_weight=raw["hourWeight"],
        payee_weight=raw["payeeWeight"],
        thresholds=dict(raw["thresholds"]),
    )


def as_dict(c: Counts) -> dict:
    return {
        "precision": round(c.precision, 4),
        "recall": round(c.recall, 4),
        "flags_per_100_normal": round(c.flags_per_100_normal, 3),
        "tp": c.tp,
        "fp": c.fp,
        "fn": c.fn,
        "normal_entries": c.normal,
    }


def evaluate(seed: int = TEST_SEED) -> dict:
    p = load_params()
    rows = make_dataset(seed)
    entries = entries_of(rows)
    labels = [int(r["is_anomaly"]) for r in rows]
    sigs = [signals(e, entries[:i], p) for i, e in enumerate(entries)]

    out: dict = {"synthetic": True, "seed": seed, "rows": len(rows), "anomalies": sum(labels)}
    out["score"] = {s: as_dict(count([combine(x, p, s).flagged for x in sigs], labels)) for s in SETTINGS}
    out["baseline_amount_only"] = {
        s: as_dict(count([x.gate_passed and x.amount_z >= p.thresholds[s] for x in sigs], labels))
        for s in SETTINGS
    }
    three_x = []
    for i, e in enumerate(entries):
        cat = [h.amount for h in entries[:i] if h.category_id == e.category_id]
        three_x.append(len(cat) >= p.min_category_history and e.amount > 3 * median(cat))
    out["baseline_three_x_median"] = as_dict(count(three_x, labels))

    by_kind = {}
    for kind in ("amount", "hour", "payee"):
        idx = [i for i, r in enumerate(rows) if r["template"] == f"anomaly_{kind}"]
        caught = sum(1 for i in idx if combine(sigs[i], p, "balanced").flagged)
        gated = sum(1 for i in idx if not sigs[i].gate_passed)
        by_kind[kind] = {"injected": len(idx), "caught_balanced": caught, "before_gate": gated}
    out["balanced_recall_by_kind"] = by_kind
    return out


if __name__ == "__main__":
    print(json.dumps(evaluate(), indent=2))
