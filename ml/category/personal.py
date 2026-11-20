"""The personal layer and the blend: the Python reference for
app/lib/smart/category/personal_layer.dart and category_suggester.dart.

History is the person's own categorised entries, oldest first. Two parts:

1. Exact-match memory, keyed by the payee key. Each past entry for that key weighs
   MEMORY_DECAY ** r, where r is 0 for the newest. The newest entry therefore holds more than
   four fifths of the memory's weight (the older ones sum to under 1/4). With MEMORY_WEIGHT
   0.9 the latest choice for a known key gets at least 0.9 * 0.8 = 0.72 of the blend, above
   the 0.7 threshold for showing it, so a correction wins on the next entry for that payee.
2. Similar payees. For every other known key, s = Jaccard similarity of the two sets of
   character n-grams (the model's char_wb 2-4). Keys below MIN_SIMILARITY are ignored. Each
   key adds s**2 times its memory distribution to the evidence for each category. The
   evidence E is smoothed toward the model with a pseudo-count of TOKEN_PSEUDO_COUNT:
   w = E / (E + TOKEN_PSEUDO_COUNT). One similar payee (s around 0.5, E around 0.25) moves
   the answer only partly; several agreeing payees move it most of the way.

P = m * P_memory + (1 - m) * (w * P_similar + (1 - w) * P_model), m = MEMORY_WEIGHT or 0.
Categories the model does not know (the person's own) get P_model = 0 and are reachable
through the first two parts.
"""

from __future__ import annotations

from collections import OrderedDict

from .features import char_wb_ngrams, normalise

MEMORY_DECAY = 0.2
MEMORY_WEIGHT = 0.9
MIN_SIMILARITY = 0.2
TOKEN_PSEUDO_COUNT = 1.0


class PersonalLayer:
    def __init__(self) -> None:
        # key -> list of category ids, oldest first
        self._by_key: "OrderedDict[str, list[str]]" = OrderedDict()
        self._grams: dict[str, frozenset[str]] = {}
        self.size = 0

    def add(self, description: str, category_id: str) -> None:
        key = normalise(description)
        if not key:
            return
        if key not in self._by_key:
            self._by_key[key] = []
            self._grams[key] = frozenset(char_wb_ngrams(key))
        self._by_key[key].append(category_id)
        self.size += 1

    def memory(self, key: str) -> dict[str, float]:
        cats = self._by_key.get(key)
        if not cats:
            return {}
        out: dict[str, float] = {}
        w = 1.0
        for c in reversed(cats):
            out[c] = out.get(c, 0.0) + w
            w *= MEMORY_DECAY
        total = sum(out.values())
        return {c: v / total for c, v in out.items()}

    def similar(self, key: str) -> tuple[dict[str, float], float]:
        """Evidence per category from other keys, and its total E."""
        grams = frozenset(char_wb_ngrams(key))
        evidence: dict[str, float] = {}
        if not grams:
            return evidence, 0.0
        for other, other_grams in self._grams.items():
            if other == key:
                continue
            inter = len(grams & other_grams)
            if inter == 0:
                continue
            s = inter / (len(grams) + len(other_grams) - inter)
            if s < MIN_SIMILARITY:
                continue
            for c, p in self.memory(other).items():
                evidence[c] = evidence.get(c, 0.0) + s * s * p
        return evidence, sum(evidence.values())


def blend(model_probs: dict[str, float], layer: PersonalLayer, description: str) -> dict[str, float]:
    key = normalise(description)
    mem = layer.memory(key) if key else {}
    evidence, total = layer.similar(key) if key else ({}, 0.0)
    m = MEMORY_WEIGHT if mem else 0.0
    w = total / (total + TOKEN_PSEUDO_COUNT)
    cats = set(model_probs) | set(mem) | set(evidence)
    out: dict[str, float] = {}
    for c in cats:
        sim = evidence.get(c, 0.0) / total if total > 0 else 0.0
        rest = w * sim + (1.0 - w) * model_probs.get(c, 0.0)
        out[c] = m * mem.get(c, 0.0) + (1.0 - m) * rest
    return out
