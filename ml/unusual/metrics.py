"""Precision, recall and flags per 100 normal entries. SYNTHETIC evaluation only."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Counts:
    tp: int
    fp: int
    fn: int
    normal: int

    @property
    def precision(self) -> float:
        return self.tp / (self.tp + self.fp) if self.tp + self.fp else 0.0

    @property
    def recall(self) -> float:
        return self.tp / (self.tp + self.fn) if self.tp + self.fn else 0.0

    @property
    def flags_per_100_normal(self) -> float:
        return 100.0 * self.fp / self.normal if self.normal else 0.0

    def __add__(self, other: "Counts") -> "Counts":
        return Counts(
            self.tp + other.tp, self.fp + other.fp, self.fn + other.fn, self.normal + other.normal
        )


def count(flags: list[bool], labels: list[int]) -> Counts:
    tp = sum(1 for f, y in zip(flags, labels) if f and y)
    fp = sum(1 for f, y in zip(flags, labels) if f and not y)
    fn = sum(1 for f, y in zip(flags, labels) if not f and y)
    normal = sum(1 for y in labels if not y)
    return Counts(tp, fp, fn, normal)
