"""Writes the unusual-payment artefact and the Dart parity vectors.

  app/assets/smart/unusual_params.json          constants and thresholds only; the usual
                                                amounts and hour shares come from the
                                                person's own history on the phone
  app/test/smart/fixtures/unusual_vectors.json  inputs and the Python outputs

All vector inputs are SYNTHETIC. Run from ml/: python -m unusual.export
"""

from __future__ import annotations

import json
from pathlib import Path

from common.synth import make_dataset
from unusual.data import entries_of
from unusual.evaluate import load_params
from unusual.score import SETTINGS, Entry, Params, score

ROOT = Path(__file__).resolve().parents[2]
PARAMS_OUT = ROOT / "app" / "assets" / "smart" / "unusual_params.json"
VECTORS_OUT = ROOT / "app" / "test" / "smart" / "fixtures" / "unusual_vectors.json"


def entry_json(e: Entry) -> dict:
    return {
        "amount": e.amount,
        "categoryId": e.category_id,
        "hour": e.hour,
        "payeeKey": e.payee_key,
        "day": e.day,
    }


def expected_json(entry: Entry, history: list[Entry], p: Params, setting: str) -> dict:
    r = score(entry, history, p, setting)
    s = r.signals
    return {
        "score": r.score,
        "flagged": r.flagged,
        "reasons": list(r.reasons),
        "gatePassed": s.gate_passed,
        "amountZ": s.amount_z,
        "usualAmount": s.usual_amount,
        "basis": s.basis,
        "hourShare": s.hour_share,
        "newPayee": s.new_payee,
    }


def _e(amount: int, cat: str = "cat.food", hour: int = 12, key: str = "lunch", day: int = 0) -> Entry:
    return Entry(amount, cat, hour, key, day)


def hand_cases() -> list[tuple[str, list[Entry], Entry, str]]:
    """Edge cases: (name, history, entry, setting)."""
    flat = [_e(5000, day=d) for d in range(25)]  # MAD 0, so the floor applies
    even = [_e(4000 + 100 * (d % 6), key=f"shop {d % 3}", day=d) for d in range(24)]
    rent = [_e(600000, cat="cat.bills", hour=9, key="house rent", day=30 * m) for m in range(5)]
    bills = [_e(5000 + 500 * (d % 7), cat="cat.bills", hour=20, key="mtn airtime", day=d) for d in range(30)]
    return [
        ("empty history", [], _e(9000, key="new shop"), "balanced"),
        ("zero amount", flat, _e(0), "balanced"),
        ("flat history, ten times", flat, _e(50000), "balanced"),
        ("flat history, same amount", flat, _e(5000), "often"),
        ("even count median", even, _e(30000, key="shop 1"), "balanced"),
        ("typo is not a new payee", even, _e(4200, key="sohp 1"), "often"),
        ("two edits is a new payee", even, _e(4200, key="xyop 1"), "often"),
        ("empty payee key", even, _e(4200, key=""), "often"),
        ("odd hour", even, _e(4200, hour=3, key="shop 2"), "balanced"),
        ("rent against its own history", bills + rent, _e(601000, cat="cat.bills", hour=9, key="house rent", day=160), "balanced"),
        ("first rent against airtime", bills, _e(600000, cat="cat.bills", hour=9, key="house rent", day=40), "rarely"),
        ("gate not passed", even[:19], _e(90000, key="shop 1"), "often"),
    ]


def vectors(p: Params) -> dict:
    rows = make_dataset(seed=31, days=200)
    entries = entries_of(rows)
    anomaly_idx = [i for i, r in enumerate(rows) if r["is_anomaly"]]
    normal_idx = [i for i in range(40, len(rows), 30) if not rows[i]["is_anomaly"]]
    targets = sorted(set(anomaly_idx + normal_idx))
    seq_targets = [
        {"index": i, "setting": SETTINGS[k % 3], "expected": expected_json(entries[i], entries[:i], p, SETTINGS[k % 3])}
        for k, i in enumerate(targets)
    ]
    cases = [
        {
            "name": name,
            "history": [entry_json(h) for h in hist],
            "entry": entry_json(e),
            "setting": setting,
            "expected": expected_json(e, hist, p, setting),
        }
        for name, hist, e, setting in hand_cases()
    ]
    return {
        "synthetic": True,
        "note": "Inputs are synthetic (ml/common/synth.py seed 31, 200 days, plus hand-made edge cases).",
        "params": p.to_json(),
        "sequence": {
            "entries": [entry_json(e) for e in entries],
            "targets": seq_targets,
        },
        "cases": cases,
    }


def export() -> tuple[int, int]:
    p = load_params()
    PARAMS_OUT.parent.mkdir(parents=True, exist_ok=True)
    artefact = {
        "model": "unusual_payment",
        "version": 1,
        "synthetic_tuning": "Thresholds tuned on synthetic seeds 101-110 only; see ml/unusual/RESULTS.md.",
        **p.to_json(),
    }
    PARAMS_OUT.write_text(json.dumps(artefact, indent=2) + "\n", encoding="utf-8", newline="\n")
    v = vectors(p)
    VECTORS_OUT.parent.mkdir(parents=True, exist_ok=True)
    VECTORS_OUT.write_text(json.dumps(v) + "\n", encoding="utf-8", newline="\n")
    return len(v["sequence"]["targets"]), len(v["cases"])


if __name__ == "__main__":
    n_seq, n_cases = export()
    print(f"wrote {PARAMS_OUT.name} and {n_seq} + {n_cases} vectors")
