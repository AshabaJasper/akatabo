"""Tests of the forecast range reference (ml/forecast/range.py). All inputs are SYNTHETIC."""

import json

import pytest

from forecast import backtest, export, rule, synth_months
from forecast import range as fr


def test_xorshift_first_outputs_are_fixed():
    # Written out so a change to the seed or the shifts cannot pass unnoticed.
    x = fr.xorshift_seed(1)
    out = []
    for _ in range(5):
        x = fr.xorshift_next(x)
        out.append(x)
    assert fr.SEED == 0x9E3779B9
    assert out == [1359504952, 3827716927, 3866437631, 332804602, 1758100174]


def test_xorshift_stays_32_bit_and_seed_never_zero():
    x = fr.xorshift_seed(31)
    for _ in range(10_000):
        x = fr.xorshift_next(x)
        assert 0 < x <= 0xFFFFFFFF
    for dom in range(1, 32):
        assert fr.xorshift_seed(dom) != 0


def test_percentile_interpolates_linearly():
    s = [10, 20, 30, 40, 50]
    assert fr.percentile(s, 0.0) == 10
    assert fr.percentile(s, 1.0) == 50
    assert fr.percentile(s, 0.5) == 30
    assert fr.percentile(s, 0.1) == pytest.approx(14.0)
    assert fr.percentile(s, 0.9) == pytest.approx(46.0)
    assert fr.percentile([7], 0.9) == 7
    assert fr.percentile([], 0.5) == 0.0


def test_round_half_up():
    assert fr.round_half_up(2.5) == 3
    assert fr.round_half_up(2.4999) == 2
    assert fr.round_half_up(-2.5) == -2
    assert fr.round_half_up(0.0) == 0


def _inputs(**kw):
    base = dict(
        spent_so_far=400_000,
        daily=[0, 12_000, 8_000, 30_000, 5_000, 0, 15_000, 22_000, 9_000, 11_000],
        spent_today=0,
        days_left=12,
        regular=[fr.RegularBand(590_000, 600_000, 610_000)],
        day_of_month=18,
    )
    base.update(kw)
    return base


def test_point_is_the_phase3_rule():
    r = fr.forecast_range(**_inputs())
    mean = sum(_inputs()["daily"]) / 10
    assert r.point == 400_000 + round(mean + mean * 12) + 600_000


def test_range_contains_point_and_is_deterministic():
    a = fr.forecast_range(**_inputs())
    b = fr.forecast_range(**_inputs())
    assert a == b
    assert a.low <= a.point <= a.high
    assert a.low >= 400_000
    assert a.low < a.high


def test_regular_bands_widen_the_range():
    plain = fr.forecast_range(**_inputs(regular=[]))
    banded = fr.forecast_range(**_inputs(regular=[fr.RegularBand(500_000, 600_000, 700_000)]))
    assert banded.high - banded.low == pytest.approx(plain.high - plain.low + 200_000, abs=1)


def test_no_history_gives_a_range_of_regular_bands_only():
    r = fr.forecast_range(**_inputs(daily=[], regular=[fr.RegularBand(90, 100, 120)]))
    assert (r.low, r.point, r.high) == (400_090, 400_100, 400_120)


def test_no_snapshot_months_means_no_adjustment():
    r = fr.forecast_range(**_inputs(snapshot_errors=[]))
    assert r.months_used == 0


def test_snapshot_errors_beyond_the_range_widen_it_and_never_narrow():
    plain = fr.forecast_range(**_inputs())
    wide = fr.forecast_range(**_inputs(snapshot_errors=[0.5, 0.4, -0.5]))
    assert wide.months_used == 3
    assert wide.low < plain.low
    assert wide.high > plain.high
    tiny = fr.forecast_range(**_inputs(snapshot_errors=[0.0, 0.0, 0.0, 0.0]))
    assert (tiny.low, tiny.high) == (plain.low, plain.high)


def test_snapshot_weight_shrinks_with_few_months():
    one = fr.forecast_range(**_inputs(snapshot_errors=[0.5]))
    six = fr.forecast_range(**_inputs(snapshot_errors=[0.5] * 6))
    assert one.high < six.high


def test_only_twelve_newest_months_count():
    errors = [0.0] * 12 + [5.0]
    r = fr.forecast_range(**_inputs(snapshot_errors=errors))
    assert r.months_used == 12
    plain = fr.forecast_range(**_inputs())
    assert r.high == plain.high


def test_snapshot_errors_pick_nearest_day_per_month_newest_first():
    snaps = [
        fr.SnapshotPoint(20260901, 10, 1_000_000, 1_200_000),
        fr.SnapshotPoint(20260901, 14, 1_100_000, 1_200_000),
        fr.SnapshotPoint(20261001, 3, 900_000, 990_000),
        fr.SnapshotPoint(20261001, 25, 1_000_000, 990_000),
        fr.SnapshotPoint(20260801, 12, 0, 500_000),  # a point of 0 is skipped
    ]
    errors = fr.snapshot_errors(snaps, 12)
    # October first (nearest to day 12 is day 3, 9 away, against 13), then September day 10
    # (tie at 2 away goes to the earlier day).
    assert errors == [pytest.approx(0.1), pytest.approx(0.2)]


def test_fast_bootstrap_matches_the_reference():
    daily = [0, 1500, 9000, 25000, 4000, 0, 7000]
    for days_left in (0, 1, 13, 30):
        for dom in (1, 17, 31):
            for spent_today in (0, 6000):
                assert backtest.bootstrap_totals_fast(daily, spent_today, days_left, dom) == fr.bootstrap_totals(
                    daily, spent_today, days_left, dom
                )


def test_rule_drops_one_offs_and_regular_from_the_rate():
    rows = [
        {"idx": i, "day": i, "amount": 10_000, "category_id": "cat.food", "is_regular": 0}
        for i in range(10)
    ]
    rows.append({"idx": 10, "day": 5, "amount": 900_000, "category_id": "cat.food", "is_regular": 0})
    rows.append({"idx": 11, "day": 6, "amount": 600_000, "category_id": "cat.bills", "is_regular": 1})
    daily = rule.everyday_daily(rows, 10)
    assert len(daily) == 11
    assert daily == [10_000] * 10 + [0]


def test_synthetic_months_are_labelled_and_reproducible():
    a = synth_months.person(3, months=5)
    b = synth_months.person(3, months=5)
    assert a == b
    assert all(r["synthetic"] == 1 for r in a)
    assert len(synth_months.months_covering(151)) == 5


def test_exported_vectors_match_the_reference(tmp_path):
    v = export.vectors()
    assert v["synthetic"] is True
    assert len(v["cases"]) == 20
    on_disk = json.loads(export.VECTORS.read_text(encoding="utf-8"))
    assert on_disk == json.loads(json.dumps(v)), "re-run python -m forecast.export"
    params = json.loads(export.PARAMS.read_text(encoding="utf-8"))
    assert params == json.loads(json.dumps(export.params()))


def test_backtest_runs_on_a_small_synthetic_sample():
    res = backtest.run(persons=(1,), months=6)
    assert res["synthetic"] is True
    assert res["months"] == 3
    a = res["all"]
    assert a["forecasts"] > 0
    assert 0 <= a["coverage_bootstrap"] <= 1
    assert a["mape_point"] < a["mape_last_month"] + 1
