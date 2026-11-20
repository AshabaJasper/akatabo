import json

from regular.detect import Params, Payment, detect
from regular.evaluate import TEST_SEED, TUNING_SEEDS, evaluate, load_params
from regular.export import VECTORS_OUT, export
from regular.payee import plain_sum, round_half_up


def pay(day, amount=45000, key="dstv", cat="cat.bills"):
    return Payment(amount, cat, key, day)


P = Params()


def test_round_half_up_differs_from_python_round():
    assert round(2.5) == 2
    assert round_half_up(2.5) == 3
    assert round_half_up(30.4999) == 30


def test_plain_sum_adds_left_to_right():
    assert plain_sum([0.1, 0.2, 0.3]) == (0.1 + 0.2) + 0.3


def test_monthly_series_and_next_date():
    [s] = detect([pay(d) for d in (3, 33, 62, 93, 122)], 130, P)
    assert s.interval_days == 30
    assert s.next_day == 152
    assert (s.amount_low, s.typical_amount, s.amount_high) == (45000, 45000, 45000)


def test_a_missed_month_is_tolerated():
    [s] = detect([pay(d) for d in (3, 33, 93, 122, 153)], 160, P)
    assert s.interval_days == 30


def test_two_payments_are_not_enough():
    assert detect([pay(1), pay(31)], 40, P) == []


def test_daily_lunch_is_never_a_bill():
    lunch = [pay(d, 5000, "posho lunch", "cat.food") for d in range(60)]
    assert detect(lunch, 60, P) == []
    # The minimum interval is the rule that stops it.
    loose = Params(min_interval_days=0.0)
    assert len(detect(lunch, 60, loose)) == 1


def test_amounts_outside_the_band_reject():
    pays = [pay(d, a) for d, a in zip((3, 33, 63, 93), (10000, 45000, 90000, 20000))]
    assert detect(pays, 100, P) == []


def test_stale_series_is_dropped():
    assert detect([pay(d) for d in (3, 33, 62, 93, 122)], 122 + 90, P) == []


def test_next_due_rolls_forward_past_today():
    [s] = detect([pay(d) for d in (3, 33, 62, 93, 122)], 175, P)
    assert s.next_day == 152
    assert s.next_due_from_today == 182


def test_irregular_gaps_reject():
    assert detect([pay(d) for d in (0, 9, 40, 47, 90, 101)], 110, P) == []


def test_held_out_seed_report_is_synthetic_and_tuning_excludes_it():
    assert TEST_SEED not in TUNING_SEEDS
    report = evaluate()
    assert report["synthetic"] is True
    assert report["rule"]["precision"] >= report["baseline_payee_3x"]["precision"]
    assert report["next_date"]["rule"]["n"] > 0
    stress = report["stress_with_daily_lunch"]
    assert stress["rule"]["precision"] >= stress["without_min_interval"]["precision"]


def test_exported_vectors_are_current():
    before = json.loads(VECTORS_OUT.read_text(encoding="utf-8"))
    n = export()
    after = json.loads(VECTORS_OUT.read_text(encoding="utf-8"))
    assert before == after
    assert n >= 30
    assert after["params"] == load_params().to_json()
