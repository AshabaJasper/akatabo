"""Regular payment detection: the Python reference for app/lib/smart/regular/.

The rule, one payee key at a time (keys from payee.payee_key_of; empty keys are skipped):

  1. at least min_occurrences payments to the key;
  2. the median gap between payments is at least min_interval_days (so lunch bought most
     days is never called a bill) and at most max_interval_days;
  3. regular gaps: each gap is divided by the number of whole intervals it spans,
     max(1, round(gap / median gap)), so one missed month counts as two gaps of a month.
     The coefficient of variation of those unit gaps must be at most cv_max, and the missed
     intervals (spans minus one, summed) may be at most max_missed_share of all intervals,
     so a few payments with long silences between them are not read as a short interval;
  4. an amount band: at least amount_share_min of the amounts lie within amount_band
     (a fraction) of the median amount;
  5. still current: the last payment is no more than stale_intervals intervals before today.

Predictions: interval = median unit gap; next day = last day + round(interval); the amount
range is the lowest and highest amount inside the band, the typical amount their median.

Integers are rounded with floor(x + 0.5) and sums are added left to right, so the Dart port
gives the same numbers. Thresholds are chosen on SYNTHETIC seeds (evaluate.py tune()).
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from regular.payee import median, plain_sum, round_half_up


@dataclass(frozen=True)
class Payment:
    amount: int
    category_id: str
    payee_key: str
    day: int


@dataclass(frozen=True)
class Params:
    min_occurrences: int = 3
    min_interval_days: float = 5.0
    max_interval_days: float = 400.0
    cv_max: float = 0.2
    amount_band: float = 0.10
    amount_share_min: float = 0.8
    stale_intervals: float = 2.5
    max_missed_share: float = 0.3

    def to_json(self) -> dict:
        return {
            "minOccurrences": self.min_occurrences,
            "minIntervalDays": self.min_interval_days,
            "maxIntervalDays": self.max_interval_days,
            "cvMax": self.cv_max,
            "amountBand": self.amount_band,
            "amountShareMin": self.amount_share_min,
            "staleIntervals": self.stale_intervals,
            "maxMissedShare": self.max_missed_share,
        }

    @staticmethod
    def from_json(raw: dict) -> "Params":
        return Params(
            min_occurrences=raw["minOccurrences"],
            min_interval_days=raw["minIntervalDays"],
            max_interval_days=raw["maxIntervalDays"],
            cv_max=raw["cvMax"],
            amount_band=raw["amountBand"],
            amount_share_min=raw["amountShareMin"],
            stale_intervals=raw["staleIntervals"],
            max_missed_share=raw["maxMissedShare"],
        )


@dataclass(frozen=True)
class Series:
    payee_key: str
    category_id: str
    occurrences: int
    interval: float
    interval_days: int
    gap_cv: float
    typical_amount: int
    amount_low: int
    amount_high: int
    last_day: int
    next_day: int
    next_due_from_today: int  # the first predicted day on or after today


def _category(group: list[Payment]) -> str:
    counts: dict[str, int] = {}
    for g in group:
        counts[g.category_id] = counts.get(g.category_id, 0) + 1
    best = max(counts.values())
    return min(c for c, n in counts.items() if n == best)


def check(group: list[Payment], today: int, p: Params) -> Series | None:
    """The series for one payee's payments, or None when the rule rejects it."""
    group = sorted(group, key=lambda g: (g.day, g.amount))
    n = len(group)
    if n < p.min_occurrences:
        return None
    days = [g.day for g in group]
    gaps = [float(days[i + 1] - days[i]) for i in range(n - 1)]
    med_gap = median(gaps)
    if med_gap < p.min_interval_days or med_gap > p.max_interval_days:
        return None
    spans = [max(1, round_half_up(g / med_gap)) for g in gaps]
    if sum(spans) - len(spans) > p.max_missed_share * sum(spans):
        return None
    units = [g / k for g, k in zip(gaps, spans)]
    mean = plain_sum(units) / len(units)
    var = plain_sum([(u - mean) * (u - mean) for u in units]) / len(units)
    cv = math.sqrt(var) / mean if mean > 0 else math.inf
    if cv > p.cv_max:
        return None

    amounts = [float(g.amount) for g in group]
    med_amount = median(amounts)
    band = [a for a in amounts if abs(a - med_amount) <= p.amount_band * med_amount]
    if len(band) < p.amount_share_min * n:
        return None

    interval = median(units)
    interval_days = max(1, round_half_up(interval))
    last = days[-1]
    if today - last > p.stale_intervals * interval:
        return None
    next_day = last + interval_days
    next_due = next_day
    if next_due < today:
        next_due += ((today - next_due + interval_days - 1) // interval_days) * interval_days
    return Series(
        payee_key=group[0].payee_key,
        category_id=_category(group),
        occurrences=n,
        interval=interval,
        interval_days=interval_days,
        gap_cv=cv,
        typical_amount=round_half_up(median(band)),
        amount_low=int(min(band)),
        amount_high=int(max(band)),
        last_day=last,
        next_day=next_day,
        next_due_from_today=next_due,
    )


def detect(payments: list[Payment], today: int, p: Params) -> list[Series]:
    """Every regular series in [payments] as of [today], sorted by payee key."""
    groups: dict[str, list[Payment]] = {}
    for pay in payments:
        if pay.payee_key != "":
            groups.setdefault(pay.payee_key, []).append(pay)
    out = []
    for key in sorted(groups):
        s = check(groups[key], today, p)
        if s is not None:
            out.append(s)
    return out
