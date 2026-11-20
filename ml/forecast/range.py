"""The month-end forecast RANGE: the reference algorithm the phone runs.

The Dart port is app/lib/smart/forecast/forecast_range.dart. A parity test feeds both the
same vectors (app/test/smart/fixtures/forecast_vectors.json, written by export.py) and
requires the same low, point and high. Change one, change the other.

The point forecast is the Phase 3 rule (app/lib/domain/forecast.dart) and is not changed here:

    point = spent so far
          + round(max(0, mean - spent today) + mean * days left)      everyday still to come
          + the typical amount of every regular payment still due

where mean is the average of the person's everyday daily amounts (one-offs and regular
payments taken out) over the history window.

THE RANGE
1. Bootstrap. For each of SAMPLES simulated months, draw one history day for the rest of today
   (counting only what is above what was already spent today, never below zero) and one history
   day for each day left, with replacement, and add them up. The draws come from a fixed PRNG
   (below), so the phone and Python give the same numbers for the same inputs.
2. Cut-offs. The 10th and 90th percentiles of the simulated totals (an 80% range), by linear
   interpolation on the sorted totals: h = (n - 1) * p, value = s[floor h] + (s[ceil h] -
   s[floor h]) * (h - floor h).
3. Regular payments. low adds every due payment's low amount, high adds its high amount.
   low = spent + round_half_up(p10) + regular low; high = spent + round_half_up(p90) + regular high.
4. Snapshot adjustment (the person's own track record). Each earlier month with a saved
   snapshot gives one error, e = (actual - snapshot point) / snapshot point, from the snapshot
   taken nearest the same day of the month. With k such months (newest MAX_MONTHS only) and
   weight w = k / (k + SHRINK_MONTHS):
       lo_rel = (low - point) / point,  hi_rel = (high - point) / point
       lo_rel' = lo_rel + w * min(0, p10(errors) - lo_rel)
       hi_rel' = hi_rel + w * max(0, p90(errors) - hi_rel)
       low = round_half_up(point * (1 + lo_rel')), high = round_half_up(point * (1 + hi_rel'))
   The adjustment only widens: an edge moves out, part of the way, when the person's own past
   errors went beyond it, and never moves in (a few months cannot show the range is too wide).
   No snapshot months, or a point of 0: no adjustment.
5. Clamp. low is at least the money already spent and at most the point; high is at least the
   point. The range always contains the point.

THE PRNG: 32-bit xorshift (Marsaglia 2003, shifts 13, 17, 5).
    state = (SEED XOR day_of_month) AND 0xFFFFFFFF; if state == 0 then state = SEED
    next:  x ^= (x << 13) & 0xFFFFFFFF;  x ^= x >> 17;  x ^= (x << 5) & 0xFFFFFFFF
    index = x mod n            (n = number of history days)
The draws run sample by sample: sample 0 takes the rest-of-today draw then its days-left
draws, then sample 1, and so on. Seeding by the day of the month means the same inputs on the
same day always give the same range.

ROUNDING: round_half_up(x) = floor(x + 0.5), written the same way in both languages.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Sequence

SEED = 0x9E3779B9
SAMPLES = 500
P_LOW = 0.1
P_HIGH = 0.9
SHRINK_MONTHS = 3
MAX_MONTHS = 12
MASK32 = 0xFFFFFFFF


def xorshift_seed(day_of_month: int) -> int:
    state = (SEED ^ day_of_month) & MASK32
    return state if state != 0 else SEED


def xorshift_next(x: int) -> int:
    x ^= (x << 13) & MASK32
    x ^= x >> 17
    x ^= (x << 5) & MASK32
    return x


def round_half_up(x: float) -> int:
    return math.floor(x + 0.5)


def percentile(sorted_values: Sequence[float], p: float) -> float:
    """Linear interpolation between the two nearest ranks of already sorted values."""
    if not sorted_values:
        return 0.0
    h = (len(sorted_values) - 1) * p
    lo = math.floor(h)
    hi = math.ceil(h)
    return sorted_values[lo] + (sorted_values[hi] - sorted_values[lo]) * (h - lo)


@dataclass(frozen=True)
class RegularBand:
    """One regular payment occurrence still due this month."""

    low: int
    typical: int
    high: int


@dataclass(frozen=True)
class Range:
    low: int
    point: int
    high: int
    everyday_low: float  # p10 of the simulated everyday totals (before rounding)
    everyday_high: float  # p90
    months_used: int  # snapshot months that adjusted the range (0 = none)


def bootstrap_totals(daily: Sequence[int], spent_today: int, days_left: int, day_of_month: int) -> list[int]:
    """SAMPLES simulated everyday totals for the rest of the month, unsorted."""
    n = len(daily)
    if n == 0:
        return []
    x = xorshift_seed(day_of_month)
    totals = []
    for _ in range(SAMPLES):
        x = xorshift_next(x)
        total = max(0, daily[x % n] - spent_today)
        for _ in range(days_left):
            x = xorshift_next(x)
            total += daily[x % n]
        totals.append(total)
    return totals


def everyday_mean(daily: Sequence[int]) -> float:
    return sum(daily) / len(daily) if daily else 0.0


def adjust_for_snapshots(low: int, point: int, high: int, errors: Sequence[float]) -> tuple[int, int, int]:
    used = list(errors[:MAX_MONTHS])
    k = len(used)
    if k == 0 or point <= 0:
        return low, high, 0
    w = k / (k + SHRINK_MONTHS)
    lo_rel = (low - point) / point
    hi_rel = (high - point) / point
    es = sorted(used)
    lo_rel2 = lo_rel + w * min(0.0, percentile(es, P_LOW) - lo_rel)
    hi_rel2 = hi_rel + w * max(0.0, percentile(es, P_HIGH) - hi_rel)
    return round_half_up(point * (1 + lo_rel2)), round_half_up(point * (1 + hi_rel2)), k


def forecast_range(
    *,
    spent_so_far: int,
    daily: Sequence[int],
    spent_today: int,
    days_left: int,
    regular: Sequence[RegularBand],
    day_of_month: int,
    snapshot_errors: Sequence[float] = (),
    totals: Sequence[int] | None = None,
) -> Range:
    """The forecast and its 80% range. [totals] lets the backtest pass a faster, identical
    bootstrap (see backtest.bootstrap_totals_fast); the phone always draws them itself."""
    mean = everyday_mean(daily)
    to_come = max(0.0, mean - spent_today) + mean * days_left
    reg_low = sum(r.low for r in regular)
    reg_typical = sum(r.typical for r in regular)
    reg_high = sum(r.high for r in regular)
    point = spent_so_far + round_half_up(to_come) + reg_typical

    sims = sorted(totals if totals is not None else bootstrap_totals(daily, spent_today, days_left, day_of_month))
    if sims:
        ev_low = percentile(sims, P_LOW)
        ev_high = percentile(sims, P_HIGH)
    else:
        ev_low = ev_high = to_come

    low = spent_so_far + round_half_up(ev_low) + reg_low
    high = spent_so_far + round_half_up(ev_high) + reg_high
    low, high, used = adjust_for_snapshots(low, point, high, snapshot_errors)

    low = min(max(low, spent_so_far), point)
    high = max(high, point)
    return Range(low, point, high, ev_low, ev_high, used)


@dataclass(frozen=True)
class SnapshotPoint:
    """A saved forecast for an earlier month, with what that month really came to."""

    period_start: int  # yyyymmdd of the month's first day
    day_in_period: int  # 1 on the month's first day
    point: int
    actual: int


def snapshot_errors(snapshots: Sequence[SnapshotPoint], day_in_period: int) -> list[float]:
    """One relative error per earlier month, newest month first, at most MAX_MONTHS.

    Each month uses its snapshot taken nearest [day_in_period] (the earlier day on a tie).
    A snapshot with a point of 0 or less says nothing about relative error and is skipped.
    """
    best: dict[int, SnapshotPoint] = {}
    for s in snapshots:
        if s.point <= 0:
            continue
        cur = best.get(s.period_start)
        key = (abs(s.day_in_period - day_in_period), s.day_in_period)
        if cur is None or key < (abs(cur.day_in_period - day_in_period), cur.day_in_period):
            best[s.period_start] = s
    months = sorted(best, reverse=True)[:MAX_MONTHS]
    return [(best[m].actual - best[m].point) / best[m].point for m in months]
