# Known bugs

Bugs scoring under 5 (frequency x severity, each 1 to 10) are filed here and left in the code until they are worth fixing. Bugs scoring 5 or more are fixed in the phase that found them.

## Open

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

## Fixed

### [states-audit] Budgets' empty state has no button

- **Found:** 20 November 2026, Phase 8 TalkBack tree check. Score 2 x 2 = 4.
- **Fixed:** 21 November 2026. Empty Budgets lists each spending category with "Set a budget", opening that category's Set a budget screen (`test/features/budgets/budgets_test.dart`).
