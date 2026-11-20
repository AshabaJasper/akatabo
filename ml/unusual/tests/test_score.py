import json
import math
from pathlib import Path

import pytest

from regular.payee import median, payee_key_of
from unusual.data import TEST_SEED, TUNING_SEEDS
from unusual.evaluate import evaluate, load_params
from unusual.export import VECTORS_OUT, vectors
from unusual.score import Entry, Params, is_new_payee, osa_distance, score

HERE = Path(__file__).resolve().parents[1]


def e(amount, key="shop", hour=12, cat="cat.food", day=0):
    return Entry(amount, cat, hour, key, day)


def test_median_odd_and_even():
    assert median([3.0, 1.0, 2.0]) == 2.0
    assert median([4.0, 1.0, 3.0, 2.0]) == 2.5
    with pytest.raises(ValueError):
        median([])


def test_payee_key_matches_the_dart_normaliser():
    assert payee_key_of("Groceries, Nakasero  market") == "groceries nakasero market"
    assert payee_key_of("  MTN-airtime!! ") == "mtn airtime"
    assert payee_key_of("") == ""


def test_osa_counts_a_swap_as_one_edit():
    assert osa_distance("shop", "sohp") == 1
    assert osa_distance("shop", "shop") == 0
    assert osa_distance("abc", "") == 3
    assert osa_distance("kitten", "sitting") == 3


def test_typo_is_known_but_a_different_name_is_new():
    known = {"nakasero market", "boda boda"}
    assert not is_new_payee("nakasreo market", known)
    assert is_new_payee("new payee 4821", known)
    assert not is_new_payee("", known)


def test_gate_blocks_flags_before_twenty_category_entries():
    p = Params()
    hist = [e(5000, day=d) for d in range(19)]
    r = score(e(500000), hist, p, "often")
    assert r.signals.amount_z > 10
    assert not r.flagged
    r = score(e(500000), hist + [e(5000, day=19)], p, "often")
    assert r.flagged and "amount" in r.reasons


def test_payee_history_is_the_baseline_when_long_enough():
    p = Params()
    bills = [e(5000, key="airtime", cat="cat.bills", day=d) for d in range(30)]
    rent = [e(600000, key="house rent", cat="cat.bills", day=30 * m) for m in range(4)]
    r = score(e(600000, key="house rent", cat="cat.bills"), bills + rent, p)
    assert r.signals.basis == "payee"
    assert r.signals.amount_z < 1
    assert not r.flagged


def test_smaller_than_usual_is_not_unusual():
    p = Params()
    hist = [e(50000, day=d) for d in range(30)]
    assert score(e(500), hist, p, "often").signals.amount_z == 0.0


def test_mad_floor_keeps_a_flat_history_finite():
    p = Params()
    hist = [e(5000, day=d) for d in range(25)]
    z = score(e(50000), hist, p).signals.amount_z
    assert math.isfinite(z)
    assert z == pytest.approx(math.log(10) / (p.mad_scale * p.mad_floor))


def test_tuned_thresholds_are_ordered_and_seed_7_is_held_out():
    t = load_params().thresholds
    assert t["rarely"] >= t["balanced"] >= t["often"]
    assert TEST_SEED not in TUNING_SEEDS
    tuned = json.loads((HERE / "tuned.json").read_text(encoding="utf-8"))
    assert TEST_SEED not in tuned["tuning_seeds"]
    assert tuned["synthetic"] is True


def test_more_often_flags_more():
    report = evaluate()
    assert report["synthetic"] is True
    s = report["score"]
    assert s["often"]["tp"] + s["often"]["fp"] >= s["balanced"]["tp"] + s["balanced"]["fp"]
    assert s["balanced"]["tp"] + s["balanced"]["fp"] >= s["rarely"]["tp"] + s["rarely"]["fp"]


def test_exported_vectors_are_current():
    on_disk = json.loads(VECTORS_OUT.read_text(encoding="utf-8"))
    fresh = json.loads(json.dumps(vectors(load_params())))
    assert on_disk == fresh
    assert len(on_disk["sequence"]["targets"]) + len(on_disk["cases"]) >= 30
