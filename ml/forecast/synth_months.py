"""SYNTHETIC calendar months for the forecast backtest.

Built on ml/common/synth.py (whose outputs are not changed): its everyday spending and regular
payments, laid on a calendar from 1 January 2025, plus three effects the forecast rule does NOT
assume, so the backtest is not flattering:

* a weekday pattern: Monday to Thursday lighter, Friday heavier, the weekend much heavier;
* payday bursts: extra shopping and family transfers on the 1st to 3rd of each month;
* heavy-tailed one-offs: Pareto-sized payments (tail index 1.2) on a few random days.

Every row is synthetic (synthetic = 1). Nothing here describes a real person.
"""

from __future__ import annotations

import random
from datetime import date, timedelta

from common import synth

START = date(2025, 1, 1)
# Weekday factors, Monday first. Saturday is set per person.
_WEEKDAY = (0.85, 0.85, 0.85, 0.9, 1.15)


def day_date(day: int) -> date:
    return START + timedelta(days=day)


def months_covering(days: int) -> list[tuple[int, int]]:
    """(first day index, length) for every whole calendar month inside [0, days)."""
    out = []
    d = 0
    while True:
        first = day_date(d)
        nxt = date(first.year + (first.month == 12), first.month % 12 + 1, 1)
        length = (nxt - first).days
        if d + length > days:
            return out
        out.append((d, length))
        d += length


def person(seed: int, months: int = 17) -> list[dict]:
    """About [months] calendar months of one synthetic person's money out, sorted by day."""
    days = (date(START.year + (months // 12), months % 12 + 1, 1) - START).days
    rng = random.Random(seed * 7919 + 101)
    saturday = rng.uniform(1.3, 1.9)
    sunday = (saturday + 1) / 2
    payday_rows = rng.randint(1, 4)
    oneoff_rate = rng.uniform(0.015, 0.05)

    rows = []
    for r in synth.generate_everyday(seed, days):
        wd = day_date(r["day"]).weekday()
        factor = _WEEKDAY[wd] if wd < 5 else (saturday if wd == 5 else sunday)
        rows.append({**r, "amount": max(500, int(round(r["amount"] * factor / 100.0)) * 100)})

    burst = [t for t in synth.EVERYDAY if t.template_id in ("food_shop", "family_gift", "other_misc")]
    for day in range(days):
        dom = day_date(day).day
        if dom <= 3:
            for _ in range(rng.randint(0, payday_rows)):
                t = rng.choice(burst)
                rows.append(_row(day, synth._amount(rng, t), t.category, f"payday_{t.template_id}"))
        if rng.random() < oneoff_rate:
            amount = min(5_000_000, int(30000 * rng.paretovariate(1.2)) // 1000 * 1000)
            cat = rng.choice((synth.OTHER, synth.HEALTH, synth.FAMILY))
            rows.append(_row(day, amount, cat, "oneoff_heavy"))

    rows += synth.generate_regular(seed, days)
    rows.sort(key=lambda r: (r["day"], r["hour"] if "hour" in r else 0, r["description"]))
    for i, r in enumerate(rows):
        r["idx"] = i
    return rows


def _row(day: int, amount: int, category: str, template: str) -> dict:
    return {
        "description": template,
        "amount": amount,
        "category_id": category,
        "hour": 12,
        "day": day,
        "template": template,
        "series_id": "",
        "is_regular": 0,
        "is_anomaly": 0,
        "synthetic": 1,
    }
