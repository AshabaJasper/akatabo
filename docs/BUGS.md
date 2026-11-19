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

### [bug-review] Quarter bar labels ignore "Month starts on"

- **Where:** `app/lib/features/calendar/calendar_screen.dart`, the Quarter labels (`_firstOfMonthIn`)
- **What happens:** Quarter week bars are labelled at the calendar 1st of each month. With a month starting on the 25th, a quarter titled "October to December 2026" (25 Oct to 25 Jan) is labelled "Nov, Dec, Jan".
- **How to trigger:** set "Month starts on" to 25 (the setting screen comes in phase 5), open Calendar, choose Quarter.
- **Score:** frequency 1 x severity 2 = 2
- **Suggested fix:** label the week that holds each month period's start (`calc.month(...).start`), named after that month.
- **Found:** 19 November 2026, phase 2 part 2 review

### [bug-review] Calendar Day and Week titles have no year

- **Where:** `app/lib/features/calendar/calendar_screen.dart`, `_dayName` and `_range`
- **What happens:** after stepping back a year in Day or Week, the title reads the same as this year's ("Thursday 19 November", "16 to 22 November").
- **How to trigger:** Calendar, Year, step back to 2025, then switch to Week.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** add the year to the title when the period's year differs from today's.
- **Found:** 19 November 2026, phase 2 part 2 review

### [bug-review] Reveal creates a CurvedAnimation on every build

- **Where:** `app/lib/features/onboarding/reveal.dart`, `Reveal.build`
- **What happens:** each build makes a `CurvedAnimation` that adds a status listener to the group's controller and is never disposed. Listeners pile up until the page goes.
- **How to trigger:** rotate the phone or change the theme or text size while an Onboarding step is showing.
- **Score:** frequency 2 x severity 1 = 2
- **Suggested fix:** compute `Interval(...).transform(controller.value)` inside the `AnimatedBuilder`, or make `Reveal` stateful and dispose its `CurvedAnimation`.
- **Found:** 19 November 2026, phase 2 part 2 review

### [bug-review] Double-tapping Skip or the last Next opens Welcome twice

- **Where:** `app/lib/features/onboarding/onboarding_screen.dart`, `_toWelcome`
- **What happens:** each tap pushes `/welcome`, so Back from Welcome lands on a second Welcome.
- **How to trigger:** on a first launch, double-tap Skip quickly, then press Back on Welcome.
- **Score:** frequency 2 x severity 1 = 2
- **Suggested fix:** guard `_toWelcome` with a flag cleared when the pushed route returns.
- **Found:** 19 November 2026, phase 2 part 2 review

### [bug-review] A yearly payment due more than 400 days after month end is not listed

- **Where:** `app/lib/features/regular/regular_payments_screen.dart`, the "later" lookup
- **What happens:** the list looks for the next due date only up to 400 days after the month ends, but the date picker allows dates up to three years ahead. A payment due later than that is neither "this month" nor "later", so it is not listed anywhere.
- **How to trigger:** on 19 November 2026, add a Yearly payment with next due 1 March 2028.
- **Score:** frequency 1 x severity 4 = 4
- **Suggested fix:** when `nextDueOn` is after the month end, list it at `fromLocalDay(p.nextDueOn)`, or search up to the picker's limit.
- **Found:** 19 November 2026, phase 3 review

### [bug-review] Budget rows sorted by ratio can put "A little ahead" above "Nearly used"

- **Where:** `app/lib/features/budgets/budgets_screen.dart`, the sort of budget lines
- **What happens:** rows are ordered by spent over budget. With different warn levels, a budget at 85% with a 90% warn level ("A little ahead") sorts above one at 82% with a 80% warn level ("Nearly used"), so the more urgent status sits lower.
- **How to trigger:** Food at 85% of its budget with warn level 90, Bills at 82% with warn level 80, past the pace.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** sort by `status.index` first (Over, Nearly used, A little ahead, On track), then by ratio.
- **Found:** 19 November 2026, phase 4 review

### [bug-review] Settings "damaged stored value" test never stores a damaged value

- **Where:** `app/test/features/settings/settings_test.dart`, the test "a damaged stored value falls back to the default"
- **What happens:** the test writes a valid 25 and then only calls `decode` on the literal strings '31' and 'abc'. The stored row is never damaged, so the provider path (`periodCalculatorProvider`, `storedAppearanceProvider`) and the screens are not tested against a bad stored value.
- **How to trigger:** change `periodCalculatorProvider` to parse the raw stored string without `decode`. The test still passes.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** insert the bad text straight into the settings table (for example '31' for month start, '9' for week start, 'purple' for theme), wait for the provider, and expect the default. Delete the two literal `decode` lines.
- **Found:** 19 November 2026, Phase 5 bug review

### [bug-review] New account: save failure message shown twice and under the Name field

- **Where:** `app/lib/features/settings/new_account_screen.dart`, `_error` used as the field error and as the note
- **What happens:** when saving fails, "The account could not be saved. Try again." shows under the Name field and again below the button, which suggests the name is wrong.
- **How to trigger:** make the account insert fail (for example a locked database), enter a name and save.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** keep a name error and a save problem in separate fields, each shown in one place.
- **Found:** 20 November 2026, Phase 5 review

### [bug-review] New account: Kind segment labels may break mid-word on narrow phones

- **Where:** `app/lib/features/settings/new_account_screen.dart`, the five-option Kind control
- **What happens:** five options share about 256 to 286dp, so "Airtel Money" may break inside a word at 360dp or with larger text. Worked out from sizes, not seen on a screen.
- **How to trigger:** open New account on a 360dp phone, or with Appearance > Text size Large.
- **Score:** frequency 4 x severity 1 = 4
- **Suggested fix:** confirm with a 360dp golden; if it breaks, use wrapping chips or a picker, or shorter labels.
- **Found:** 20 November 2026, Phase 5 review

### [bug-review] New account: screen does not close when opened as the first route

- **Where:** `app/lib/features/settings/new_account_screen.dart` and `app/lib/app/close_screen.dart`
- **What happens:** `closeScreen` does nothing when the router cannot pop. The account is saved, but the button stays disabled and the screen stays open.
- **How to trigger:** open `/settings/accounts/new` as the first route (a deep link) and save.
- **Score:** frequency 1 x severity 3 = 3
- **Suggested fix:** when the router cannot pop, go to the parent path; or reset `_saving` if the screen is still mounted after `closeScreen`.
- **Found:** 20 November 2026, Phase 5 review

### [bug-review] Renaming a category allows a name another category already uses

- **Where:** `app/lib/features/settings/category_edit_screen.dart`, `_save`; also `CategoryRepository.rename` in `app/lib/data/repositories/repositories.dart`
- **What happens:** the save goes through when another category already has that name, so two categories show the same label on Add, Insights, Budgets and Settings. Only the icon and colour tell them apart. No code looks categories up by name, so no data is lost.
- **How to trigger:** Settings > Categories > Rename on "Food and shopping", type "Transport", save.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** refuse a name that matches another category's (trimmed, ignoring case, different id) with "Another category already has this name."; optionally check again in the repository.
- **Found:** 20 November 2026, Phase 5 review

### [bug-review] Categories settings: "Rename" links do not say which category they rename

- **Where:** `app/lib/features/settings/categories_settings_screen.dart`, the `AkTextLink('Rename', ...)` on each row
- **What happens:** every link is announced as "Rename, button". Voice Access users cannot say "Rename Food", and TalkBack's controls list shows identical entries.
- **How to trigger:** turn on TalkBack or Voice Access and open Settings > Categories.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** give `AkTextLink` an optional `semanticLabel` and pass "Rename <name>".
- **Found:** 20 November 2026, Phase 5 review

### [bug-review] Choose dates: preset range text goes stale across midnight

- **Where:** `app/lib/features/filters/choose_dates_screen.dart`, the range line under the presets (`_first` and `_last`)
- **What happens:** the dates shown under a preset are copied when the screen opens or a chip is tapped. The day count on the button and the applied range use today. If the screen stays open past midnight, the text can show yesterday's range while today's is applied.
- **How to trigger:** choose "Last 7 days", leave the screen open past midnight, then tap the button.
- **Score:** frequency 1 x severity 3 = 3
- **Suggested fix:** when not on Custom, work out the text in `build()` from `presetPeriod(_preset, today, calc)`.
- **Found:** 20 November 2026, Phase 5 review
