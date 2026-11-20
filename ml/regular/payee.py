"""Payee keys and small shared helpers, mirrored exactly in Dart.

payee_key_of mirrors app/lib/smart/text_normaliser.dart: lower case, every run of
characters other than a-z and 0-9 becomes one space, then the ends are trimmed.

median and plain_sum are written out by hand so that Dart can do the same operations
in the same order. Python 3.12+ sum() on floats uses compensated summation, which Dart
does not, so plain_sum adds left to right on purpose.
"""

from __future__ import annotations

import math
import re

_NOT_WORD = re.compile(r"[^a-z0-9]+")


def payee_key_of(description: str) -> str:
    return _NOT_WORD.sub(" ", description.lower()).strip()


def median(values: list[float]) -> float:
    """Middle value; the mean of the two middle values for an even count."""
    if not values:
        raise ValueError("median of nothing")
    s = sorted(values)
    m = len(s) // 2
    if len(s) % 2 == 1:
        return float(s[m])
    return (s[m - 1] + s[m]) / 2.0


def plain_sum(values: list[float]) -> float:
    total = 0.0
    for v in values:
        total += v
    return total


def round_half_up(x: float) -> int:
    """Rounds .5 up for positive numbers. Python round() rounds half to even; Dart
    round() rounds half away from zero. floor(x + 0.5) is the same in both."""
    return int(math.floor(x + 0.5))
