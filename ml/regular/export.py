"""Writes the regular-payment artefact and the Dart parity vectors.

  app/assets/smart/regular_params.json          the rule's constants only
  app/test/smart/fixtures/regular_vectors.json  inputs and the Python outputs

All vector inputs are SYNTHETIC. Run from ml/: python -m regular.export
"""

from __future__ import annotations

import json
import random
from pathlib import Path

from common.synth import generate_everyday, generate_regular
from regular.detect import Params, Payment, Series, detect
from regular.evaluate import load_params, payments_of

ROOT = Path(__file__).resolve().parents[2]
PARAMS_OUT = ROOT / "app" / "assets" / "smart" / "regular_params.json"
VECTORS_OUT = ROOT / "app" / "test" / "smart" / "fixtures" / "regular_vectors.json"


def series_json(s: Series) -> dict:
    return {
        "payeeKey": s.payee_key,
        "categoryId": s.category_id,
        "occurrences": s.occurrences,
        "interval": s.interval,
        "intervalDays": s.interval_days,
        "gapCv": s.gap_cv,
        "typicalAmount": s.typical_amount,
        "amountLow": s.amount_low,
        "amountHigh": s.amount_high,
        "lastDay": s.last_day,
        "nextDay": s.next_day,
        "nextDueFromToday": s.next_due_from_today,
    }


def payment_json(x: Payment) -> dict:
    return {"amount": x.amount, "categoryId": x.category_id, "payeeKey": x.payee_key, "day": x.day}


def _p(day: int, amount: int = 45000, key: str = "dstv", cat: str = "cat.bills") -> Payment:
    return Payment(amount, cat, key, day)


def hand_cases() -> list[tuple[str, list[Payment], int]]:
    monthly = [_p(d) for d in (3, 33, 62, 93, 122)]
    return [
        ("nothing", [], 100),
        ("two payments only", [_p(1), _p(31)], 40),
        ("monthly", monthly, 130),
        ("monthly with a missed month", [_p(d) for d in (3, 33, 93, 122, 153)], 160),
        ("daily lunch is not a bill", [_p(d, 5000, "posho lunch", "cat.food") for d in range(0, 40)], 40),
        ("every 4 days is too often", [_p(d, 5000, "water jerrycan") for d in range(0, 60, 4)], 60),
        ("stopped long ago", monthly, 122 + 90),
        ("next due rolls past today", monthly, 175),
        ("amounts all over the place", [_p(d, a) for d, a in zip((3, 33, 63, 93), (10000, 45000, 90000, 20000))], 100),
        ("one odd amount inside the share", [_p(d, a) for d, a in zip((3, 33, 63, 93, 123), (45000, 45200, 44800, 90000, 45000))], 130),
        ("irregular gaps", [_p(d) for d in (0, 9, 40, 47, 90, 101)], 110),
        ("same day twice", [_p(d) for d in (3, 3, 33, 63)], 70),
        ("two categories, tie", [_p(3, cat="cat.other"), _p(33), _p(63, cat="cat.other"), _p(93)], 100),
        ("half-day median rounds up", [_p(d) for d in (0, 30, 61, 91, 122)], 130),
        ("weekly", [_p(d, 20000, "church offering", "cat.family") for d in range(0, 70, 7)], 70),
        ("empty key ignored", [_p(d, key="") for d in (3, 33, 63, 93)], 100),
    ]


def synthetic_inputs(n: int) -> list[tuple[str, list[Payment], int]]:
    out = []
    for i in range(n):
        seed = 500 + i
        days = 200 + 20 * (i % 5)
        rng = random.Random(seed)
        everyday = generate_everyday(seed, days)
        rows = generate_regular(seed, days) + rng.sample(everyday, min(60, len(everyday)))
        rows.sort(key=lambda r: (r["day"], r["description"]))
        out.append((f"synthetic seed {seed}, {days} days", payments_of(rows), days - 1))
    return out


def export() -> int:
    p: Params = load_params()
    PARAMS_OUT.parent.mkdir(parents=True, exist_ok=True)
    PARAMS_OUT.write_text(
        json.dumps(
            {
                "model": "regular_payment",
                "version": 1,
                "synthetic_tuning": "Constants chosen on synthetic seeds 101-110 only; see ml/regular/RESULTS.md.",
                **p.to_json(),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8", newline="\n",
    )
    cases = [
        {
            "name": name,
            "today": today,
            "payments": [payment_json(x) for x in pays],
            "expected": [series_json(s) for s in detect(pays, today, p)],
        }
        for name, pays, today in hand_cases() + synthetic_inputs(16)
    ]
    VECTORS_OUT.parent.mkdir(parents=True, exist_ok=True)
    VECTORS_OUT.write_text(
        json.dumps({"synthetic": True, "params": p.to_json(), "cases": cases}) + "\n", encoding="utf-8", newline="\n"
    )
    return len(cases)


if __name__ == "__main__":
    print(f"wrote {PARAMS_OUT.name} and {export()} vectors")
