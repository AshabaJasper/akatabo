# Unusual payment: results (SYNTHETIC data only)

Every number below is measured on synthetic entries from `ml/common/synth.py` with injected
anomalies. None of it is real-world performance. The real measure is how often people answer
"This was me", which only real use gives.

## Method

`score.py` adds three signals: the upward robust z of the log amount against the payee's own
history (at least 4 earlier payments) or else the category's history (median and MAD, MAD
floored at 0.1), a fixed weight when under 0.5% of the person's earlier entries were at this
hour, and a fixed weight when no earlier payee key is equal or one edit away (a swapped-letter
typo is not a new payee). Nothing is flagged until the category has 20 earlier entries.

Tuning (`tune.py`) used seeds 101-110 only. Each setting has a budget of false flags per 100
normal entries (Rarely 0.5, Balanced 1.5, Often 4); thresholds take the best recall inside the
budget, and the weights and hour cut-off the best Balanced recall. Chosen: hour weight 7,
payee weight 5, hour share under 0.005, thresholds Rarely 7.0, Balanced 5.25, Often 3.75.

## Held-out seed 7 (1,221 rows, 23 injected anomalies, 1,198 normal)

| Setting | Precision | Recall | False flags per 100 normal |
| --- | --- | --- | --- |
| Rarely | 0.63 (5 of 8) | 0.22 (5 of 23) | 0.25 |
| Balanced | 0.50 (10 of 20) | 0.43 (10 of 23) | 0.83 |
| Often | 0.30 (18 of 60) | 0.78 (18 of 23) | 3.51 |

Baselines on the same rows and gate:

| Baseline | Precision | Recall | False flags per 100 normal |
| --- | --- | --- | --- |
| Amount z only, Balanced threshold | 0.38 | 0.13 | 0.42 |
| Amount z only, Often threshold | 0.12 | 0.13 | 1.92 |
| Amount over 3 times the category median | 0.02 | 0.22 | 16.69 |

Balanced recall by injected kind: amount 3 of 5 (2 came before the 20-entry gate), odd hour
3 of 5, new payee 4 of 13 (a new payee alone scores 5, under the Balanced threshold, so it
needs a second signal; Often flags it alone).

With 23 anomalies the held-out figures move by about 4 points per entry; read them as rough.
Tuning-seed figures are in `tuned.json`.

## Files

`score.py` (reference), `data.py`, `metrics.py`, `tune.py`, `evaluate.py`, `export.py`
(writes `app/assets/smart/unusual_params.json` and the parity vectors), `tests/`.
Run from `ml/`: `python -m unusual.tune`, `python -m unusual.evaluate`, `python -m unusual.export`.
