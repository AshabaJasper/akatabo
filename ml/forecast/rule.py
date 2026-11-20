"""Python port of the inputs the phone's forecast rule builds (app/lib/domain/forecast.dart).

Used by the backtest only. It mirrors the Dart rule: one-offs are money out above
Q3 + 3 * max(IQR, Q3 / 4) for their category (pooled line for a category with fewer than 4
entries; nothing with fewer than 4 in all); regular payments are left out of the daily rate;
the history is the last 90 days, never shorter than 7, ending today.
"""

from __future__ import annotations

from collections import defaultdict
from typing import Iterable

FORECAST_MIN_DAYS = 7
RATE_WINDOW_DAYS = 90
ONE_OFF_MIN_SAMPLE = 4


def _quantile(sorted_values: list[int], p: float) -> float:
    h = (len(sorted_values) - 1) * p
    lo = int(h // 1)
    hi = -int(-h // 1)
    return sorted_values[lo] + (sorted_values[hi] - sorted_values[lo]) * (h - lo)


def _one_off_line(amounts: list[int]) -> float | None:
    if len(amounts) < ONE_OFF_MIN_SAMPLE:
        return None
    s = sorted(amounts)
    q1 = _quantile(s, 0.25)
    q3 = _quantile(s, 0.75)
    return q3 + 3 * max(q3 - q1, q3 / 4)


def one_off_ids(rows: Iterable[dict]) -> set[int]:
    """Indices (the row's "idx") of one-off entries among money-out rows."""
    rows = list(rows)
    pooled = _one_off_line([r["amount"] for r in rows])
    by_cat: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        by_cat[r["category_id"]].append(r)
    ids: set[int] = set()
    for lst in by_cat.values():
        line = _one_off_line([r["amount"] for r in lst]) if len(lst) >= ONE_OFF_MIN_SAMPLE else pooled
        if line is None:
            continue
        for r in lst:
            if r["amount"] > line:
                ids.add(r["idx"])
    return ids


def everyday_daily(rows: list[dict], today: int) -> list[int]:
    """The everyday amount per history day, oldest first. [rows] are entries in the 90-day
    window ending [today] (day indices), seen so far; regular rows carry is_regular = 1."""
    if not rows:
        return []
    oneoffs = one_off_ids(rows)
    first = min(r["day"] for r in rows)
    since = today - first + 1
    history = max(FORECAST_MIN_DAYS, min(RATE_WINDOW_DAYS, since))
    by_day: dict[int, int] = defaultdict(int)
    for r in rows:
        if r["is_regular"] or r["idx"] in oneoffs:
            continue
        by_day[r["day"]] += r["amount"]
    return [by_day.get(today - i, 0) for i in range(history - 1, -1, -1)]
