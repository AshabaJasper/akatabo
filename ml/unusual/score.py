"""Unusual payment score: the Python reference for app/lib/smart/unusual/.

A transparent sum of three signals, each of which can be said in plain words:

  amount  how far the amount sits above the person's usual amount, as a robust z score
          on log amounts: (ln x - median) / (1.4826 * max(MAD, mad_floor)), upward only.
          The usual amount is this payee's own history when there are at least
          min_payee_history earlier payments to it, otherwise the category's history.
          (So monthly rent is compared with earlier rent, not with airtime.)
  hour    hour_weight when fewer than hour_share_min of the person's earlier entries
          were made at this hour of the day, else 0.
  payee   payee_weight when no earlier payee key is equal to this one or one edit away
          (optimal string alignment distance <= 1, so a swapped-letter typo is not new).

score = amount + hour + payee. An entry is flagged when the category has at least
min_category_history earlier entries and score >= the threshold for the person's setting
(rarely, balanced, often).

Nothing here is learned from real data. Thresholds are tuned on SYNTHETIC seeds (tune.py).
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

from regular.payee import median

SETTINGS = ("rarely", "balanced", "often")


@dataclass(frozen=True)
class Entry:
    amount: int
    category_id: str
    hour: int
    payee_key: str
    day: int


@dataclass(frozen=True)
class Params:
    min_category_history: int = 20
    min_payee_history: int = 4
    mad_scale: float = 1.4826
    mad_floor: float = 0.1
    amount_reason_z: float = 2.0
    hour_share_min: float = 0.01
    hour_weight: float = 3.0
    payee_weight: float = 3.0
    thresholds: dict = field(
        default_factory=lambda: {"rarely": 8.0, "balanced": 5.0, "often": 3.5}
    )

    def to_json(self) -> dict:
        return {
            "minCategoryHistory": self.min_category_history,
            "minPayeeHistory": self.min_payee_history,
            "madScale": self.mad_scale,
            "madFloor": self.mad_floor,
            "amountReasonZ": self.amount_reason_z,
            "hourShareMin": self.hour_share_min,
            "hourWeight": self.hour_weight,
            "payeeWeight": self.payee_weight,
            "thresholds": {s: self.thresholds[s] for s in SETTINGS},
        }


@dataclass(frozen=True)
class Signals:
    """The parts of the score before weights and threshold are applied."""

    gate_passed: bool
    amount_z: float  # upward robust z, 0 when there is nothing to compare with
    usual_amount: float  # exp(median log amount) of the baseline, 0 when none
    basis: str  # "payee", "category" or "none"
    hour_share: float  # share of earlier entries at this hour, 1.0 when no history
    new_payee: bool


@dataclass(frozen=True)
class Result:
    score: float
    flagged: bool
    reasons: tuple[str, ...]
    signals: Signals


def osa_distance(a: str, b: str) -> int:
    """Optimal string alignment distance: insertions, deletions, substitutions and
    swaps of two neighbouring characters each cost 1."""
    n, m = len(a), len(b)
    prev2 = [0] * (m + 1)
    prev = list(range(m + 1))
    for i in range(1, n + 1):
        cur = [i] + [0] * m
        for j in range(1, m + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            best = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
                best = min(best, prev2[j - 2] + 1)
            cur[j] = best
        prev2, prev = prev, cur
    return prev[m]


def is_new_payee(key: str, earlier_keys: set[str]) -> bool:
    if key == "" or key in earlier_keys:
        return False
    for k in earlier_keys:
        if k != "" and abs(len(k) - len(key)) <= 1 and osa_distance(key, k) <= 1:
            return False
    return True


def signals(entry: Entry, history: list[Entry], p: Params) -> Signals:
    category = [h for h in history if h.category_id == entry.category_id]
    gate = len(category) >= p.min_category_history

    same_payee = (
        [h for h in history if h.payee_key == entry.payee_key] if entry.payee_key != "" else []
    )
    if len(same_payee) >= p.min_payee_history:
        baseline, basis = same_payee, "payee"
    else:
        baseline, basis = category, "category"
    logs = [math.log(h.amount) for h in baseline if h.amount > 0]
    if entry.amount <= 0 or not logs:
        amount_z, usual, basis = 0.0, 0.0, "none"
    else:
        centre = median(logs)
        mad = median([abs(v - centre) for v in logs])
        scale = p.mad_scale * max(mad, p.mad_floor)
        amount_z = max(0.0, (math.log(entry.amount) - centre) / scale)
        usual = math.exp(centre)

    if history:
        at_hour = 0
        for h in history:
            if h.hour == entry.hour:
                at_hour += 1
        hour_share = at_hour / len(history)
    else:
        hour_share = 1.0

    new_payee = is_new_payee(entry.payee_key, {h.payee_key for h in history})
    return Signals(gate, amount_z, usual, basis, hour_share, new_payee)


def combine(s: Signals, p: Params, setting: str) -> Result:
    hour = p.hour_weight if s.hour_share < p.hour_share_min else 0.0
    payee = p.payee_weight if s.new_payee else 0.0
    score = s.amount_z + hour + payee
    reasons = tuple(
        name
        for name, on in (
            ("amount", s.amount_z >= p.amount_reason_z),
            ("hour", hour > 0),
            ("payee", payee > 0),
        )
        if on
    )
    flagged = s.gate_passed and score >= p.thresholds[setting]
    return Result(score, flagged, reasons, s)


def score(entry: Entry, history: list[Entry], p: Params, setting: str = "balanced") -> Result:
    """Scores [entry] against the [history] of earlier entries."""
    return combine(signals(entry, history, p), p, setting)
