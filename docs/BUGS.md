# Known bugs

Bugs scoring under 5 (frequency x severity, each 1 to 10) are filed here and left in the code until they are worth fixing. Bugs scoring 5 or more are fixed in the phase that found them.

## Open

### [bug-review] Calendar Savings card leaves the Calendar behind

- **Where:** `app/lib/features/calendar/period_cards.dart` (`_SavingsCard`, `openGoalsTab`)
- **What happens:** tapping the Savings card switches to the Goals tab with `go`, so the Calendar and the period chosen on it are gone; back lands on Home. The Top category rows on the same screen use `push` and come back.
- **How to trigger:** Home, Calendar, step back to an earlier month, tap Savings, press back.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** push the full-screen Savings goals list (`Routes.goals`) from Calendar, or keep the tab switch and say so in the design notes.
- **Found:** 25 November 2026, bug review of the Home savings, Goals switch and Calendar cards

### [bug-review] Calendar money card hints at figures while amounts are hidden

- **Where:** `app/lib/features/calendar/period_cards.dart` (`_Figure` colour, `_MoneyCard` net sentence)
- **What happens:** with Hide amounts on, the Out and In figures are still muted for nothing and coloured otherwise, and the sentence still says "more in than out" or "more out than in". Someone looking over a shoulder can tell whether money came in and which side was bigger.
- **How to trigger:** hide amounts, open Calendar on a period with spending and no income.
- **Score:** frequency 3 x severity 1 = 3
- **Suggested fix:** while hidden, draw both figures in `ink-muted` (as Insights does) and leave the net sentence out.
- **Found:** 25 November 2026, bug review of the Home savings, Goals switch and Calendar cards

### [bug-review] Goal moves list order is not stable for moves on the same day

- **Where:** `app/lib/features/goals/goal_detail_screen.dart` (`_MovesCard`, the sort of moves by day)
- **What happens:** moves are sorted by `localDay` alone. Dart's `List.sort` is not stable above 32 items, so moves made on the same day can swap places between rebuilds once a goal has more than 32 moves.
- **How to trigger:** a goal with 33 or more moves, several on one day; open it, then add another move.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** sort by `localDay`, then `occurredAt`, then `id`.
- **Found:** 24 November 2026, second bug review of the goal screens

### [bug-review] The move sheet's over-balance warning is not announced

- **Where:** `app/lib/features/goals/move_sheet.dart` (the "This is more than is free in ..." caption)
- **What happens:** the warning appears as plain text under the amount field. A screen reader user typing the amount is not told it appeared.
- **How to trigger:** with TalkBack on, type an amount larger than the account's free money in Set aside.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** wrap the caption in `Semantics(liveRegion: true)`.
- **Found:** 24 November 2026, second bug review of the goal screens

### [bug-review] Goal percent rounds up to 100% before the goal is reached

- **Where:** `app/lib/features/goals/goal_detail_screen.dart` (`_Block`, the percent figure) and `app/lib/features/goals/goal_widgets.dart` (`GoalBar`, the spoken value)
- **What happens:** `(progress * 100).round()` shows "100% saved", and reads "100 percent saved", while the goal is still short, next to "UGX 400 to go".
- **How to trigger:** a goal of UGX 100,000 with UGX 99,600 set aside; open it.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** use `floor()`, or cap at 99 while the goal is not reached, in both places.
- **Found:** 24 November 2026, bug review of the goal screens and Goals tab

### [bug-review] Savings goal money can be set aside in an account that is switched off

- **Where:** `app/lib/data/repositories/repositories.dart` (`GoalRepository.addMove`)
- **What happens:** `addMove` only checks that the account exists, so a positive move into a switched-off account is accepted. Add stops offering that account, but a goal can still put money in it.
- **How to trigger:** switch an account off, then `addMove(goalId: g, accountId: offAccount, amount: 1000)`. It succeeds.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** refuse with `StateError('Account … is switched off')` when `amount > 0 && !account.enabled`. Keep take-outs allowed so the money can come back out.
- **Found:** 24 November 2026, savings goals bug review
- **Since:** the goal move sheet offers only switched-on accounts for Set aside, so the screens cannot reach it. The repository still accepts it.

### [bug-review] GoalRepository.delete doc says "while money is set aside" but any move blocks it

- **Where:** `app/lib/data/repositories/repositories.dart` (`GoalRepository.delete` doc comment)
- **What happens:** the doc says delete is refused only while money is set aside. The code refuses whenever any move exists, even if they net to zero, which is the intended rule (test `a goal with any moves cannot be deleted`). A screen built from the doc would offer Delete on a goal at zero saved and then hit a `StateError`.
- **How to trigger:** add 1,000, take out 1,000, then `delete(goalId)`. It throws.
- **Score:** frequency 2 x severity 1 = 2
- **Suggested fix:** change the doc to "Refused, and nothing changes, while the goal has any moves (its history keeps them): archive it instead."
- **Found:** 24 November 2026, savings goals bug review

### [bug-review] Forecast day labels shift a day after the clocks go back

- **Where:** `app/lib/features/forecast/forecast_screen.dart` (the chart's `dayLabelOf`)
- **What happens:** the labels add 24-hour durations to the month start. Across the end of daylight saving that lands on 23:00 of the day before, so each label after the change reads one day early. Africa/Kampala has no daylight saving, so it does not happen there.
- **How to trigger:** set the phone to a zone with daylight saving (for example Europe/London) and open Forecast in October.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** `DateTime(month.start.year, month.start.month, month.start.day + i)`.
- **Found:** 24 November 2026, Phase 3 bug review

### [bug-review] READINESS.md names the wrong scandelete path

- **Where:** `docs/fdroid/READINESS.md` (section 2, "Prebuilt binaries in the source")
- **What happens:** the audit says the recipe uses `scandelete: .pub-cache`; the recipe uses `app/.pub-cache`, which is correct, because `scandelete` is relative to the repository root and the pub cache sits inside `subdir: app`.
- **How to trigger:** a reviewer compares the audit with the recipe and copies the wrong path.
- **Score:** frequency 1 x severity 2 = 2
- **Suggested fix:** change it to `scandelete: app/.pub-cache`.
- **Found:** 24 November 2026, Phase 7 bug review

### [bug-review] READINESS.md mentions scanignore entries the draft does not have

- **Where:** `docs/fdroid/READINESS.md` ("To verify on a build server", item 1)
- **What happens:** it says the scanner passes "with the `scandelete` and `scanignore` entries in the draft", but the draft has no `scanignore`.
- **How to trigger:** read the line beside the recipe.
- **Score:** frequency 1 x severity 1 = 1
- **Suggested fix:** remove "and `scanignore`".
- **Found:** 24 November 2026, Phase 7 bug review

### [bug-review] About > Open-source licences reads "Akatabo" twice to screen readers

- **Where:** `app/lib/features/privacy/about_section.dart` (the `applicationIcon` passed to `showLicensePage`)
- **What happens:** the icon is `AkLogo(wordmark: false)`, which carries the label "Akatabo" as an image, and the licence page shows the application name "Akatabo" as text right under it, so TalkBack or VoiceOver reads the name twice.
- **How to trigger:** turn on TalkBack, open Settings > Privacy and data > About > Open-source licences, and swipe through the header.
- **Score:** frequency 2 x severity 1 = 2
- **Suggested fix:** wrap the icon in `ExcludeSemantics`.
- **Found:** 24 November 2026, bug review after the Phase 2 merge

### [bug-review] F-Droid draft builds a release APK signed with the debug key

- **Where:** `app/android/app/build.gradle.kts` (release `signingConfig = signingConfigs.getByName("debug")`), used by the `build:` step of `docs/fdroid/com.persmon.akatabo.yml`
- **What happens:** `flutter build apk --release` gives a debug-signed APK, but F-Droid expects an unsigned one in `output` that it signs itself. The build or publish step may fail, or the APK gets signed twice, and it cannot be checked as reproducible.
- **How to trigger:** once the READINESS.md blockers are cleared, run `fdroid build -v -l com.persmon.akatabo`.
- **Score:** frequency 1 x severity 4 = 4
- **Suggested fix:** sign releases only when `key.properties` exists and leave them unsigned otherwise (this is also needed for Play), or add a `prebuild` `sed` that deletes the signing line. Then check with `apksigner verify` that the output is unsigned.
- **Found:** 24 November 2026, Phase 7 bug review

### [bug-review] ml/README.md export command fails as written

- **Where:** `ml/README.md`, "Run it" (`python ml/category/export.py`)
- **What happens:** the exports use package imports, so running the file path gives `ImportError: attempted relative import with no known parent package` (or `No module named 'common'`).
- **How to trigger:** run the documented command from the project root.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** document `PYTHONPATH=ml python -m category.export` (and `unusual`, `regular`, `forecast`). With that form, all four artefacts rebuild byte for byte.
- **Found:** 24 November 2026, Phase 7 F-Droid audit

### [bug-review] The one-colour mark's layer has no bounds

- **Where:** `app/lib/core/brand/akatabo_mark.dart` (`AkMarkPainter._paintOneColour`, `saveLayer(null, ...)`)
- **What happens:** the layer is as big as the current clip, not the mark, so an unclipped parent can make it screen-sized.
- **How to trigger:** show the one-colour mark in a scrolling list on a low-end phone and profile the raster thread.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** pass `AkMarkGeometry.bounds.inflate(AkMarkGeometry.lineWidth)` as the bounds; it is in grid space after the transform.
- **Found:** 24 November 2026, brand bug review

### [bug-review] The brand SVG tool treats any transparent colour as currentColor and drops alpha

- **Where:** `app/tool/render_brand_test.dart` (`_hex`, the `Color(0x00000000)` sentinel in `_markShapes`)
- **What happens:** a fully transparent colour becomes `currentColor`, and a part-transparent one becomes opaque in the SVG while the painter draws it see-through.
- **How to trigger:** add `AkMarkInOneColour(colour.withValues(alpha: 0.6))` to the tool and compare the SVG with the PNG.
- **Score:** frequency 1 x severity 2 = 2
- **Suggested fix:** pass an explicit fill string (`currentColor` or hex) and write `fill-opacity` when alpha is below 255.
- **Found:** 24 November 2026, brand bug review

### [bug-review] The preview SVG reader matches `x=` inside `rx=`

- **Where:** `app/tool/render_brand_test.dart` (`_drawSvg`, `attr`/`sattr`)
- **What happens:** a rect with `rx` but no `x` is drawn shifted right by its corner radius. Today only lockups are previewed, and they never hit this.
- **How to trigger:** call `_drawSvg` on `design/brand/akatabo-icon.svg`.
- **Score:** frequency 1 x severity 2 = 2
- **Suggested fix:** anchor the attribute name: `RegExp('(?:^|\s)$name="([^"]*)"')`.
- **Found:** 24 November 2026, brand bug review

### [device check] Back links name a fixed screen, not the one you came from

- **Where:** `app/lib/features/fees/fees_screen.dart`, `app/lib/features/forecast/forecast_screen.dart`, `app/lib/features/transactions/transaction_detail_screen.dart` (`AkBackLink` labels)
- **What happens:** Fees and Forecast always say "Insights" and transaction detail always says "Transactions", even when opened from Home. Tapping still goes back to Home; only the label is wrong.
- **How to trigger:** on Home, tap the Fees and tax tile, the forecast card or a Latest entry.
- **Score:** frequency 4 x severity 1 = 4
- **Suggested fix:** pass a `from` query parameter as Restore does (`from=home`) and pick the label from it.
- **Found:** 23 November 2026, Pixel 8 Pro check

### [bug-review] Edit account shows "Pick this first" off for the account Add opens on

- **Where:** `app/lib/features/settings/new_account_screen.dart` (`_fill`, and the "Now it is" detail)
- **What happens:** when no account is marked default, Add opens on the first account switched on. Editing that account shows "Pick this first when I add" as off, and the "Now it is X" line is hidden because X is this account.
- **How to trigger:** switch off "Pick this first" on the default account, then open Edit on the first account switched on.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** start with `_makeDefault = a.isDefault || firstPickAccount(enabled)?.id == a.id`, and treat it as unchanged when nothing was touched.
- **Found:** 23 November 2026, polish round stage 4 review

### [bug-review] Add (edit or copy) replaces what was typed if the entry loads late

- **Where:** `app/lib/features/add/add_screen.dart` (`_fillFrom` while `_filling`)
- **What happens:** while the entry is loading, the fields can be typed in; when it arrives, the loaded values replace what was typed.
- **How to trigger:** on a slow database, open Edit and type an amount before the form fills.
- **Score:** frequency 1 x severity 2 = 2
- **Suggested fix:** keep the form from taking input while `_filling` (`IgnorePointer`), or skip a field the person has already changed.
- **Found:** 23 November 2026, polish round stage 4 review

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

### [bug-review] Choose dates: preset range text goes stale across midnight

- **Where:** `app/lib/features/filters/choose_dates_screen.dart`, the range line under the presets (`_first` and `_last`)
- **What happens:** the dates shown under a preset are copied when the screen opens or a chip is tapped. The day count on the button and the applied range use today. If the screen stays open past midnight, the text can show yesterday's range while today's is applied.
- **How to trigger:** choose "Last 7 days", leave the screen open past midnight, then tap the button.
- **Score:** frequency 1 x severity 3 = 3
- **Suggested fix:** when not on Custom, work out the text in `build()` from `presetPeriod(_preset, today, calc)`.
- **Found:** 20 November 2026, Phase 5 review

### [bug-review] Filters: a very long typed amount silently becomes no limit

- **Where:** `app/lib/features/filters/filters_screen.dart`, `_parseAmount` (used by both amount fields)
- **What happens:** when the typed amount is too large for an int, parsing fails and that limit is dropped without a message.
- **How to trigger:** type 20 or more digits into "At least, UGX".
- **Score:** frequency 1 x severity 2 = 2
- **Suggested fix:** add `LengthLimitingTextInputFormatter(15)` to both amount fields.
- **Found:** 21 November 2026, Filters review

### [bug-review] All transactions: rows from a switched-off account show no account name

- **Where:** `app/lib/features/transactions/transactions_screen.dart`, the `accounts` name map (built from `enabledAccountsProvider`)
- **What happens:** an entry paid from an account that was later switched off shows a blank account name in its row, and a transfer to it shows no destination. Filters can now narrow the list to such an account, which makes these rows easy to reach.
- **How to trigger:** add an entry from Cash, switch Cash off in Settings > Accounts, open All transactions.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** build the name map from `allAccountsProvider`, as the Filters screen does.
- **Found:** 21 November 2026, Filters second review

### [bug-review] Reminders: cancelling all and rescheduling on every hide can drop them

- **Where:** `app/lib/services/notifications/reminder_scheduler.dart` (the reschedule on hide), `app/lib/services/notifications/notifications_service.dart` (`replaceAll`)
- **What happens:** each time Akatabo goes to the background, `replaceAll` cancels every pending notification and then schedules each one again. If the process is killed between the two steps, no reminders fire until Akatabo is next opened. It also re-plans when nothing changed.
- **How to trigger:** send the app to the background and have it killed within milliseconds (swiped from recents, or a memory kill).
- **Score:** frequency 1 x severity 4 = 4
- **Suggested fix:** keep the last applied plan and skip `replaceAll` when the new plan is the same; otherwise schedule the planned ids first, then cancel only ids no longer in the plan.
- **Found:** 20 November 2026, Phase 5 second check

### [bug-review] Add: a fee typed under "More details" is still saved after "Fewer details" hides it

- **Where:** `app/lib/features/add/add_screen.dart`, the "More details" section
- **What happens:** for an account that does not ask for the fee, a fee typed under "More details" stays in the entry after "Fewer details" folds the section away, so it is saved without being on screen. Tax already behaves this way.
- **How to trigger:** Add, Paid from Cash, More details, type a fee, tap Fewer details, save.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** keep the section open while it holds a fee or tax, or show the hidden amounts in the "More details" row ("Fee 500").
- **Found:** 20 November 2026, Phase 5 New account review

### [bug-review] Add: a cleared fee box moves away on a later rebuild

- **Where:** `app/lib/features/add/add_screen.dart`, the fee field's `onChanged` (sets `_feeTypedUpFront` without `setState`)
- **What happens:** after the person empties a fee carried over to an account that does not ask for a fee, nothing rebuilds at once. On the next rebuild from something else (a category tap, or the minute timer), the empty box jumps under "More details", or disappears if that section is closed, and focus goes with it.
- **How to trigger:** Money out on MTN MoMo, type a fee of 500, switch Paid from to Cash, clear the fee, tap a category.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** only ever set `_feeTypedUpFront = true` in `onChanged`; clear it when the account changes and the box is empty, inside that `setState`.
- **Found:** 20 November 2026, Phase 5 New account review

### [bug-review] PDF report: an emoji in a description prints as a box

- **Where:** `app/lib/services/export/pdf_report.dart` (fonts)
- **What happens:** the PDF embeds static Geist, which has no emoji, so an emoji in a description or note prints as an empty box.
- **How to trigger:** add an entry described "Lunch 🍲", export a PDF report.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** strip or replace characters Geist cannot draw before writing the PDF, or add a fallback font.
- **Found:** 20 November 2026, Phase 6 export builder

### [bug-review] Export: a hidden category's budget is still listed in the totals

- **Where:** `app/lib/services/export/export_report.dart` (category totals)
- **What happens:** a category hidden on Categories still appears with its budget in the exported category totals.
- **How to trigger:** set a budget on a category, hide it, export with "Category totals and budgets" ticked.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** leave hidden categories out unless they have entries in the period.
- **Found:** 20 November 2026, Phase 6 export builder

### [bug-review] Excel: a cell over 32,767 characters makes the file fail to open

- **Where:** `app/lib/services/export/xlsx_writer.dart`
- **What happens:** Excel refuses cells longer than 32,767 characters; a very long note would make the whole file report as damaged.
- **How to trigger:** paste a very long text into a note, export Excel with Notes ticked.
- **Score:** frequency 1 x severity 4 = 4
- **Suggested fix:** cut cell text at 32,767 characters with an ellipsis.
- **Found:** 20 November 2026, Phase 6 export builder

### [bug-review] Lock screen can say "0 more tries" before a wait

- **Where:** `app/lib/features/lock/lock_screen.dart` (wrong-PIN message)
- **What happens:** on the last free try the message can read "0 more tries before a wait" instead of saying the next wrong try starts a wait.
- **How to trigger:** with the lock on, enter a wrong PIN four times.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** word the last free try as "A wrong PIN now means a 30-second wait".
- **Found:** 20 November 2026, Phase 6 lock builder

### [bug-review] Fingerprint or face availability is checked once per run

- **Where:** `app/lib/services/security/biometrics.dart` (`biometricsAvailableProvider`)
- **What happens:** if the person adds or removes a fingerprint in phone settings while Akatabo is open, "Unlock with" is not shown or hidden until the app restarts.
- **How to trigger:** open Privacy and data, add a fingerprint in Android settings, return.
- **Score:** frequency 1 x severity 2 = 2
- **Suggested fix:** invalidate the provider when the app comes back to the foreground.
- **Found:** 20 November 2026, Phase 6 lock builder

### [bug-review] A protected weekly backup asks for the folder again after a restart

- **Where:** `app/lib/services/backup/weekly_backup.dart`, `app/lib/features/data/backup_weekly_prompt.dart`
- **What happens:** when the phone does not keep access to the chosen folder across restarts, each weekly backup asks for the folder as well as the password.
- **How to trigger:** turn on weekly backups with a password, restart the phone, open Akatabo a week later.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** keep a persisted folder permission (Android `takePersistableUriPermission`) where the dialog plugin allows it.
- **Found:** 20 November 2026, Phase 6 backup builder

### [bug-review] A double tap on "Save a backup file now" can open two dialogs

- **Where:** `app/lib/features/data/backup_actions.dart`, `backup_section.dart`, `data_section.dart`
- **What happens:** the button is disabled only once `onWorking` runs, after the password dialog closes; two quick taps before that open two dialogs.
- **How to trigger:** with "Protect with a password" on, tap Save a backup file now twice quickly.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** set the busy flag before the first await.
- **Found:** 20 November 2026, Phase 6 backup builder

### [bug-review] A double tap on the restore button can start the restore twice

- **Where:** `app/lib/features/data/restore_screen.dart` (`_restore`)
- **What happens:** for "Add what is missing" there is no dialog before `_busy` is set, so a very fast second tap can run a second restore; the merge is by id, so the second run adds nothing, but it shows two results.
- **How to trigger:** tap the restore button twice very quickly.
- **Score:** frequency 1 x severity 3 = 3
- **Suggested fix:** return at once from `_restore` while `_busy` is set.
- **Found:** 20 November 2026, Phase 6 backup builder

### [bug-review] Backup settings write errors are unhandled and leave the backup buttons stuck

**Fixed in Phase 8 (20 November 2026):** `setWeekly` and `setProtect` catch the write and say "That could not be changed"; both `_run` methods reset `_working` in a `finally`.

- **Where:** `app/lib/features/data/backup_actions.dart` (`setWeekly`, `setProtect`); called from `backup_section.dart` and `data_section.dart`
- **What happens:** the settings writes in `setWeekly` and `setProtect` have no try/catch and their callers are not awaited, so a failed write is an unhandled async error. If it fails after `onWorking` set `_working`, "Save a backup file now" stays on "Saving the backup…" until the screen is left.
- **How to trigger:** make the settings write fail (full disk, locked database), then switch on "Back up by itself every week" and pick a folder.
- **Score:** frequency 1 x severity 4 = 4
- **Suggested fix:** catch the writes, report them and return `BackupActions.failed`; in `_run`, reset `_working` in a `finally`.
- **Found:** 20 November 2026, Phase 6 checker

### [bug-review] A smart model file that fails to load hides its feature silently

- **Where:** `app/lib/features/add/category_suggestion_providers.dart`, `app/lib/features/transactions/unusual_providers.dart`, `app/lib/features/regular/regular_providers.dart` (the asset loaders; the forecast range keeps its constants in code)
- **What happens:** if a bundled JSON in `assets/smart/` cannot be read, the pill, the unusual card or "Looks regular" stay hidden, and nothing is reported.
- **How to trigger:** ship a build with a damaged or missing artefact.
- **Score:** frequency 1 x severity 3 = 3
- **Suggested fix:** report the load error through `FlutterError.reportError`, and add a test that every artefact in `assets/smart/` parses.
- **Found:** 20 November 2026, Phase 7 builders

### [bug-review] The category suggestion keeps a stale amount until the words change

- **Where:** `app/lib/features/add/category_suggestion_providers.dart`
- **What happens:** the suggestion is worked out from the words and the amount at the time; changing only the amount does not update it.
- **How to trigger:** type "Shell fuel", then change the amount from 5,000 to 60,000.
- **Score:** frequency 3 x severity 1 = 3
- **Suggested fix:** include the amount bucket in what the provider watches.
- **Found:** 20 November 2026, Phase 7 category builder

### [bug-review] The similar-payee scan grows with every payee, on each keystroke

- **Where:** `app/lib/smart/category/personal_layer.dart`
- **What happens:** each keystroke compares the words with every distinct payee the person has; with thousands of payees typing could lag.
- **How to trigger:** a few years of entries with many distinct descriptions.
- **Score:** frequency 1 x severity 2 = 2
- **Suggested fix:** index payees by token, or debounce the suggestion.
- **Found:** 20 November 2026, Phase 7 category builder

### [bug-review] Forecast point and range can round a .5 differently

- **Where:** `app/lib/domain/forecast.dart` (point) and `app/lib/smart/forecast/forecast_range.dart` (range)
- **What happens:** the point shown comes from `domain` and the range from `smart`; on a value ending in exactly .5 the two can differ by one shilling.
- **How to trigger:** rare; a daily rate that makes the point land on .5.
- **Score:** frequency 1 x severity 2 = 2
- **Suggested fix:** take the point from one place, or share one rounding helper.
- **Found:** 20 November 2026, Phase 7 forecast builder

### [bug-review] The xorshift bootstrap would break on the web

- **Where:** `app/lib/smart/forecast/forecast_range.dart`
- **What happens:** on the web Dart integers are JavaScript numbers, so the 32-bit xorshift gives different numbers. Android and iOS are fine; Akatabo has no web build.
- **How to trigger:** a web build.
- **Score:** frequency 1 x severity 3 = 3
- **Suggested fix:** mask with `& 0xFFFFFFFF` after every shift, or note that the app is mobile only.
- **Found:** 20 November 2026, Phase 7 forecast builder

### [bug-review] A failed read of past forecasts silently drops the range adjustment

- **Where:** `app/lib/data/repositories/forecast_snapshot_repository.dart`, `app/lib/features/forecast/forecast_providers.dart`
- **What happens:** if the snapshots cannot be read, the range is shown without the widening from past errors and nothing is reported.
- **How to trigger:** a database read error on the snapshots table.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** report the error; the range without the adjustment is still a fair fallback.
- **Found:** 20 November 2026, Phase 7 forecast builder

### [bug-review] Looks regular: a failed Add or Dismiss save is swallowed and the card stays hidden

**Fixed in Phase 8 (20 November 2026):** the save goes through `saveOrSay`, which reports it and tells the person; the card comes back.

- **Where:** `app/lib/features/regular/looks_regular_section.dart` (`_save`)
- **What happens:** the card is hidden before `addDetected` runs, and the returned Future is dropped. If the insert fails, nothing is saved, nothing is said, and the card stays hidden until the screen is reopened.
- **How to trigger:** make `addDetected` throw (database locked or full), then tap Add on a "Looks regular" card.
- **Score:** frequency 1 x severity 3 = 3
- **Suggested fix:** await the save in a try/catch, report the error, show the card again and say "Could not save. Try again."
- **Found:** 20 November 2026, Phase 7 checker

### [bug-review] "Only unusual" rescans the whole history for every entry on the UI thread

- **Where:** `app/lib/features/transactions/unusual_providers.dart` (`unusualIdsProvider`), `app/lib/smart/unusual/unusual_detector.dart`
- **What happens:** each money-out entry is scored against every earlier entry, including an edit-distance check per payee name, again on every database change while the filter is on. With a few thousand entries the list stalls visibly.
- **How to trigger:** about two years of daily entries, turn on "Only ones marked unusual", add an entry.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** keep running per-category and per-payee state as the loop goes, or cache results by id and score only new entries.
- **Found:** 20 November 2026, Phase 7 checker

### [bug-review] AkSegmented 44px minimum can drop a fitting proportional layout to an equal split

- **Where:** `app/lib/widgets/ak_controls.dart` (`_flexes`)
- **What happens:** every segment's measured width is raised to at least 44px before the fit test. With one long label beside short ones at a large text size, the raised total can exceed the room, so the control falls back to equal widths and the long label breaks onto two lines, though proportional widths would have fitted.
- **How to trigger:** a 360dp phone at a large text size, a segmented control with one long label and two or three very short ones ("All").
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** test `total > room` with the raw text widths; apply the 44px floor only when sharing out the flexes.
- **Found:** 20 November 2026, Phase 8 checker

### [bug-review] Load-error note hides the current period when only the comparison period failed

- **Where:** `app/lib/features/insights/insights_screen.dart`, `categories/categories_screen.dart`, `fees/fees_screen.dart`, `categories/category_detail_screen.dart`
- **What happens:** `ready` needs both the current and the previous period. If only the previous-period stream fails, the screen says "This could not load" though this period's figures loaded.
- **How to trigger:** make `previousSameDaysRowsProvider` (or Insights' previous period) throw while the current one succeeds.
- **Score:** frequency 1 x severity 3 = 3
- **Suggested fix:** when the current data loaded and only the comparison failed, show the current figures and drop the comparison line.
- **Found:** 20 November 2026, Phase 8 checker

### [bug-review] A secure-storage error hides every Privacy control

- **Where:** `app/lib/features/privacy/privacy_section.dart`
- **What happens:** if reading whether a PIN is set fails, the whole section becomes one note. Hide amounts and Blank the screen in the app switcher, which do not need the PIN, can no longer be changed, and "close and open again" does not help a broken keystore.
- **How to trigger:** make the PIN store's check throw (Android keystore failure after a device restore), then open Privacy and data.
- **Score:** frequency 1 x severity 4 = 4
- **Suggested fix:** show the note only in place of the lock rows and keep the other switches working.
- **Found:** 20 November 2026, Phase 8 checker

### [states-audit] Add shows its problems in one list above Save, not on each field

- **Where:** `app/lib/features/add/add_screen.dart` (problems list above Save)
- **What happens:** a missing amount, account or category is listed above Save, far from the amount field at the top of a long form. New account and Edit a category put errors on the field itself.
- **Score:** frequency 3 x severity 1 = 3
- **Suggested fix:** put the amount problem in the amount field's `errorText` and the category problem under the category grid; keep the list for problems that belong to no one field.
- **Found:** 20 November 2026, Phase 8 states audit

### [bug-review] update_tokens.py drops size tokens added directly to tokens.json

- **Where:** `tools/design/update_tokens.py` (the `data["size"]` rebuild, with the `SIZE_TOKENS` list)
- **What happens:** the script replaces the whole `size` group with its own list. `size-icon-add`, `size-chart` and `size-stroke` exist only in `design/tokens.json`, so running the script deletes them. The next `dart run tool/gen_tokens.dart` then removes `AkSize.iconAdd` and the app stops compiling.
- **How to trigger:** `python -I tools/design/update_tokens.py`, then `dart run tool/gen_tokens.dart` and `flutter analyze`.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** merge `SIZE_TOKENS` into the existing size tokens by name, as spacing and radius already do, or add the three missing tokens to `SIZE_TOKENS`. Since 21 November 2026 this also covers `size-pin-key`, `size-pinned-form-min` and `size-icon-lg`.
- **Found:** 20 November 2026, bug review of the plus-size change

### [bug-review] Add: hairline under the pinned header shows when the form is not scrolled

- **Where:** `app/lib/features/add/add_screen.dart` (the `ScrollUpdateNotification` listener)
- **What happens:** a long "What was it for" scrolls inside its own field and turns the line on; scrolling down under Money out and then tapping Move money shortens the list back to the top with no scroll event, so the line stays.
- **How to trigger:** type a description wider than the field, or scroll down then switch to Move money.
- **Score:** frequency 4 x severity 1 = 4
- **Suggested fix:** react only when `n.depth == 0`, and also listen for `ScrollMetricsNotification` so the line resets when the content shrinks.
- **Found:** 21 November 2026, bug review of the polish round

### [bug-review] Date dialog has no way to jump by year

- **Where:** `app/lib/widgets/ak_pickers.dart` (`AkDateDialog`), used by `features/data/export_section.dart`
- **What happens:** Export lets the first day go back to 2000, but the dialog steps one month per tap.
- **How to trigger:** in Export, choose a first day two years back.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** make the month label in `AkMonthGrid` open a year list, or show year steps when the range is longer than a year.
- **Found:** 21 November 2026, bug review of the polish round

### [bug-review] AkSegmented thumb is wrong right-to-left and asserts when very narrow

- **Where:** `app/lib/widgets/ak_controls.dart` (`AkSegmented`)
- **What happens:** right to left, the thumb sits under the mirrored segment; below 4px per gap the segment widths go negative and a `SizedBox` asserts.
- **How to trigger:** wrap it in `Directionality(textDirection: TextDirection.rtl)`, or lay three segments out in under 8px.
- **Score:** frequency 1 x severity 3 = 3
- **Suggested fix:** use `PositionedDirectional(start: …)` and clamp the free room at 0.
- **Found:** 21 November 2026, bug review of the polish round

### [bug-review] Forecast reads "UGX 0 more than came in" in the out colour when the gap is zero

- **Where:** `app/lib/features/forecast/forecast_screen.dart` (the gap line under the headline)
- **What happens:** when the forecast equals money in to the shilling, `gap >= 0` picks "more" and the bold out colour.
- **How to trigger:** a month where the forecast point equals money in, for example both zero.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** at `gap == 0` use `ink-muted`, normal weight, and say "about the same as came in".
- **Found:** 24 November 2026, bug review of the November plan's Phase 2

### [bug-review] Segment label shrink ignores the 44px floor of short labels

- **Where:** `app/lib/widgets/ak_controls.dart`, `AkSegmented._flexes`
- **What happens:** the shrink scale is worked out from the label widths alone. When a short label ("All") is held at 44px, the shrunk total is over the room and the control falls back to the even split, although a smaller scale (still 14/16 or more) would have fitted.
- **How to trigger:** one very short label beside long ones, on a narrow phone or at large text, so shrinking is needed.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** take the held segments' 44px out of the room, work out the scale for the rest, repeat once, then apply the floor.
- **Found:** 24 November 2026, bug review of the November plan's Phase 2

### [bug-review] App lock's "Wrong PIN tries" row goes stale while the page is open

- **Where:** `app/lib/features/lock/app_lock_screen.dart`, `pinTriesProvider` and the Wrong PIN tries row
- **What happens:** the wrong-try count and the wait are read once when the page opens, and again only after a PIN screen closes. A wait that ends while the page is open still shows "Waiting", and wrong tries made on the lock screen after "Lock now" (then a fingerprint unlock) are not counted until the page is reopened.
- **How to trigger:** lock on with fingerprint unlock; open App lock, tap Lock now, enter two wrong PINs, unlock with a fingerprint: the row still says "4 free".
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** have `pinTriesProvider` watch `lockControllerProvider`, so it reads again when the app opens; while a wait runs, a one-off timer for the time left refreshes it (cancelled in `ref.onDispose`).
- **Found:** 24 November 2026, bug review of the November plan's Phase 4

### [bug-review] Phone permissions reads ref after dispose if left during the first check

- **Where:** `app/lib/features/settings/permissions_screen.dart`, `_check`
- **What happens:** `_check` awaits `areAllowed()`, then calls `ref.read(phonePermissionsProvider)` before checking `mounted`. If the page was closed meanwhile, Riverpod throws, and the error is reported. The person sees nothing wrong.
- **How to trigger:** open Settings > Phone permissions and go back at once.
- **Score:** frequency 2 x severity 2 = 4
- **Suggested fix:** read both services before the first `await`, and check `mounted` between the awaits.
- **Found:** 24 November 2026, bug review of the permissions page

### [bug-review] "Never asked for" list misses some permissions, and the storage sentence is unconditional

- **Where:** `app/lib/services/permissions/phone_permissions.dart`, `sensitiveAccess`; `app/lib/features/settings/permissions_screen.dart`, the Never asked for text
- **What happens:** `sensitiveAccess` leaves out READ_MEDIA_VIDEO, READ_MEDIA_AUDIO, READ_MEDIA_VISUAL_USER_SELECTED, MANAGE_EXTERNAL_STORAGE, ACCESS_BACKGROUND_LOCATION, SEND_SMS, READ_PHONE_STATE, WRITE_CONTACTS and GET_ACCOUNTS. A future plugin adding one of them would leave a false "never asks for" claim. "So no storage permission is needed" shows whenever anything is listed. Today the manifest removals and `tool/check_permissions.ps1` prevent this.
- **How to trigger:** add a dependency that merges READ_MEDIA_VIDEO without a `tools:node="remove"` line.
- **Score:** frequency 1 x severity 4 = 4
- **Suggested fix:** add the missing permissions to each group; show the storage sentence only when "your files and photos" is in the list; add a unit test.
- **Found:** 24 November 2026, bug review of the permissions page

## Fixed

### [bug-review] Goal move sheet can call setState after it closes, or stay stuck on an unexpected error

- **Found:** 24 November 2026, goal screens bug review. Filed at 1 x 4 = 4, then rescored 2 x 5 = 10 in the second review because a stuck button blocks the main action.
- **Fixed:** 24 November 2026. `_save` returns early when the sheet is gone, and an `on Object` branch turns the button back on with "That could not be saved. Try again." Test: "the move sheet recovers from an unexpected error and lets the person retry" in `app/test/features/goals/goals_screens_test.dart`.

### [bug-review] Deleting an account that holds goal money fails with a misleading message

- **Found:** 24 November 2026, savings goals v5 bug review. Score 1 x 4 = 4.
- **Fixed:** 24 November 2026, with the goal repository. `AccountRepository.usedBy` counts goal moves as well as entries, `delete` refuses with a `StateError` while either exists, and the Settings dialog counts both (`goalMovesIn`). Tests in `app/test/data/goal_repository_test.dart`: "an account with money set aside in it cannot be deleted" and "an account with no entries and no goal money can still be deleted".

### [bug-review] Settings search tests do not check each keyword against its page

- **Found:** 24 November 2026, Settings search bug review. Score 2 x 2 = 4.
- **Fixed:** 24 November 2026. A table test in `app/test/features/settings/settings_search_test.dart` ("each hidden keyword finds exactly the pages that have that thing") lists a term and the pages it must find, such as password: App lock and Data and backup. Checked by changing the CSV keyword: the test failed, then passed once it was put back.

### [states-audit] Budgets' empty state has no button

- **Found:** 20 November 2026, Phase 8 TalkBack tree check. Score 2 x 2 = 4.
- **Fixed:** 21 November 2026. Empty Budgets lists each spending category with "Set a budget", opening that category's Set a budget screen (`test/features/budgets/budgets_test.dart`).

### [bug-review] A sync just after a reminder's time can push that reminder to the next period

- **Found:** 25 November 2026, goal reminders bug review. Score 1 x 3 = 3.
- **Where:** `app/lib/services/notifications/notifications_service.dart` (`replaceAll`) with `nextMonthlyAt` and `nextWeeklyAt` in `reminder_plan.dart`.
- **What happens:** reminders are scheduled inexactly, so the 1st 09:00 goal reminder can still be pending at 09:05. If Akatabo is opened or hidden then, `replaceAll` cancels it and the next time is a month away, so that month's reminder is lost. The daily and weekly reminders behave the same way.
- **Suggested fix:** in `replaceAll`, keep a reminder whose time passed in the last 15 minutes and has not fired, or show it at once.

### [bug-review] The Android "Reminders" channel description leaves out goal reminders

- **Found:** 25 November 2026, goal reminders bug review. Score 2 x 1 = 2.
- **Where:** `app/lib/services/notifications/notifications_service.dart`, the `reminders` channel.
- **What happens:** Android's notification settings for Akatabo describe Reminders as the daily nudge, regular payments and the weekly summary, but goal reminders go there too.
- **Suggested fix:** add goals to the description. Android updates an existing channel's description on the next start.

### [bug-review] Goal reminders were not set again after a goal changed

- **Found:** 25 November 2026, goal reminders bug review. Score 1 x 2 = 2.
- **Fixed:** 25 November 2026. `rescheduleRemindersAtStart` also listens to goals and goal moves, so a save, archive, put-back or move sets the reminders again. Test: "after start, saving a goal or giving it money sets the reminders again" in `app/test/services/goal_reminders_test.dart`.
