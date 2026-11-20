"""Backtest of the month-end forecast and its 80% range on SYNTHETIC months.

For every synthetic person and every evaluated calendar month, a forecast is made on the
morning of each day from the 8th onward (entries up to yesterday are known), exactly as the
phone would, and compared with what the month really ended at.

Reported (all SYNTHETIC):
* MAPE of the point forecast, of the run-rate baseline (spent so far / days gone * days in
  month) and of the last-month baseline (last month's total);
* coverage of the 80% range: the share of forecasts whose real total falls inside it, for
  the bootstrap alone, the bootstrap with the snapshot adjustment, and the Phase 3 range
  (one standard deviation scaled by the square root of the days left) for comparison.

Run from ml/:  python -m forecast.backtest
"""

from __future__ import annotations

import json
import math
from collections import defaultdict
from pathlib import Path

import numpy as np

from common import synth
from forecast import range as fr
from forecast import rule, synth_months

PERSONS = tuple(range(1, 17))
MONTHS = 17
FIRST_EVALUATED = 3  # month index; three months of history before the first one
FIRST_DAY = 8
_INTERVAL = {s.series_id: s.every_days for s in synth.REGULAR}
_AMOUNT = {s.series_id: s.amount for s in synth.REGULAR}
_MAX_DRAWS = fr.SAMPLES * 32


def _streams() -> dict[int, np.ndarray]:
    """The PRNG states for each day of the month, long enough for any month."""
    out = {}
    for dom in range(1, 32):
        x = fr.xorshift_seed(dom)
        arr = np.empty(_MAX_DRAWS, dtype=np.int64)
        for i in range(_MAX_DRAWS):
            x = fr.xorshift_next(x)
            arr[i] = x
        out[dom] = arr
    return out


_STREAMS: dict[int, np.ndarray] | None = None


def bootstrap_totals_fast(daily: list[int], spent_today: int, days_left: int, day_of_month: int) -> list[int]:
    """The same totals as range.bootstrap_totals, vectorised with the same draw order."""
    global _STREAMS
    if not daily:
        return []
    if _STREAMS is None:
        _STREAMS = _streams()
    n = len(daily)
    width = days_left + 1
    idx = (_STREAMS[day_of_month][: fr.SAMPLES * width] % n).reshape(fr.SAMPLES, width)
    vals = np.asarray(daily, dtype=np.int64)[idx]
    first = np.maximum(0, vals[:, 0] - spent_today)
    return (first + vals[:, 1:].sum(axis=1)).tolist()


def _regular_due(rows: list[dict], today: int, month_end: int) -> list[fr.RegularBand]:
    last: dict[str, int] = {}
    for r in rows:
        if r["is_regular"] and r["day"] < today:
            last[r["series_id"]] = max(last.get(r["series_id"], -1), r["day"])
    bands = []
    for sid, day in last.items():
        step = _INTERVAL[sid]
        nxt = day + step
        while nxt < today:
            nxt += step
        while nxt <= month_end:
            a = _AMOUNT[sid]
            bands.append(fr.RegularBand(a - 200, a, a + 200))
            nxt += step
    return bands


def _phase3_range(daily, spent, days_left, bands, point):
    n = len(daily)
    mean = fr.everyday_mean(daily)
    sd = math.sqrt(sum((x - mean) ** 2 for x in daily) / n) if n else 0.0
    to_come = mean + mean * days_left
    spread = sd * math.sqrt(days_left + 1)
    low = min(point, spent + fr.round_half_up(max(0.0, to_come - spread)) + sum(b.low for b in bands))
    high = max(point, spent + fr.round_half_up(to_come + spread) + sum(b.high for b in bands))
    return low, high


def band_of(dom: int) -> str:
    return "days 8-14" if dom <= 14 else ("days 15-21" if dom <= 21 else "days 22-end")


def run(persons=PERSONS, months=MONTHS) -> dict:
    records = []
    month_count = 0
    for seed in persons:
        rows = synth_months.person(seed, months)
        by_day: dict[int, list[dict]] = defaultdict(list)
        for r in rows:
            by_day[r["day"]].append(r)
        spans = synth_months.months_covering(max(r["day"] for r in rows) + 1)
        totals = [sum(r["amount"] for d in range(a, a + n) for r in by_day[d]) for a, n in spans]
        snapshots: list[fr.SnapshotPoint] = []
        for mi in range(FIRST_EVALUATED, len(spans)):
            first, length = spans[mi]
            month_end = first + length - 1
            actual = totals[mi]
            period_start = int(synth_months.day_date(first).strftime("%Y%m%d"))
            month_count += 1
            this_month: list[fr.SnapshotPoint] = []  # known only once the month has ended
            for dom in range(FIRST_DAY, length + 1):
                today = first + dom - 1
                days_with = sum(1 for d in range(first, today) if by_day[d])
                if days_with < rule.FORECAST_MIN_DAYS:
                    continue
                spent = sum(r["amount"] for d in range(first, today) for r in by_day[d])
                window = [r for d in range(today - rule.RATE_WINDOW_DAYS + 1, today) for r in by_day[d]]
                daily = rule.everyday_daily(window, today)
                bands = _regular_due(rows, today, month_end)
                days_left = month_end - today
                sims = bootstrap_totals_fast(daily, 0, days_left, dom)
                errors = fr.snapshot_errors(snapshots, dom)
                common = dict(spent_so_far=spent, daily=daily, spent_today=0, days_left=days_left,
                              regular=bands, day_of_month=dom, totals=sims)
                plain = fr.forecast_range(**common)
                adjusted = fr.forecast_range(**common, snapshot_errors=errors)
                p3_low, p3_high = _phase3_range(daily, spent, days_left, bands, plain.point)
                run_rate = spent / (dom - 1) * length
                records.append({
                    "seed": seed, "month": mi, "dom": dom, "actual": actual,
                    "point": plain.point, "run_rate": run_rate, "last_month": totals[mi - 1],
                    "boot": (plain.low, plain.high), "adj": (adjusted.low, adjusted.high),
                    "adj_used": adjusted.months_used, "p3": (p3_low, p3_high),
                })
                this_month.append(fr.SnapshotPoint(period_start, dom, plain.point, actual))
            snapshots += this_month
    return summarise(records, month_count)


def _ape(pred: float, actual: int) -> float:
    return abs(pred - actual) / actual


def summarise(records: list[dict], month_count: int) -> dict:
    def block(rs):
        if not rs:
            return {}
        n = len(rs)
        inside = lambda key: sum(1 for r in rs if r[key][0] <= r["actual"] <= r[key][1]) / n
        width = lambda key: sum((r[key][1] - r[key][0]) / r["actual"] for r in rs) / n
        with_snap = [r for r in rs if r["adj_used"] > 0]
        return {
            "forecasts": n,
            "mape_point": sum(_ape(r["point"], r["actual"]) for r in rs) / n,
            "mape_run_rate": sum(_ape(r["run_rate"], r["actual"]) for r in rs) / n,
            "mape_last_month": sum(_ape(r["last_month"], r["actual"]) for r in rs) / n,
            "coverage_bootstrap": inside("boot"),
            "coverage_bootstrap_snapshots": inside("adj"),
            "coverage_phase3": inside("p3"),
            "width_bootstrap": width("boot"),
            "width_bootstrap_snapshots": width("adj"),
            "width_phase3": width("p3"),
            "forecasts_with_snapshots": len(with_snap),
            "coverage_with_snapshots_only_bootstrap": (
                sum(1 for r in with_snap if r["boot"][0] <= r["actual"] <= r["boot"][1]) / len(with_snap)
                if with_snap else None),
            "coverage_with_snapshots_only_adjusted": (
                sum(1 for r in with_snap if r["adj"][0] <= r["actual"] <= r["adj"][1]) / len(with_snap)
                if with_snap else None),
        }

    bands = defaultdict(list)
    for r in records:
        bands[band_of(r["dom"])].append(r)
    return {
        "synthetic": True,
        "persons": len({r["seed"] for r in records}),
        "months": month_count,
        "all": block(records),
        "by_day": {k: block(bands[k]) for k in ("days 8-14", "days 15-21", "days 22-end")},
    }


def _fmt(v):
    return "n/a" if v is None else f"{100 * v:.1f}%"


def table(result: dict) -> str:
    lines = [
        "| SYNTHETIC | forecasts | MAPE point | MAPE run-rate | MAPE last month | "
        "coverage bootstrap | coverage bootstrap + snapshots | coverage Phase 3 range | "
        "width bootstrap | width + snapshots | width Phase 3 |",
        "|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for name, b in [("all days", result["all"]), *result["by_day"].items()]:
        lines.append(
            f"| {name} | {b['forecasts']} | {_fmt(b['mape_point'])} | {_fmt(b['mape_run_rate'])} | "
            f"{_fmt(b['mape_last_month'])} | {_fmt(b['coverage_bootstrap'])} | "
            f"{_fmt(b['coverage_bootstrap_snapshots'])} | {_fmt(b['coverage_phase3'])} | "
            f"{_fmt(b['width_bootstrap'])} | {_fmt(b['width_bootstrap_snapshots'])} | {_fmt(b['width_phase3'])} |"
        )
    return "\n".join(lines)


if __name__ == "__main__":
    res = run()
    out = Path(__file__).resolve().parent / "backtest_results.json"
    out.write_text(json.dumps(res, indent=2) + "\n", encoding="utf-8")
    print(f"SYNTHETIC: {res['persons']} persons, {res['months']} months")
    print(table(res))
    a = res["all"]
    print(
        f"forecasts with snapshot months: {a['forecasts_with_snapshots']}; on those, coverage "
        f"bootstrap {_fmt(a['coverage_with_snapshots_only_bootstrap'])}, adjusted "
        f"{_fmt(a['coverage_with_snapshots_only_adjusted'])}"
    )
