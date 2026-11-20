# Akatabo models (`ml/`)

Four small models run on the phone in plain Dart, from JSON files in `app/assets/smart/`. Each one also exists here in Python. A parity test gives both languages the same inputs and requires the same outputs, so what is measured here is what runs on the phone.

**Every number in this folder comes from SYNTHETIC data.** `common/synth.py` invents Kampala-style entries (market, boda, Umeme, school fees, MoMo to family) with typos and mixed Luganda and English, seeded so every run gives the same rows. No real person's records were used. These numbers show that the methods work as designed; they say nothing yet about how well they work for a real person. That needs real entries (see the end of this file).

## Run it

```powershell
python -m pip install scikit-learn==1.9.1 pandas==3.1.1 numpy==2.5.5 matplotlib==3.11.2 pytest==9.2.0
python ml/common/synth.py          # writes ml/data/synthetic_entries.csv (git-ignored)
python -m pytest ml -q             # 59 tests
python ml/category/export.py       # and unusual/, regular/, forecast/: rewrite the artefacts and parity vectors
```

Run the exports from the project root. Each one writes its artefact into `app/assets/smart/` and its parity vectors into `app/test/smart/fixtures/`.

## The four models

| Model | Method | Synthetic result | Details |
| --- | --- | --- | --- |
| Category suggestion | TF-IDF character n-grams (char_wb, 2 to 4) with amount and hour buckets, multinomial logistic regression; blended on the phone with a personal layer (exact payee memory, then smoothed word counts) | On merchants it has never seen, the model alone is 26.3%, barely above the largest class (25.2%) and a keyword lookup (23.3%). After the person's own corrections: 59.6% after 3, 88.2% after 10. The pill shows at 70% sure and above; then it is right 92% of the time, on 58% of entries | [category/RESULTS.md](category/RESULTS.md) |
| Unusual payment | A transparent score from three signals: how far the amount is from the person's usual for that category (median and MAD of log amounts), how rare the hour is for them, and whether the payee is new; needs 20 earlier entries in the category | Held-out seed, 23 injected anomalies: Rarely 0.63 precision and 0.22 recall; Balanced 0.50 and 0.43; Often 0.30 and 0.78, with 0.25, 0.83 and 3.51 false flags per 100 normal entries. An amount-only score at the Balanced threshold reaches 0.38 and 0.13 | [unusual/RESULTS.md](unusual/RESULTS.md) |
| Regular payments | Group by payee key; at least three times, steady gaps (gap variation 0.25 or less), 80% of amounts within the band, never a median gap under 5 days | 6 of 6 series found, nothing else flagged; "any payee seen 3 or more times" gives precision 0.07. Next date: 87% within 3 days (mean 4.06 days) against 77% for last date plus the average gap | [regular/RESULTS.md](regular/RESULTS.md) |
| Month-end forecast range | The point forecast is the Phase 3 rule. Around it: a bootstrap of the person's own everyday daily spending for the days left (fixed xorshift32 random numbers, the same in both languages), plus the regular payments' bands, widened by their own past forecast errors | 222 synthetic months, 5,157 forecasts: point error 9.7% against 17.6% for run-rate and 22.2% for last month. The 80% range holds the real total 74.6% of the time, against 60.9% for the Phase 3 range | [forecast/RESULTS.md](forecast/RESULTS.md) |

## What these numbers do not show

- **The synthetic data is easy in places.** Regular payments scores perfectly because the invented bills are cleaner than real ones; 27 of 35 tuning settings tied at perfect, and the middle one was taken.
- **The forecast range is still narrower than it claims.** It covers 74.6%, not 80%, and the snapshot rule was chosen on the same synthetic months it is reported on, so that figure is optimistic.
- **The unusual detector was tuned on seeds 101 to 110 and reported on seed 7 only,** but all of them come from the same generator. The real measure is how often people answer "This was me", which the app now saves on each entry (`flagDismissed`) for exactly that reason.
- **The category model alone is weak on new merchants.** The suggestions are useful because of the person's own corrections, not because of the bundled model.

## Real data needed to evaluate them properly

A few hundred real entries with the category the person would choose; at least three months of dated entries for the forecast backtest; entries the person considers unusual; their actual recurring bills with dates; and common local words and merchant names to check coverage.
