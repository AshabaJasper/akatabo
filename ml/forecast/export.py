"""Writes the forecast range constants for the phone and the parity vectors for the Dart test.

* app/assets/smart/forecast_params.json: constants only (no data, nothing about a person).
* app/test/smart/fixtures/forecast_vectors.json: SYNTHETIC inputs and the Python outputs.

Run from ml/:  python -m forecast.export
"""

from __future__ import annotations

import json
import random
from pathlib import Path

from forecast import range as fr

ROOT = Path(__file__).resolve().parents[2]
PARAMS = ROOT / "app" / "assets" / "smart" / "forecast_params.json"
VECTORS = ROOT / "app" / "test" / "smart" / "fixtures" / "forecast_vectors.json"


def params() -> dict:
    return {
        "version": 1,
        "prng": {
            "kind": "xorshift32",
            "shifts": [13, 17, 5],
            "seed": fr.SEED,
            "seedRule": "state = (seed XOR dayOfMonth) AND 0xFFFFFFFF; if 0 then seed",
            "index": "state mod n",
        },
        "samples": fr.SAMPLES,
        "percentileLow": fr.P_LOW,
        "percentileHigh": fr.P_HIGH,
        "percentileMethod": "linear interpolation, h = (n - 1) * p",
        "snapshotAdjustment": {
            "shrinkMonths": fr.SHRINK_MONTHS,
            "maxMonths": fr.MAX_MONTHS,
            "rule": (
                "w = k / (k + shrinkMonths); lo' = lo + w * min(0, p10(errors) - lo); "
                "hi' = hi + w * max(0, p90(errors) - hi); lo, hi relative to the point; "
                "error = (actual - snapshot point) / snapshot point"
            ),
        },
    }


def _case(rng: random.Random, i: int) -> dict:
    n = rng.choice((0, 7, 12, 30, 45, 90)) if i > 0 else 0
    style = rng.random()
    daily = []
    for _ in range(n):
        if rng.random() < 0.2:
            daily.append(0)
        elif style < 0.3:
            daily.append(rng.randrange(0, 200) * 100)
        else:
            daily.append(int(rng.lognormvariate(10, 0.8)) // 100 * 100)
    if i == 1:
        daily = [0] * n  # with no spending and no regular payments the point is 0
    regular = []
    for _ in range(rng.randint(0, 3)):
        typ = rng.randrange(20, 700) * 1000
        regular.append({"low": typ - rng.randrange(0, 5) * 1000, "typical": typ, "high": typ + rng.randrange(0, 5) * 1000})
    k = rng.choice((0, 0, 1, 2, 5, 14))
    errors = [round(rng.uniform(-0.4, 0.6), 6) for _ in range(k)]
    return {
        "spentSoFar": rng.randrange(0, 3_000_000) if i != 1 else 0,
        "daily": daily,
        "spentToday": rng.choice((0, 0, 5000, 40000)),
        "daysLeft": rng.choice((0, 1, 9, 17, 23, 30)),
        "regular": regular if i != 1 else [],
        "dayOfMonth": rng.randint(1, 31),
        "snapshotErrors": errors,
    }


def vectors() -> dict:
    rng = random.Random(2026)
    cases = []
    for i in range(20):
        inp = _case(rng, i)
        r = fr.forecast_range(
            spent_so_far=inp["spentSoFar"],
            daily=inp["daily"],
            spent_today=inp["spentToday"],
            days_left=inp["daysLeft"],
            regular=[fr.RegularBand(**b) for b in inp["regular"]],
            day_of_month=inp["dayOfMonth"],
            snapshot_errors=inp["snapshotErrors"],
        )
        cases.append({
            "input": inp,
            "low": r.low,
            "point": r.point,
            "high": r.high,
            "everydayLow": r.everyday_low,
            "everydayHigh": r.everyday_high,
            "monthsUsed": r.months_used,
        })

    snaps = []
    for j in range(4):
        pts = [
            {
                "periodStart": 20260100 + 100 * rng.randint(1, 9) + 1 if j else 20250101,
                "dayInPeriod": rng.randint(1, 31),
                "point": rng.choice((0, rng.randrange(100_000, 3_000_000))),
                "actual": rng.randrange(100_000, 3_000_000),
            }
            for _ in range(rng.randint(0, 25))
        ]
        day = rng.randint(1, 31)
        out = fr.snapshot_errors([fr.SnapshotPoint(p["periodStart"], p["dayInPeriod"], p["point"], p["actual"]) for p in pts], day)
        snaps.append({"snapshots": pts, "dayInPeriod": day, "errors": out})

    x = fr.xorshift_seed(1)
    first = []
    for _ in range(5):
        x = fr.xorshift_next(x)
        first.append(x)
    return {
        "synthetic": True,
        "note": "SYNTHETIC inputs; outputs from ml/forecast/range.py. Regenerate with python -m forecast.export.",
        "xorshiftDay1First5": first,
        "cases": cases,
        "snapshotCases": snaps,
    }


def main() -> None:
    PARAMS.parent.mkdir(parents=True, exist_ok=True)
    VECTORS.parent.mkdir(parents=True, exist_ok=True)
    PARAMS.write_text(json.dumps(params(), indent=2) + "\n", encoding="utf-8", newline="\n")
    VECTORS.write_text(json.dumps(vectors(), indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {PARAMS.relative_to(ROOT)} and {VECTORS.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
