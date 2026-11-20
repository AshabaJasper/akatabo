"""Turns SYNTHETIC rows from common.synth into scored entries, one pass in time order."""

from __future__ import annotations

from common.synth import make_dataset
from regular.payee import payee_key_of
from unusual.score import Entry, Params, Signals, signals

TEST_SEED = 7
TUNING_SEEDS = tuple(range(101, 111))  # never 7


def entries_of(rows: list[dict]) -> list[Entry]:
    return [
        Entry(
            amount=int(r["amount"]),
            category_id=r["category_id"],
            hour=int(r["hour"]),
            payee_key=payee_key_of(r["description"]),
            day=int(r["day"]),
        )
        for r in rows
    ]


def scored_seed(seed: int, p: Params) -> tuple[list[Signals], list[int]]:
    """Signals for every row of the seed's dataset, each against the rows before it
    (make_dataset sorts by day, hour, description), and the is_anomaly labels."""
    rows = make_dataset(seed)
    entries = entries_of(rows)
    out = [signals(e, entries[:i], p) for i, e in enumerate(entries)]
    return out, [int(r["is_anomaly"]) for r in rows]
