"""Features for the category model. Every function here has a Dart twin in
app/lib/smart/category/, and the parity test holds the two to the same numbers.

- normalise: the payee key (app/lib/smart/text_normaliser.dart): lower case, letters and
  digits only, single spaces.
- char_wb_ngrams: scikit-learn's char_wb analyser, written out so the Dart port has a
  readable reference and a test can hold it to sklearn's own output.
- amount and hour buckets: one-hot tokens appended after the TF-IDF block.
"""

from __future__ import annotations

import re
from bisect import bisect_right

import numpy as np
from scipy import sparse
from sklearn.feature_extraction.text import TfidfVectorizer

NGRAM_MIN = 2
NGRAM_MAX = 4
MAX_FEATURES = 3000

# Shillings. Bucket i holds amounts with i edges at or below them (bisect_right).
AMOUNT_EDGES: tuple[int, ...] = (1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000, 1000000)
# Local hours. 0-5 night, 6-9 morning, 10-13 midday, 14-17 afternoon, 18-21 evening, 22-23 late.
HOUR_EDGES: tuple[int, ...] = (6, 10, 14, 18, 22)

_NOT_WORD = re.compile(r"[^a-z0-9]+")
_WHITE_SPACES = re.compile(r"\s\s+")


def normalise(description: str) -> str:
    """Same as payeeKeyOf in Dart."""
    return _NOT_WORD.sub(" ", description.lower()).strip()


def char_wb_ngrams(text: str, n_min: int = NGRAM_MIN, n_max: int = NGRAM_MAX) -> list[str]:
    """sklearn's _char_wb_ngrams (lowercase is applied by the vectoriser's preprocessor)."""
    text = _WHITE_SPACES.sub(" ", text.lower())
    out: list[str] = []
    for w in text.split():
        w = " " + w + " "
        w_len = len(w)
        for n in range(n_min, n_max + 1):
            offset = 0
            out.append(w[offset : offset + n])
            while offset + n < w_len:
                offset += 1
                out.append(w[offset : offset + n])
            if offset == 0:  # the word is shorter than n
                break
    return out


def amount_bucket(amount: int) -> int:
    return bisect_right(AMOUNT_EDGES, amount)


def hour_bucket(hour: int) -> int:
    return bisect_right(HOUR_EDGES, hour)


N_AMOUNT = len(AMOUNT_EDGES) + 1
N_HOUR = len(HOUR_EDGES) + 1


def make_vectoriser() -> TfidfVectorizer:
    return TfidfVectorizer(
        analyzer="char_wb",
        ngram_range=(NGRAM_MIN, NGRAM_MAX),
        max_features=MAX_FEATURES,
        lowercase=True,
        smooth_idf=True,
        sublinear_tf=False,
        norm="l2",
        dtype=np.float64,
    )


def bucket_matrix(amounts, hours) -> sparse.csr_matrix:
    rows, cols = [], []
    for i, (a, h) in enumerate(zip(amounts, hours)):
        rows += [i, i]
        cols += [amount_bucket(int(a)), N_AMOUNT + hour_bucket(int(h))]
    data = np.ones(len(rows), dtype=np.float64)
    return sparse.csr_matrix((data, (rows, cols)), shape=(len(amounts), N_AMOUNT + N_HOUR))


def design_matrix(vec: TfidfVectorizer, descriptions, amounts, hours) -> sparse.csr_matrix:
    texts = [normalise(d) for d in descriptions]
    return sparse.hstack([vec.transform(texts), bucket_matrix(amounts, hours)], format="csr")
