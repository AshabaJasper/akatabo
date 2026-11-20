"""Tunes the regular-payment rule on SYNTHETIC seeds 101-110 and reports on held-out seed 7.

Data: common.synth.make_dataset, which has six regular series (rent, school term, gym,
DStv, Netflix, insurance) with +-2 day jitter, +-200 shilling amount wobble and skipped
occurrences, mixed with everyday spending whose descriptions repeat at random (the
distractors). Every number here is synthetic, never real-world performance.

Series-level scoring: a detected series is a true positive when most of its payments carry
one series_id that no earlier detection has claimed. Precision = true / detected,
recall = true series found / true series.

Next-date error: at cut-off days 180, 210, ... the rule sees only payments before the
cut-off; for each detected true series, the error is predicted next day minus the day of
the series' next real payment after the last one seen.

Baselines: payee_3x (any payee key seen at least 3 times is "regular"), no_min_interval
(the full rule without the minimum-interval check), and for the next date, last day plus
the mean raw gap (which a skipped month inflates).

Run from ml/: python -m regular.evaluate      (tunes, writes tuned.json, prints the report)
"""

from __future__ import annotations

import itertools
import json
from dataclasses import replace
from pathlib import Path

from common.synth import make_dataset
from regular.detect import Params, Payment, detect
from regular.payee import median, payee_key_of, plain_sum, round_half_up

TEST_SEED = 7
TUNING_SEEDS = tuple(range(101, 111))
HERE = Path(__file__).resolve().parent

CV_GRID = (0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4)
SHARE_GRID = (0.6, 0.7, 0.8, 0.9, 1.0)


def payments_of(rows: list[dict]) -> list[Payment]:
    return [
        Payment(int(r["amount"]), r["category_id"], payee_key_of(r["description"]), int(r["day"]))
        for r in rows
    ]


def truth_by_key(rows: list[dict]) -> dict[str, str]:
    """payee key -> the series_id most of its rows carry ('' when mostly not regular)."""
    votes: dict[str, dict[str, int]] = {}
    for r in rows:
        k = payee_key_of(r["description"])
        votes.setdefault(k, {}).setdefault(r["series_id"], 0)
        votes[k][r["series_id"]] += 1
    return {k: max(sorted(v), key=lambda s: v[s]) for k, v in votes.items()}


def series_scores(rows: list[dict], detected_keys: list[str]) -> dict:
    truth = truth_by_key(rows)
    true_series = {r["series_id"] for r in rows if r["series_id"]}
    claimed: set[str] = set()
    tp = 0
    for k in detected_keys:
        sid = truth.get(k, "")
        if sid and sid not in claimed:
            claimed.add(sid)
            tp += 1
    return {
        "detected": len(detected_keys),
        "true_series": len(true_series),
        "tp": tp,
        "precision": tp / len(detected_keys) if detected_keys else 0.0,
        "recall": len(claimed) / len(true_series) if true_series else 0.0,
    }


def run_rule(rows: list[dict], p: Params) -> dict:
    today = max(int(r["day"]) for r in rows)
    keys = [s.payee_key for s in detect(payments_of(rows), today, p)]
    return series_scores(rows, keys)


def payee_3x(rows: list[dict]) -> dict:
    counts: dict[str, int] = {}
    for pay in payments_of(rows):
        if pay.payee_key:
            counts[pay.payee_key] = counts.get(pay.payee_key, 0) + 1
    return series_scores(rows, sorted(k for k, n in counts.items() if n >= 3))


def next_date_errors(rows: list[dict], p: Params) -> dict:
    truth = truth_by_key(rows)
    pays = payments_of(rows)
    end = max(pay.day for pay in pays)
    by_series: dict[str, list[int]] = {}
    for r in rows:
        if r["series_id"]:
            by_series.setdefault(r["series_id"], []).append(int(r["day"]))
    rule_err: list[int] = []
    base_err: list[int] = []
    for cut in range(180, end + 1, 30):
        seen = [x for x in pays if x.day < cut]
        for s in detect(seen, cut - 1, p):
            sid = truth.get(s.payee_key, "")
            if not sid:
                continue
            later = sorted(d for d in by_series[sid] if d > s.last_day)
            if not later:
                continue
            actual = later[0]
            rule_err.append(s.next_day - actual)
            days = sorted(x.day for x in seen if x.payee_key == s.payee_key)
            gaps = [float(days[i + 1] - days[i]) for i in range(len(days) - 1)]
            base_err.append(days[-1] + round_half_up(plain_sum(gaps) / len(gaps)) - actual)

    def summary(errs: list[int]) -> dict:
        if not errs:
            return {"n": 0}
        abs_e = [abs(e) for e in errs]
        return {
            "n": len(errs),
            "mean_abs_days": round(plain_sum([float(a) for a in abs_e]) / len(abs_e), 3),
            "median_abs_days": median([float(a) for a in abs_e]),
            "max_abs_days": max(abs_e),
            "share_within_3_days": round(sum(1 for a in abs_e if a <= 3) / len(abs_e), 3),
        }

    return {"rule": summary(rule_err), "baseline_last_plus_mean_gap": summary(base_err)}


def tune() -> Params:
    data = [make_dataset(s) for s in TUNING_SEEDS]
    scores = {}
    for cv, share in itertools.product(CV_GRID, SHARE_GRID):
        p = replace(Params(), cv_max=cv, amount_share_min=share)
        tp = det = true = 0
        for rows in data:
            r = run_rule(rows, p)
            tp, det, true = tp + r["tp"], det + r["detected"], true + r["true_series"]
        prec = tp / det if det else 0.0
        rec = tp / true if true else 0.0
        f1 = 2 * prec * rec / (prec + rec) if prec + rec else 0.0
        scores[(cv, share)] = {"precision": prec, "recall": rec, "f1": f1}
    # Many settings tie on the synthetic seeds. Take the middle of the best plateau rather
    # than its edge, so neither the strictest nor the loosest setting is chosen by accident.
    top = max(v["f1"] for v in scores.values())
    best = [k for k, v in scores.items() if v["f1"] == top]
    cvs = sorted({k[0] for k in best})
    shares = sorted({k[1] for k in best})
    pick = (cvs[len(cvs) // 2], shares[len(shares) // 2])
    if pick not in best:
        pick = best[0]
    p = replace(Params(), cv_max=pick[0], amount_share_min=pick[1])
    m = {**scores[pick], "settings_tied_at_best": len(best), "settings_tried": len(scores)}
    (HERE / "tuned.json").write_text(
        json.dumps(
            {"synthetic": True, "tuning_seeds": list(TUNING_SEEDS), "params": p.to_json(), "tuning_metrics": m},
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    return p


def load_params() -> Params:
    return Params.from_json(json.loads((HERE / "tuned.json").read_text(encoding="utf-8"))["params"])


def daily_lunch_rows(seed: int, days: int = 540) -> list[dict]:
    """A SYNTHETIC stress distractor the generator does not have: the same 5,000 shilling
    lunch bought on about 9 days in 10. Its amount band and gaps are both very regular, so only
    the minimum-interval rule keeps it from being called a bill."""
    import random

    rng = random.Random(seed + 50)
    return [
        {"description": "posho lunch", "amount": 5000, "category_id": "cat.food", "hour": 13,
         "day": d, "template": "stress_lunch", "series_id": "", "is_regular": 0,
         "is_anomaly": 0, "synthetic": 1}
        for d in range(days)
        if rng.random() < 0.9
    ]


def evaluate(seed: int = TEST_SEED) -> dict:
    p = load_params()
    rows = make_dataset(seed)
    stress = rows + daily_lunch_rows(seed)
    return {
        "stress_with_daily_lunch": {
            "rule": run_rule(stress, p),
            "without_min_interval": run_rule(stress, replace(p, min_interval_days=0.0)),
        },
        "synthetic": True,
        "seed": seed,
        "params": p.to_json(),
        "rule": run_rule(rows, p),
        "baseline_payee_3x": payee_3x(rows),
        "baseline_no_min_interval": run_rule(rows, replace(p, min_interval_days=0.0)),
        "next_date": next_date_errors(rows, p),
    }


if __name__ == "__main__":
    tune()
    print(json.dumps(evaluate(), indent=2))
