# Category suggestion: method and SYNTHETIC results

Every number on this page comes from the seeded synthetic generator in `ml/common/synth.py`
(seed 7, 540 days). None of it is real-world performance. The real measure will be how often
people keep a suggestion, which only real use gives (`categoryWasCorrected` on each entry).

## Method

- **Text.** The description is normalised to the payee key (lower case, letters and digits,
  single spaces; `app/lib/smart/text_normaliser.dart`). Features are scikit-learn TF-IDF over
  `char_wb` character n-grams of length 2 to 4, `max_features=3000`, `smooth_idf`, l2 norm.
- **Amount and hour.** One-hot tokens appended after the TF-IDF block. Amount buckets (UGX)
  at edges 1,000, 2,000, 5,000, 10,000, 20,000, 50,000, 100,000, 200,000, 500,000 and
  1,000,000; hour buckets at 6, 10, 14, 18 and 22 (a value falls after every edge at or below
  it).
- **Model.** Multinomial logistic regression (lbfgs, C = 4, seeded). C was not tuned on the
  test split; C = 0.25, 1 and 16 gave 22.6%, 25.0% and 28.0% template-split accuracy, so the
  choice barely matters here.
- **Export.** `app/assets/smart/category_model.json` (187 KB): vocabulary, idf, coefficients
  and intercepts rounded to 6 significant digits, class list and bucket edges. The rounding
  moves sklearn's probabilities by under 1e-4 (pytest).
- **Personal layer, on the phone** (`app/lib/smart/category/`, Python twin in `personal.py`):
  1. Exact-match memory keyed by the payee key. Past entries for that key weigh 0.2^r
     (r = 0 for the newest), so the newest choice holds over 80% of the memory.
  2. Similar payees: every other key with Jaccard similarity s >= 0.2 between the two n-gram
     sets adds s^2 times its memory to the evidence E for each category.
  3. Blend: `P = m * memory + (1 - m) * (w * similar + (1 - w) * model)`, with m = 0.9 when
     the key is known (else 0) and w = E / (E + 1). One similar payee therefore moves the
     answer only partly. Categories the person made are reachable through 1 and 2.
  "87% sure" is this P, restricted to the categories on offer and renormalised, on the phone.

## Data and split

1,198 synthetic rows from 22 merchant templates (16 everyday, 6 regular payments). The 27
injected anomaly rows are left out: they reuse everyday descriptions without a template id
and would leak merchants across the split. The split is **leave one template out**: the
model never sees any spelling of the merchant it is scored on. Descriptions include swapped
letter typos (156 rows), Luganda (emmere, matooke, yaka) and mixed English.

## Results (synthetic, template split)

| | Accuracy |
| --- | --- |
| Model (rows) | **26.3%** |
| Model (mean over templates) | 24.6% |
| Majority class of each training fold | 3.0% |
| Largest class for every row (Bills) | 25.2% |
| Keyword baseline (each word seen in training mapped to its most common category) | 23.3% |
| Typo rows: model / keyword | 18.6% / 9.6% |

The fold-majority baseline is near zero because removing one template of the largest class
hands the majority to another class. On merchants it has never seen, the model is only a
little better than the baselines: the 22 synthetic templates share few words across
categories. Spellings of merchants it was trained on, typos included, get the right
category at 91% to 99% in the parity fixtures. That gap is the point of the personal layer:
a person's own merchants are learned on the phone.

**Learning curve** (a simulated person with 40 unrelated past entries labels the first k
entries of a held-out merchant; scored on that merchant's later entries):

| k | Same category | Moved to a new category of their own |
| --- | --- | --- |
| 0 | 26.5% | 0.0% |
| 1 | 44.0% | 22.4% |
| 3 | 59.6% | 42.0% |
| 5 | 74.1% | 61.4% |
| 10 | 88.2% | 81.5% |

## When the pill shows (decision)

| Threshold | Model alone, unseen merchant: right when shown / shown | Blended after 1 to 10 entries: right when shown / shown |
| --- | --- | --- |
| 0.5 | 31.4% / 51.3% | 80.0% / 73.2% |
| 0.6 | 36.6% / 32.1% | 86.5% / 65.0% |
| **0.7** | 40.9% / 17.4% | **92.1% / 57.9%** |
| 0.8 | 59.8% / 6.8% | 96.8% / 52.4% |
| 0.9 | 62.1% / 2.4% | 98.8% / 49.0% |

- **Threshold 0.7.** With some history the pill is right 92% of the time it shows and shows
  for 58% of entries (synthetic). Higher thresholds gain a few points and lose few showings,
  but 0.7 is also what the memory guarantees: the latest choice for a known payee gets at
  least 0.9 x 0.8 = 0.72, so a correction always shows on the next entry for that payee.
- **At least 5 categorised entries of the person's own** since "Forget everything it has
  learned" (whose dialog says suggestions "start again from your next entries"). Unseen
  merchants are where the model alone is weak (41% right at 0.7), so a brand-new person sees
  nothing until they have taught it a little.
- **At least 3 letters or digits** in the description.
- The suggested tile is preselected in the grid and the pill is shown, as DESIGN_SYSTEM.md
  ("Adding a transaction") asks; tapping the pill fixes the choice; tapping another tile is
  a correction, stored through `suggestedCategoryId`, `suggestionConfidence` and
  `categoryWasCorrected`. Percentages are whole numbers capped at 99%.

## Reproduce

From `ml/`: `python -m category.train`, `python -m category.evaluate`,
`python -m category.export` (writes the model and the Dart parity fixtures),
`python -m pytest category/tests -q`. scikit-learn 1.9.1, numpy 2.5.5, scipy 1.18.1,
Python 3.13.
