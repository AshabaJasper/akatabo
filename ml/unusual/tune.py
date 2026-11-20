"""Chooses the weights and the three thresholds on SYNTHETIC tuning seeds 101-110.

The held-out test seed (7) is never read here.

Method: each setting has a budget of false flags per 100 normal entries
(rarely 0.5, balanced 1.5, often 4). For every combination of hour weight, payee weight
and hour-share cut-off, each setting takes the threshold with the highest recall whose
pooled false-flag rate stays within its budget (ties: higher precision, then the higher
threshold). The combination with the best balanced recall wins (ties: higher summed
recall over the three settings, then higher balanced precision).

Writes ml/unusual/tuned.json. Run from ml/: python -m unusual.tune
"""

from __future__ import annotations

import bisect
import itertools
import json
from dataclasses import replace
from pathlib import Path

from unusual.data import TUNING_SEEDS, scored_seed
from unusual.metrics import Counts
from unusual.score import SETTINGS, Params, combine

BUDGETS = {"rarely": 0.5, "balanced": 1.5, "often": 4.0}
WEIGHTS = tuple(float(w) for w in range(1, 11))  # 1 .. 10
HOUR_SHARES = (0.005, 0.01, 0.02)
THRESHOLDS = tuple(1.0 + 0.25 * i for i in range(57))  # 1.0 .. 15.0

OUT = Path(__file__).resolve().parent / "tuned.json"


def best_threshold(signal_sets, labels_sets, p: Params, setting: str):
    # The score does not depend on the threshold, so it is computed once per combination
    # and each threshold is a count over sorted scores. Same result as count() on flags.
    pos, neg = [], []
    n_pos = n_neg = 0
    for sigs, labels in zip(signal_sets, labels_sets):
        for s, y in zip(sigs, labels):
            if y:
                n_pos += 1
            else:
                n_neg += 1
            if s.gate_passed:
                (pos if y else neg).append(combine(s, p, setting).score)
    pos.sort()
    neg.sort()
    best = None
    for thr in THRESHOLDS:
        tp = len(pos) - bisect.bisect_left(pos, thr)
        fp = len(neg) - bisect.bisect_left(neg, thr)
        c = Counts(tp, fp, n_pos - tp, n_neg)
        if c.flags_per_100_normal > BUDGETS[setting]:
            continue
        key = (c.recall, c.precision, thr)
        if best is None or key > best[0]:
            best = (key, thr, c)
    return best


def tune() -> dict:
    base = Params()
    data = [scored_seed(s, base) for s in TUNING_SEEDS]
    signal_sets = [d[0] for d in data]
    labels_sets = [d[1] for d in data]

    winner = None
    for hw, pw, hs in itertools.product(WEIGHTS, WEIGHTS, HOUR_SHARES):
        p = replace(base, hour_weight=hw, payee_weight=pw, hour_share_min=hs)
        picks = {s: best_threshold(signal_sets, labels_sets, p, s) for s in SETTINGS}
        if any(v is None for v in picks.values()):
            continue
        bal = picks["balanced"][2]
        key = (bal.recall, sum(picks[s][2].recall for s in SETTINGS), bal.precision)
        if winner is None or key > winner[0]:
            winner = (key, p, picks)

    _, p, picks = winner
    p = replace(p, thresholds={s: picks[s][1] for s in SETTINGS})
    report = {
        "synthetic": True,
        "tuning_seeds": list(TUNING_SEEDS),
        "budgets_false_flags_per_100_normal": BUDGETS,
        "params": p.to_json(),
        "tuning_metrics": {
            s: {
                "precision": picks[s][2].precision,
                "recall": picks[s][2].recall,
                "flags_per_100_normal": picks[s][2].flags_per_100_normal,
                "tp": picks[s][2].tp,
                "fp": picks[s][2].fp,
                "fn": picks[s][2].fn,
            }
            for s in SETTINGS
        },
    }
    OUT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


if __name__ == "__main__":
    print(json.dumps(tune(), indent=2))
