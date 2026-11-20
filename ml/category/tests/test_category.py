"""Tests for the category model. All data is SYNTHETIC."""

from __future__ import annotations

import json

import numpy as np
import pytest

from category.export import FIXTURE_PATH, MODEL_PATH, ExportedModel, fixtures, model_dict
from category.features import (
    AMOUNT_EDGES,
    N_AMOUNT,
    N_HOUR,
    amount_bucket,
    char_wb_ngrams,
    hour_bucket,
    make_vectoriser,
    normalise,
)
from category.personal import PersonalLayer, blend
from category.train import category_rows, fit, predict_proba, train_final

SAMPLES = [
    "nakasero mkt",
    "boda to work",
    "a",
    "ab",
    "abc",
    "posho  and   beans",
    "",
    "x y z",
    "mtn airtime 5000",
    "emmere ya leero",
]


@pytest.fixture(scope="module")
def trained():
    return train_final()


@pytest.mark.parametrize("text", SAMPLES)
def test_char_wb_matches_sklearn(text):
    analyse = make_vectoriser().build_analyzer()
    assert char_wb_ngrams(text) == analyse(text)


def test_normalise_matches_the_payee_key():
    assert normalise("Groceries, Nakasero  market") == "groceries nakasero market"
    assert normalise("  MTN-airtime!! ") == "mtn airtime"
    assert normalise("!!!") == ""


def test_buckets_use_bisect_right_at_the_edges():
    assert amount_bucket(999) == 0
    assert amount_bucket(1000) == 1
    assert amount_bucket(10**9) == len(AMOUNT_EDGES)
    assert [hour_bucket(h) for h in (0, 5, 6, 9, 10, 21, 22, 23)] == [0, 0, 1, 1, 2, 4, 5, 5]
    assert (N_AMOUNT, N_HOUR) == (11, 6)


def test_training_is_deterministic(trained):
    vec2, clf2 = train_final()
    vec, clf = trained
    assert vec.vocabulary_ == vec2.vocabulary_
    np.testing.assert_array_equal(clf.coef_, clf2.coef_)


def test_export_round_trips_the_probabilities(trained):
    vec, clf = trained
    exported = ExportedModel(json.loads(json.dumps(model_dict(vec, clf))))
    rows = category_rows()[:300]
    sk = predict_proba(vec, clf, [r["description"] for r in rows], [r["amount"] for r in rows], [r["hour"] for r in rows])
    worst = 0.0
    for r, p in zip(rows, sk):
        mine = exported.probabilities(r["description"], r["amount"], r["hour"])
        worst = max(worst, max(abs(mine[c] - v) for c, v in zip(clf.classes_, p)))
        assert max(mine, key=mine.get) == clf.classes_[int(np.argmax(p))]
    assert worst < 1e-4  # rounding to 6 significant digits


def test_shipped_files_match_a_fresh_export(trained):
    vec, clf = trained
    shipped = json.loads(MODEL_PATH.read_text(encoding="utf-8"))
    assert shipped == json.loads(json.dumps(model_dict(vec, clf)))
    assert MODEL_PATH.stat().st_size < 400 * 1024
    on_disk = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))
    assert on_disk == json.loads(json.dumps(fixtures(ExportedModel(shipped))))
    assert len(on_disk["model"]) >= 40


def test_a_correction_wins_on_the_same_payee():
    layer = PersonalLayer()
    for _ in range(20):
        layer.add("Nakasero market", "cat.food")
    layer.add("Nakasero market", "cat.family")
    model = {"cat.food": 0.97, "cat.family": 0.01, "cat.other": 0.02}
    p = blend(model, layer, "nakasero  MARKET")
    assert max(p, key=p.get) == "cat.family"
    assert p["cat.family"] >= 0.72  # above the 0.7 threshold for showing the pill
    assert sum(p.values()) == pytest.approx(1.0)


def test_one_similar_payee_moves_the_answer_only_partly():
    layer = PersonalLayer()
    layer.add("boda to office", "cat.custom.work")
    model = {"cat.transport": 0.95, "cat.other": 0.05}
    p = blend(model, layer, "boda to work")
    assert 0.0 < p["cat.custom.work"] < 0.5
    assert max(p, key=p.get) == "cat.transport"


def test_template_split_never_shares_a_template():
    rows = category_rows()
    held = "food_market"
    train = [r for r in rows if r["template"] != held]
    vec, _ = fit(train)
    assert all(r["template"] != held for r in train)
    assert len(vec.vocabulary_) <= 3000
