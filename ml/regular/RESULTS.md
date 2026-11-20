# Regular payments: results (SYNTHETIC data only)

Every number below is measured on synthetic entries from `ml/common/synth.py`. None of it is
real-world performance.

## Method

`detect.py` groups money-out payments by payee key (`payee.py` mirrors
`app/lib/smart/text_normaliser.dart`) and keeps a group when: at least 3 payments; median gap
between 5 and 400 days (the minimum interval keeps lunch from being called a bill); unit gaps
(each gap divided by the whole intervals it spans, so a missed month counts as two) with a
coefficient of variation of at most 0.25, and missed intervals at most 30% of all intervals;
at least 80% of amounts within 10% of the median amount; last payment no more than 2.5
intervals before today. Next date = last payment + median unit gap; the amount range is the
lowest and highest amount inside the band.

`cvMax` and `amountShareMin` were chosen on seeds 101-110 (`evaluate.py tune()`): 27 of 35
grid settings tied at precision and recall 1.0 there, so the middle of that plateau was taken
(0.25, 0.8) rather than an edge. `minIntervalDays` (5), `amountBand` (10%),
`staleIntervals` (2.5) and `maxMissedShare` (0.3) were set by reasoning, not tuned; the
synthetic data has no case that separates nearby values.

## Held-out seed 7

| | Detected | True series found | Precision | Recall |
| --- | --- | --- | --- | --- |
| Rule | 6 | 6 of 6 | 1.00 | 1.00 |
| Baseline: any payee seen 3+ times | 82 | 6 of 6 | 0.07 | 1.00 |
| Rule without the minimum interval | 6 | 6 of 6 | 1.00 | 1.00 |
| Stress (seed 7 plus a 5,000 lunch bought about 9 days in 10): rule | 6 | 6 of 6 | 1.00 | 1.00 |
| Stress: rule without the minimum interval | 7 | 6 of 6 | 0.86 | 1.00 |

The generator's everyday amounts vary too much to pass the amount band, so the minimum interval
only matters in the stress set, which adds a fixed-price daily lunch the generator does not make.

Next-date error (cut-offs every 30 days from day 180; 69 predictions):

| | Mean absolute days | Median | Within 3 days | Worst |
| --- | --- | --- | --- | --- |
| Rule (last + median unit gap) | 4.06 | 2 | 87% | 56 |
| Baseline (last + mean raw gap) | 4.58 | 2 | 77% | 54 |

The large errors are skipped occurrences: when a month is missed, the next real payment comes
an interval later than predicted. Six true series is a small test; read precision and recall
as "no misses or false series on this seed", not as a rate.

## Files

`payee.py` (normaliser, median, sum and rounding shared with Dart), `detect.py` (reference),
`evaluate.py` (tune and evaluate), `export.py` (writes `app/assets/smart/regular_params.json`
and the parity vectors), `tests/`. Run from `ml/`: `python -m regular.evaluate`,
`python -m regular.export`.
