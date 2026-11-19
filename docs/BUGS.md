# Known bugs

Bugs scoring under 5 (frequency x severity, each 1 to 10) are filed here and left in the code until they are worth fixing. Bugs scoring 5 or more are fixed in the phase that found them.

## Open

### [bug-review] formatShort has no billions step

- **Where:** `app/lib/core/format/money.dart`, `formatShort`
- **What happens:** 1,000,000,000 UGX or more shows as `1500M` or `12345.68M` on chart labels and stat tiles.
- **How to trigger:** a yearly or category total of 1,000,000,000 UGX or more, then open a chart or stat tile.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** add a `B` step at 999,500,000 before the `M` step, with a test that `formatShort(1500000000) == '1.5B'`.
- **Found:** 19 November 2026, phase 1 review

### [bug-review] PeriodCalculator has no equality, so any settings write rebuilds period providers

- **Where:** `app/lib/core/time/period.dart` (`PeriodCalculator`), `app/lib/data/providers.dart` (`periodCalculator`)
- **What happens:** every settings change creates a new, unequal calculator, so every provider that watches it runs again and re-subscribes its database queries.
- **How to trigger:** write any setting (for example `onboardingDone`) while a screen shows period totals. This can only happen once phase 2 adds those screens.
- **Score:** frequency 4 x severity 1 = 4
- **Suggested fix:** override `==` and `hashCode` with `monthStartsOn` and `weekStartsOn`.
- **Found:** 19 November 2026, phase 1 review

### [bug-review] Month captions and daily bars ignore "Month starts on"

- **Where:** `app/lib/features/home/home_screen.dart` (the "Money out, 1 to {day} {Month}" caption) and `app/lib/features/transactions/transactions_screen.dart` (the daily bars)
- **What happens:** the totals use the chosen month start, but the Home caption always says "1 to 19 November", and the daily bars always start on the 1st. With a month starting on the 25th, the caption and the bars disagree with the figure beside them.
- **How to trigger:** set "Month starts on" to any day other than the 1st (the setting screen comes in phase 5), add entries, open Home and All transactions.
- **Score:** frequency 1 x severity 3 = 3
- **Suggested fix:** build the caption and the bar days from `currentMonthProvider`'s start and end, not from the calendar month, with a test for a month starting on the 25th.
- **Found:** 19 November 2026, phase 2 review
