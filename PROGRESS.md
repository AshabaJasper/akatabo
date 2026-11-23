# Progress

## Phase 1: Foundation (19 November 2026)

- **Works:** tokens and the icon table generate the theme and icons, so the app never types its own colours; a light and dark five-tab shell with Add above the tabs; a drift database (schema v1) that creates the drawn default categories and accounts; typed settings; periods with a chosen month and week start; UGX formatting; a release APK that asks only for notifications and fingerprint.
- **Tested:** 73 tests pass and `flutter analyze` reports no issues. The tests cover: stored settings ready before the first frame; a screen-reader tap action on every nav control and the back link; nav labels kept inside their slots at twice the text size; the icon table with Windows line endings; calendar-day stepping on every day of 2026; generated files are up to date with the design files; every icon in the table is in the registry; no typed colours, sizes or radii in widgets; palette, corner and text-size rules; the database in memory on Windows (defaults, local day, payee key, corrections, transfers, CHECK and foreign-key refusals, period queries, settings fallbacks); period and money rules; shell navigation and tap-target guidelines; light and dark shell goldens. Release build, permission check and 16 KB alignment check pass. On the Android 16 emulator the debug build opens on Home with the bundled fonts, creates `akatabo.sqlite` in its private files folder, and logs no errors.
- **Not tested or not built yet:** every real screen (phase 2 on), the demo seed (moved to phase 2), iOS (no Mac), and a migration test (comes with schema v2).

### For a design check

1. Six dark tokens corrected to the values the dark screens use (`brand-deep`, `brand-bright`, `brand-text`, `switch-on`, `surface-raised`, `screen-deep`).
2. Tokens added for values the screens use but `tokens.json` lacked: type steps, spacing, `radius-xs`, colours, heat steps, past-period tints, a `size` section, five derived main colours. Each has a `note` in `tokens.json`.
3. 26 icons copied into the icon table from the screens; `grip` is drawn stroked, the screens fill it.
4. The active bottom-navigation item uses `brand-text`. The Layout rule says `brand`; the Dark theme rule gives links and marks to `brand-text`, and the dark screen draws `#8FD0B5`. Both are the same green in light.
5. Section eyebrows use `caption` weight 500 as the rule says; the screens draw 600.
6. A month that starts on, say, the 25th of October is named October. The design does not say.
7. Health uses the `medical` cross icon, as drawn.

### Bug review

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | Tabs and the Add disc had no screen-reader tap action | 4 x 6 = 24 | Fixed, tested |
| 2 | Back link had no screen-reader tap action (the placeholder Close button too) | 4 x 4 = 16 | Fixed, tested |
| 3 | Stored theme and periods flashed to defaults on cold start | 7 x 2 = 14 | Fixed: settings are read before the first frame. The new test also caught that Riverpod pauses an unlistened provider, which would have frozen the splash screen. Tested |
| 4 | Period steps used 24-hour durations, wrong in daylight-saving zones | 2 x 3 = 6 | Fixed with calendar-day steps, tested |
| 5 | Nav labels overflowed at large phone text size | 3 x 2 = 6 | Fixed: the label scales down to fit its slot, tested |
| 6 | Icon table did not parse with Windows line endings | 2 x 4 = 8 | Fixed, plus `.gitattributes`; tested |
| 7 | `formatShort` has no billions step | 2 x 2 = 4 | Filed in `docs/BUGS.md` |
| 8 | `PeriodCalculator` has no equality | 4 x 1 = 4 | Filed in `docs/BUGS.md` |

### Risks

- `flutter_file_dialog` applies the Kotlin Gradle Plugin; Flutter warns that a future version will fail to build with it. Watch for a plugin update or replace it before then.
- The release APK is signed with the debug key. This is a launch blocker until the owner provides an upload key.

## Phase 2: Core loop, part 1 (19 November 2026, not yet complete)

- **Works:** Add for money out, money in and move money, with fee, tax and a note under "More details", validation from the repository's own rules, and save-then-close; Home with the first-day three steps, or the filled month (totals, the split of money out by category, the latest three, and the comparison with the same days last month); All transactions grouped by day with each day's net, search by words or amount, a kind filter and the month's daily bars; One transaction with fee, tax and total cost, and a delete that asks first. Money rules live in `lib/domain/spending.dart`. Demo entries load only with `--dart-define=AKATABO_DEMO=true` into an empty database.
- **Tested:** 114 tests pass and `flutter analyze` reports no issues. Unit tests cover the money rules (transfers count only fee and tax, categories add back to the total, same-days sums, percentage change) and the amount field's cursor. Widget tests cover Add (validation, save, the time stamp taken at saving, a failed save, fee, money in, move money and its same-account check, semantics), Home (first day and a filled month), All transactions (grouping, search, filter) and One transaction (fee and total, delete confirmation). Shell goldens were regenerated because Home is now the first-day screen.
- **Not built or not tested yet:** Calendar with its five periods; Onboarding and Welcome; the "New" category tile on Add and the date and time picker behind "When" (it is fixed to now); the "Left in budgets" tile and the forecast card (phases 3 and 4); the category suggestion (phase 7); the Restore row on the first-day screen (phase 6); goldens for Add, Home, All transactions and One transaction; a side-by-side design check of each screen in both themes.

### For a design check (phase 2)

1. Move money has no drawn screen. Its layout is my reading of the money rules and the owner's decision.
2. The first-day card's dashed outline is drawn solid. Flutter has no built-in dashed border.
3. Home shows two of the three stat tiles (money in, fees and tax). "Left in budgets" waits for phase 4.
4. "When" on Add is fixed to the moment of saving; the design shows a time value that can be changed.
5. Money out includes fees and tax, so an entry of 45,000 with a 1,000 fee counts as 46,000. The design's sample day shows 53,000, the same entries without the fee. This is the kept difference from the design's "Rules for the numbers" section; it is flagged, not settled.

### Bug review (phase 2, part 1)

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | New entries were stamped with the time the app opened, because "now" was cached once Home watched it | 10 x 8 = 80 | Fixed: Add stamps `clock.now()` at saving; tested |
| 2 | Home and All transactions kept yesterday's "today" and last month's totals after midnight or the 1st | 6 x 4 = 24 | Fixed: "now" refreshes itself after local midnight and when the app returns to the foreground. The midnight timer is not tested directly; screens are tested with a fixed day |
| 3 | Add stayed on "Saving" with a dead button if the database refused the entry | 2 x 5 = 10 | Fixed: the error is reported, the entry is kept and a message asks to try again; tested |
| 4 | Editing the middle of an amount threw the cursor to the end | 4 x 3 = 12 | Fixed: the cursor keeps its place among the digits; tested for insert, a new comma and delete |
| 5 | All transactions and One transaction kept their database watches open after closing | 6 x 2 = 12 | Fixed: both providers auto-dispose |
| 6 | Home caption "1 to N" and the daily bars ignore "Month starts on" | 1 x 3 = 3 | Filed in `docs/BUGS.md` |

## Phase 2: Core loop, part 2 (19 November 2026, phase 2 complete)

- **Works:** Calendar with Day, Week, Month, Quarter and Year (the Month heat grid, bars for the others, Earlier and Later, a day card that opens that day's entries, the busiest week, and the year's highest, lowest and usual month); Onboarding (three steps, Skip, reduced motion) and Welcome, shown on a first launch only; the Home month pill opens Calendar; All transactions and Calendar link to each other without stacking. On emulator-5554 a fresh install opened on Onboarding, Skip then "Look around first" reached Home, and a cold restart opened Home.
- **Tested:** 170 tests pass and `flutter analyze` reports no issues. Unit tests cover heat steps (they reproduce the drawn November), day, hour, week and month marks, quarter weeks adding back to the quarter, "Month starts on" 25, the year summary and the midnight refresh of "now" (with `fake_async`). Widget tests cover each Calendar period, stepping, the disabled Later, zero days, loading without false zeros, hours added since the app opened, Onboarding and Welcome paths, the stored flag at start-up, 44px labelled targets, the Home status bar, and goldens in both themes for Calendar, Onboarding, Welcome, Home, Add, All transactions and One transaction.
- **Not tested:** the new Home month-pill ripple on a device (the build on the emulator predates it); TalkBack; text scale 1.3 and 2.0 (phase 8); a side-by-side design render of each screen.

### For a design check (phase 2, part 2)

1. Onboarding steps 2 and 3, and Calendar Day, Week, Quarter and Year, have no drawn screens; they are built from the rules. A `size-chart` token (160px) was added for their bars.
2. The Onboarding headline uses `figure-lg` 34/38 where the drawing has 36/40, and the content is centred rather than held in a fixed 340px area.
3. Welcome's third line says "nothing uploaded" instead of "no permissions", because reminders and fingerprint unlock each ask for one when switched on.
4. Welcome's outlined button uses `on-brand-muted` for the drawn #7FA596.
5. The selected Calendar day's 2px outline is drawn inside the cell; future bars are dashed outlines at 25% height; past days with nothing spent show no "0" (the spoken label still says UGX 0).
6. Calendar heat steps are rank-based within the month, which matches the drawn November exactly.
7. Add's three kind segments have no icons, because with icons the labels wrapped.
8. The tap-target floor is 44px (the design system's), so tests use the iOS guideline rather than Android's 48dp.

### Bug review (phase 2, part 2)

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | All transactions opened from Calendar said "Home" on its back link, and its Calendar pill stacked a second Calendar | 5 x 3 = 15 | Fixed: a `from=calendar` route; back says Calendar and the pill returns; tested |
| 2 | Each Earlier, Later or period switch flashed "UGX 0 out" and "Nothing spent" while the period loaded | 9 x 2 = 18 | Fixed: no figures until rows arrive, an error message if they fail; tested, and the test fails on the old code |
| 3 | Day view marked hours since the app opened as "not yet", even with entries in them | 4 x 3 = 12 | Fixed: the hours use the time now, and an hour with an entry is never "not yet"; tested, fails on the old code |
| 4 | "See that day" briefly said "Nothing added on this day." while loading | 6 x 2 = 12 | Fixed: no message until entries load; tested |
| 5 | The Home month pill showed no ripple, because it was drawn under the green header | 9 x 1 = 9 | Fixed: a transparent Material under the ink; not checked on a device |
| 6 | A returning person saw Onboarding again if settings took over 3 seconds at start-up | 2 x 3 = 6 | Fixed: the flag is read directly from the database before the first frame; tested |
| 7 | Quarter labels ignore "Month starts on" | 1 x 2 = 2 | Filed in `docs/BUGS.md` |
| 8 | Day and Week titles have no year | 2 x 2 = 4 | Filed |
| 9 | `Reveal` makes a `CurvedAnimation` per build | 2 x 1 = 2 | Filed |
| 10 | Double-tapping Skip opens Welcome twice | 2 x 1 = 2 | Filed |

## Phase 3: Understanding (19 November 2026)

- **Works:** Insights (Week, Month, 3 months and Year; spent so far with the same days before drawn as a dashed line; cash flow; the three biggest changes; links onward); Categories and the one category page (share bars, change on last month, week by week, what it went on); Fees and tax (sending, withdrawing and tax, by account); Forecast (gated until seven days this month have entries; point, range, the running total with the forecast and band drawn beyond today, and how it adds up); Regular payments, added by hand, listed with their dues this month and later, and removable after a confirmation. All are reached from Insights, which is now a real tab.
- **Tested:** 234 tests pass and `flutter analyze` reports no issues. Unit tests cover the forecast rule, the 7-day gate, the rate window and short history, one-offs (per category, pooled for thin categories, and a spread floor when most amounts are equal), regular dues by calendar month and year, a due today counted once, the rate without a regular payment's entries, today's spending still to come, the drawn 96,000, and the fee split summing to its total. Widget tests cover the empty and filled state of each screen, the forecast gate message, removing with confirmation, adding with validation, a cash-out to a switched-off Cash account, and painter goldens for Forecast (light and dark) and Insights.
- **Not tested:** the new screens on the emulator or a device; tapping a Biggest-changes row (it uses go_router, which the widget tests do not mount); the forecast against real months of the owner's data; TalkBack and large text (phase 8); a side-by-side design render.

### For a design check (phase 3)

1. Insights has no Earlier and Later stepping; Categories shows the current month only.
2. The forecast's everyday line now reads "Everyday, rest of today and 11 more days", because the rest of today is counted (see the bug table). The drawn screen says "Everyday, 11 days".
3. A new `size-stroke` token (2px) for the Insights legend line.
4. Regular payments show "You added these by hand." under the total, because detection from entries is not built yet.
5. Not built yet: Edit a category, the budget row, "See all", the six-month stacked fee chart, "How close it has been", the remind toggle, the bubble timeline, and the heat strip on Categories.

### Bug review (phase 3)

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | "Monthly" stepped 30 days, so a bill due on the 1st also fell on 31 December and was counted twice | 7 x 6 = 42 | Fixed: Monthly and Yearly step by calendar month and year, clamped to the month's length; tested |
| 2 | A regular payment's own entries stayed in the daily rate and were added again as "Regular bills due" | 6 x 6 = 36 | Fixed: entries to a regular payment's payee are left out of the rate; tested |
| 3 | A payment due today was dropped from the forecast and the list | 6 x 5 = 30 | Fixed: dues count from today, unless an entry for it was already made today; tested both ways |
| 4 | A morning forecast left out today's spending still to come | 9 x 3 = 27 | Fixed: the rest of today (the rate less today's spending, never below 0) is added; tested |
| 5 | The Fees and tax row under Biggest changes opened an empty category page | 6 x 4 = 24 | Fixed: it opens Fees and tax, as Categories does; not covered by a widget test |
| 6 | When most amounts in a category were equal, a slightly larger one counted as a one-off | 5 x 4 = 20 | Fixed: the spread is never less than a quarter of Q3; tested, and a school payment among equal amounts is still caught |
| 7 | "Tax on withdrawals" had the detail "On money out and withdrawals" | 7 x 2 = 14 | Fixed: the detail matches the title; tested |
| 8 | The regular amount field kept "46000.50" as 4,600,050 | 2 x 7 = 14 | Fixed: the same formatter and parser as Add |
| 9 | A `height: 2` literal in the Insights legend | 10 x 1 = 10 | Fixed: the `size-stroke` token |
| 10 | Fees to a switched-off Cash account showed as "Sending money" | 2 x 3 = 6 | Fixed: Fees reads every account; tested |
| 11 | A yearly payment due more than 400 days after month end is not listed | 1 x 4 = 4 | Filed in `docs/BUGS.md` |

## Phase 4: Planning (19 November 2026)

- **Works:** Budgets (left to spend this month, the daily allowance for the days left or "Left for today" on the last day, a bar with a pace tick, every budget with its status in words, and categories with spending but no budget offered "Set one"); Set a budget (amount, a suggestion from the last six months with how many months it would have covered, history bars with the current budget as a dashed line, carry-over, warn level 60, 70, 80 or 90, save and remove with a confirmation). Carry-over adds last month's unspent part once the budget has covered a whole month. Fees and tax cannot be budgeted.
- **Tested:** 294 tests pass and `flutter analyze` reports no issues. Unit tests cover pace, all four statuses at their boundaries (exactly at the budget, one shilling over, exactly at the warn level, one below, exactly on pace, one above), the daily allowance rounded down to the hundred and on the last day, the net overall figure, carry-over and when it applies, the suggestion (five of six months, three-month minimum, latest six only) and money out per month. The schema 1 to 2 migration is tested with drift's generated tests, and the repository test checks when `budgetSince` starts, stays and clears. Widget tests cover the drawn figures, the statuses, the unbudgeted offer, a month starting on the 25th, carry-over before and after a full month, the last day, database errors on both screens, save, validation, remove and a failed remove; goldens in light and dark.
- **Not tested:** the screens on the emulator or a device (the emulator was not running); tapping "Set one" or a budget row through go_router; TalkBack and large text (phase 8); a side-by-side design render; carry-over across a change of "Month starts on".

### For a design check (phase 4)

1. "Left for today" replaces "A day, for N days" on the last day of the month; not drawn.
2. Error states on both screens ("Budgets could not load. Close Akatabo and open it again."); not drawn.
3. The pace tick on the budget bar uses the `size-stroke` token (2px) in ink.
4. Section labels stay as eyebrows, as the design system draws them.
5. The suggestion note when there is too little history ("A suggestion appears after three months with spending in ..."); not drawn.

### Bug review (phase 4)

The five fixed bugs were re-scored when this was written, because the first scores were lost when the session's context was summarised.

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | Pace and status used the calendar day, wrong when "Month starts on" is not the 1st | 3 x 4 = 12 | Fixed: the day of the budget month (`elapsedDays`); tested with a month starting on the 25th |
| 2 | Carry-over added last month's unspent part even when the budget was set this month | 4 x 4 = 16 | Fixed: a `budgetSince` column (schema v2); carry applies only once the budget covered a whole month; tested in domain, repository and widget tests |
| 3 | On the last day the summary read "A day, for 0 days" | 3 x 2 = 6 | Fixed: "Left for today", in the text and the screen-reader label; tested |
| 4 | A database error left both screens loading forever | 1 x 6 = 6 | Fixed: an error message; tested with a failing stream on each screen |
| 5 | A failed "Remove budget" threw with no message | 1 x 5 = 5 | Fixed: "The budget could not be removed. Try again."; tested |
| 6 | Rows sorted by ratio can put "A little ahead" above "Nearly used" | 2 x 2 = 4 | Filed in `docs/BUGS.md` |

## Phase 5: Customising (partly built, 19 November 2026)

- **Works:** the Settings tab lists the drawn pages. General (month and week start, new entry as money out or in; a month start of the 25th changes the periods the app reads), Appearance (theme, text size and corners, read back and applied to the theme), Accounts (switch an account off and it stops being offered on Add), Home screen (switch the header figures, "Where it went" and "Latest" off; Home redraws). Each change saves at once.
- **Tested:** 313 tests pass and `flutter analyze` reports no issues. Tests cover each setting's effect at the provider or database level, the General and Appearance pages' saves, a long value at 2x text scale without overflow, and a switched-off Latest section on Home.
- **Not built, and not tested:** Categories, Smart help, Reminders (the notifications plugin is in pubspec but no reminder is scheduled), Edit a category, New account, Money-in categories, Filters, Choose dates and the pickers. Privacy and security and Data and backup belong to Phase 6 and still open placeholders. Main colour is not changeable. Home's forecast and budgets cards do not exist on Home yet, so there are no switches for them.

### Bug review (phase 5)

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | A long settings value (e.g. Currency at 2x text) overflowed its row instead of wrapping | 4 x 3 = 12 | Fixed: the value area is capped at half the width; tested at 320 wide with 2x text |
| 2 | The "damaged stored value" test never stored a damaged value | 2 x 2 = 4 | Filed in `docs/BUGS.md` |

### For a design check (phase 5)

1. The Home screen page offers three switches; the drawn page also lists the forecast card and "Budgets at a glance", which Home does not show yet.
2. The Settings hub rows and the Accounts and Home pages use the drawn labels; the switch rows have no icons.

### Phase 5, second pass (20 November 2026)

- **Works:** New account (name and kind, refuses an empty name, saves once even if Done and Save both fire; the account appears on Accounts and Add). Categories (show or hide each spending and money-in category on Add; Fees and tax is never listed). Switch rows on Accounts, Home screen and Categories now show their label: `AkSwitch` draws only the switch, so a shared labelled row was added.
- **Tested:** 321 tests pass and `flutter analyze` reports no issues. New tests cover adding an account (trimmed name, kind, colour, empty name refused), the form's validation and save, a double Done saving one account, the name message clearing on typing, hiding a category removing it from the list Add reads, and the Categories page saving a switch and leaving out Fees and tax.
- **Not built, and not tested:** Smart help, Reminders, Edit a category (names, icons, colours, order), Filters, Choose dates and the pickers. Nothing was checked on a device.

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | Done on the keyboard and Save could create two accounts | 3 x 4 = 12 | Fixed: one save at a time; tested |
| 2 | "Give the account a name." stayed after typing a name | 3 x 2 = 6 | Fixed: cleared on typing; tested |
| 3 | A save failure message showed twice, once under Name | 2 x 2 = 4 | Filed in `docs/BUGS.md` |
| 4 | Kind labels may break mid-word at 360dp | 4 x 1 = 4 | Filed |
| 5 | New account opened as the first route does not close after saving | 1 x 3 = 3 | Filed |

### Phase 5, third pass (20 November 2026)

- **Works:** renaming a category. Each row on Settings > Categories has a "Rename" link that opens Rename category; the name is trimmed, an empty name is refused, a second tap while saving is ignored, and the new name shows everywhere the category appears.
- **Tested:** 324 tests pass and `flutter analyze` reports no issues. New tests cover the repository rename (trimmed, empty refused) and the screen (empty name refused, new name saved to the database).
- **Not built, and not tested:** category icon, colour and order; Smart help, Reminders, Filters, Choose dates and the pickers. Not tested: that the screen closes after saving, and that each Rename link opens its own category. Nothing was checked on a device.

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | A category can be renamed to a name another category already uses | 2 x 2 = 4 | Filed in `docs/BUGS.md` |
| 2 | "Rename" links do not say which category they rename to screen readers | 2 x 2 = 4 | Filed |

### Phase 5, fourth pass (20 November 2026)

- **Works:** Choose dates at `/filters/dates`: six presets (Last 7 days, This month, Last month, Last 3 months, This year, Custom), a custom range on a month grid with previous and next months, and a button that names the length ("Show these 15 days", "Show this day"). The choice is held in memory; a preset's dates are worked out when read, so they follow today and "Month starts on".
- **Tested:** 345 tests pass and `flutter analyze` reports no issues. New tests cover every preset's dates on 19 November 2026, the custom tap rule (including 10 to 15 November from 1 to 30 November), a range ending before it starts being refused, the choice surviving a settings change while "This month" follows the new month start, and the screen picking a custom range, applying a preset and opening on the range already chosen.
- **Not built, and not tested:** Filters, so nothing links to Choose dates yet and no screen reads the chosen range; Smart help, Reminders, the pickers. **Design check:** the custom tap rule and its hint differ from the drawn screen (see the PLAN.md decision log). Nothing was checked on a device.

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | The start of a custom range could never move later (the drawn tap rule) | 7 x 5 = 35 | Fixed: a tap on a longer range starts a new one; tested |
| 2 | Saving any setting, or midnight, reset the chosen dates to This month | 4 x 4 = 16 | Fixed: only the choice is held; dates worked out when read; tested |
| 3 | A preset's range text can go stale if the screen stays open past midnight | 1 x 3 = 3 | Filed in `docs/BUGS.md` |

### Phase 5, fifth pass: Filters (21 November 2026)

- **Works:** Filters at `/filters`, opened from a "Filters" pill on All transactions that reads "Filters on" while anything narrows the list. Categories, Paid from (every account), an amount range in UGX, Dates (opens Choose dates, now with an "All dates" chip), Only ones with a fee, Only ones marked unusual, and Newest, Largest or Oldest order. The button counts the matching entries; Clear all resets the choices and dates. Search and direction moved into the same filter, so the count and the list always agree.
- **Tested:** 376 tests pass and `flutter analyze` reports no issues. New tests cover each filter rule and their combination, search and direction, the order rules, the day view ignoring Filters, the screen's count, toggles, amounts, an out-of-order amount pair, a switched-off account's chip, Clear all, All dates on Choose dates, the search box following a search changed elsewhere, and the day heading under Largest. The All transactions goldens were regenerated with the Filters pill and checked by eye.
- **Not built, and not tested:** Smart help, Reminders, the pickers, Money-in categories, category icon, colour and order. Filters are not saved across app restarts (by design). Nothing was checked on a device.

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | The Filters count ignored the search words and direction, so it could disagree with the list | 6 x 5 = 30 | Fixed: one rule for both; tested |
| 2 | The day view applied the global Filters and dates | 4 x 5 = 20 | Fixed: the day view uses only its own search and direction; tested |
| 3 | The search box could show old words after the day view changed the search | 3 x 4 = 12 | Fixed: the box follows the filter; tested |
| 4 | No way back to "all dates" once a range was chosen | 4 x 3 = 12 | Fixed: "All dates" chip on Choose dates; tested |
| 5 | A lowest amount above the highest silently emptied the list | 3 x 3 = 9 | Fixed: no limit applies, explained, Show disabled; tested |
| 6 | The day view lost its day heading when the order was Largest | 2 x 3 = 6 | Fixed: the day view is always newest first by day; tested |
| 7 | A very long typed amount silently becomes no limit | 1 x 2 = 2 | Filed in `docs/BUGS.md` |
| 8 | Rows from a switched-off account show no account name | 2 x 2 = 4 | Filed |

### Phase 5, sixth pass: parallel builders and two checks (20 November 2026)

Four builders worked in separate git worktrees (Smart help and Reminders, the pickers, Money-in categories, Edit a category); a checker reviewed the merged result twice, and each finding went back to a builder or was fixed here.

- **Works:** Smart help and Reminders settings, with reminders scheduled at a local time and rescheduled on open and on hide, and a budget warning after saving an entry. Themed date, time and choice pickers on Add, General and Smart help. Money-in categories on their own screen. Edit a category: name, icon, colour, budget, delete, and order by dragging, a grip menu or screen-reader actions; New category for both kinds; Edit from a category's own page. Appearance gained Main colour and Category chart. A hidden category says so under its name, and each Main colour disc has a visible edge in dark.
- **Tested:** 541 tests passed after the second round's merges, with `flutter analyze` clean. New tests cover notification permission asked only when a reminder is switched on, the reminder plan, the budget warning lines, duplicate names refused inside a transaction, delete closing both pages, the theme rebuilding when Appearance changes, and contrast of every main colour in both themes. Goldens for Smart help, Categories, Edit a category and Appearance were checked by eye.
- **Not tested:** nothing ran on a device or emulator, so notifications were never seen firing and the release build stays BLOCKED (Windows Smart App Control stops Flutter's `gen_snapshot.exe`). **Design checks** are in the PLAN.md log, including the deferred Category colours, "The app opens on", Date style and amount style.

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | The notification small icon was the full-colour launcher icon (shows as a white square) | 10 x 2 = 20 | Fixed: monochrome vector, kept from shrinking |
| 2 | Value rows wrapped onto two lines, with uneven side padding | 10 x 2 = 20 | Fixed: one shared row padding; tested |
| 3 | Category tile icons lost contrast in dark | 6 x 2 = 12 | Fixed: icon colour per theme; tested |
| 4 | Hidden category had no "Hidden" line | 7 x 1 = 7 | Fixed; tested |
| 5 | Deleting from a category's own page left that page open on a deleted category | 3 x 2 = 6 | Fixed: both pages close; tested |
| 6 | Dark Main colour discs under 3:1 against the card | 3 x 2 = 6 | Fixed: 1px edge; contrast test |
| 7 | Cancelling and rescheduling every reminder on hide can drop them if the app is killed between | 1 x 4 = 4 | Filed in `docs/BUGS.md` |

### Phase 5, seventh pass: New account and the default account (20 November 2026)

- **Works:** New account as drawn (name, kind, colour, what is in it today, ask for the fee, pick this first, count it in my totals), each changing behaviour: Add opens on the account picked first and puts the fee box in the form only for accounts that ask; General can change the account picked first; Settings > Accounts shows each account's balance and a Total of the counted ones; tapping an account says what is in it now, and the default accounts read "Not set" until then. Existing installs get the fee setting on the default accounts through a data-only schema v3 step.
- **Tested:** 581 tests pass (exit code 0) and `flutter analyze` reports no issues. New tests cover saving every New account field, only one account picked first, the fallback when it is switched off, the fee box placement, the balance arithmetic (opening amount, money in and out with fee and tax, moves, uncounted accounts still counting in money out), the Kind labels staying on one line at 360dp, a balance counting only entries dated from when it was set, an unset account staying out of the Total, setting a balance from Accounts, and the v2 to v3 step. The fee step and the date rule were each checked by breaking them on purpose. New account goldens checked by eye.
- **Not tested:** nothing on a device; no goldens for the Accounts balance section or General. **Design checks:** "Count it in my totals" applies to balances only, and the balance section is not drawn.

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | The default accounts showed a made-up balance (from 0, usually negative) that no screen could correct | 8 x 6 = 48 | Fixed: balance unset until said, settable from Accounts; tested |
| 2 | An entry dated before an account's balance was set was counted twice | 4 x 6 = 24 | Fixed: only entries from that moment count; tested |
| 3 | Existing installs kept "ask for the fee" off on MTN, Airtel and Bank | 2 x 4 = 8 | Fixed: schema v3 step; tested |
| 4 | On General, picking the fallback account saved nothing | 2 x 3 = 6 | Fixed by the builder; tested |
| 5 | A cleared fee box moves away on a later rebuild | 2 x 2 = 4 | Filed in `docs/BUGS.md` |
| 6 | A fee hidden by "Fewer details" is still saved | 2 x 2 = 4 | Filed |
| 7 | The "Not counted" note could name an account not listed | 1 x 1 = 1 | Fixed with bug 1: the note names only listed accounts |

## Phase 6: Keeping data safe (20 November 2026)

- **Works:** PIN lock (4 digits, PBKDF2, growing waits) with fingerprint or face, Lock after, Hide amounts and Blank in the app switcher; Change PIN; Forgot PIN and Delete everything both wipe the phone and remove the PIN. Export to CSV, Excel and PDF for this month, this year, all or a custom range. Backup file with an optional password (Argon2id), weekly backup to a chosen folder, restore with a preview, "Add what is missing" or "Replace everything". About shows the version and the open-source licences, including both fonts' OFL texts.
- **Tested:** 798 tests pass (exit code 0) and `flutter analyze` reports no issues. New tests cover the backup round trip with and without a password, wrong password, damaged and newer files, merge counts, restore all-or-nothing, phone-only settings kept, a new phone taking the backup's edited defaults, the PIN wait schedule and boot-clock timing, the lock overlay, hidden amounts, CSV formula escaping, the Excel and PDF writers, the segmented control widths, Delete everything removing the PIN, dialogs not locking the app, the password step never falling back to an unprotected file, and About. The four checker fixes were each confirmed by breaking them on purpose. Export, Privacy and data, lock and restore goldens checked by eye.
- **Not tested:** nothing on a device or the emulator (no fingerprint prompt, file dialog or share sheet run for real); the Excel file was not reopened with a Python reader; key-derivation timing not measured on a phone; iOS not built. **Launch blockers:** "Privacy policy" and "Send feedback" on About need the owner's policy and contact. **Design checks:** PIN screens, restore steps 1 and 3, the password entry and every Phase 6 dialog are not drawn.

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | Export hung when the save dialog was cancelled | 80 | Fixed by the export builder; tested |
| 2 | Restoring onto a new phone kept the blank defaults over the backup's balances and budgets | 6 x 8 = 48 | Fixed: untouched phone defaults give way; tested |
| 3 | Export text contrast in dark | 32 | Fixed by the export builder; tested |
| 4 | Insights figures shown with Hide amounts on; PIN hashing froze the screen | 20 each | Fixed by the lock builder; tested |
| 5 | Weekly backup prompt (15), date moved back or forward around the PIN wait (14, 14) | 14 to 15 | Fixed by the builders; tested |
| 6 | Backup file size limit, iPad share origin, Face ID text, focus | 10 each | Fixed by the builders; tested |
| 7 | System file dialogs locked the app with "Right away" | 3 x 3 = 9 | Fixed: dialogs kept unlocked; tested |
| 8 | Back button, iOS blank, picker error, protected-backup password step fail-open | 7 to 9 | Fixed; the password step by the lead, tested |
| 9 | Reshow, label, zip bomb, key cost | 5 to 6 | Fixed by the builders; tested |
| 10 | Emoji in the PDF; hidden category budget exported; Excel cell over 32,767; "0 more tries"; protected weekly backup asks for the folder; double tap on Save now; settings write errors | 4 each | Filed in `docs/BUGS.md` |
| 11 | Double-tap restore (3); biometrics checked once per run (2) | 2 to 3 | Filed |

## Phase 7: The four models (20 November 2026)

- **Works:** category suggestion on Add (a pill with "% sure", shown at 70% or more once the person has 5 entries of their own; the suggested tile is preselected and a different pick is saved as a correction); unusual payments on One transaction with "This was me" saved on the entry, and the "Only unusual" filter; "Looks regular" on Regular payments with Add and Dismiss; the month-end range on Home and Forecast ("Likely 150k to 200k, most likely 175k"), widened by the person's own past forecast errors, with the first forecast each day saved. Every model is pure Dart from a JSON file in `assets/smart/`, with a Python reference in `ml/`; each follows its Smart help switch.
- **Tested:** 906 Flutter tests and 59 pytest pass (exit code 0) and `flutter analyze` reports no issues. Dart reproduces Python exactly in every parity test (largest difference 4.4e-16). New tests cover a correction changing the next suggestion, the pill, the unusual card and filter, "This was me" being saved without touching `updatedAt`, the switch turning the filter off, "Looks regular", the range on Home and Forecast, the fixed random numbers, and the month turn. Each builder and each checker fix was confirmed by breaking it on purpose. All results are SYNTHETIC (see `ml/README.md`): the category model alone barely beats simple baselines on unseen merchants (26.3% against 25.2%) and becomes useful through the person's corrections (88.2% after 10); unusual at Balanced 0.50 precision and 0.43 recall; regular payments 6 of 6 series; the range covers 74.6% against an 80% target.
- **Not tested:** nothing on a device or the emulator; no real data, so no real-world accuracy; no dark golden for the pill. **Design checks:** the pill row height, the unusual card, "Looks regular" and the range sentence are not drawn; the Home card's wording repeats the point figure.

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | On the 1st, the forecast could be worked out from last month's rows and saved as the day's snapshot | 5 x 4 = 20 | Fixed: current month only, waits for reloads; tested |
| 2 | The category grid jumped as the pill came and went | 6 x 2 = 12 | Fixed by the builder; tested |
| 3 | "Only unusual" always showed nothing (read a flag nothing writes) | found by the lead | Fixed: uses the detector; tested |
| 4 | Home forecast card read twice by screen readers, with dots read out | 3 x 2 = 6 | Fixed by the builder; tested |
| 5 | "Only unusual" ignored the Smart help switch | 2 x 3 = 6 | Fixed; tested |
| 6 | "This was me" made an old category look newest to the suggester | 2 x 3 = 6 | Fixed: `updatedAt` untouched; tested |
| 7 | Looks regular: double Add saved twice (6); a bill added under another name offered again (6) | 6 each | Fixed by the builder; tested |
| 8 | Failed snapshot read silent; Only unusual slow on long histories; stale amount in the suggestion | 3 to 4 | Filed in `docs/BUGS.md` |
| 9 | Model load failure silent; failed Looks regular save swallowed; xorshift on the web; .5 rounding; payee scan | 2 to 3 | Filed |

## Phase 8: Finish (20 November 2026)

- **Works:** every screen states what happens when its data cannot load or a save fails; 32 screens fit at text size 2.0 with 44 x 44 targets and named controls in both themes; still page transitions under reduced motion (iOS keeps swipe-back); a provisional icon; an obfuscated, R8-shrunk release APK (66.4 MB, three ABIs) holding only notifications and biometrics permissions, 16 KB aligned.
- **Tested:** `flutter analyze` clean; `flutter test` 1,053 passing (new: accessibility sweep, failure states, field names, still transitions, first-day steps, unreadable backup setting); the journey test (PIN unlock, onboarding, three entries, a budget, back up, delete everything, restore) passes on the Android 16 emulator; the release APK's accessibility tree read on six screens, which found and fixed the unnamed amount field.
- **Not tested:** a live TalkBack listen-through (spoken words, focus order) and a re-check of the amount-field fix on the device; keyboard and Switch Access; a low-end phone; anything on iOS; an AAB build; a static security scan. Launch blockers needing the owner are listed at the top of `SHIP_GATE.md`.

## Settings hub and empty states (20 November 2026)

- **Works:** the Settings tab is built to `Settings.html`: three grouped cards, a 36px tile per page (icon in `brandText`, which reads in dark), a chevron, and "Akatabo <version>. Free, with no account and no adverts." Empty Budgets offers "Choose a category" (Categories' back link then names Budgets); empty Insights and Categories offer "Add a transaction".
- **Tested:** `flutter analyze` clean; `flutter test` 1,057 passing (new: hub cards, tiles and chevrons, dark icon colour, version footer, Budgets action and its back link). Settings seen on the Pixel 8 Pro in dark. Bug review found 2 (dark icon contrast 18, wrong back label 10); both fixed with tests.
- **Not tested:** the empty-state links on the device; Settings in light on the device; Transactions, Regular payments and Fees empty states still have no action.

## Polish round (21 November 2026)

- **Works:** an own date dialog on the shared month grid (no font-icon boxes), the time typed in; the PIN keypad balanced on tall phones with keys up to 84px; Add keeps the kind and amount pinned while the form scrolls, and keeps focus as the keyboard moves the amount; Move money always asks for the fee; segmented controls slide their thumb (still under reduced motion); Calendar says "3 months". Home's first day, empty Budgets and five empty notes now offer the next step. App lock has its own page from the Settings hub.
- **Tested:** `flutter analyze` clean; `flutter test` 1,069 passing (new: no font icon in either dialog, faded future days, sticky amount, focus kept across the keyboard, fee on Move money, first-day rows and back links, Budgets category list and route, App lock's Set a PIN, a leftover PIN, the loading guard). Goldens regenerated on purpose and named in each commit. Two bug reviews: 7 fixed with tests (focus lost when the keyboard moved the amount 40, three wrong back labels, the PIN loading race 7, a leftover PIN 6, the week start in the regular payment date 6); 3 filed.
- **Not tested:** any of this on the Pixel 8 Pro or the emulator yet, light or dark; the journey test was not rerun. Stage 4 of the round (the drawn pieces still missing) is not started: see `docs/HANDOFF.md`.

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | The keyboard moving the amount rebuilt the field, losing and grabbing focus | 8 x 5 = 40 | Fixed with a `GlobalKey`; tested |
| 2 | Back links said Settings or Coming up when opened from Privacy and data or Home | 10 and 8 | Fixed; tested |
| 3 | While the PIN check loaded, App lock offered Set a PIN (replacing a stored PIN unasked) and showed Off | 7 and 6 | Fixed: rows wait; tested |
| 4 | A PIN left behind with the lock off showed Change PIN and asked for it | 6 | Fixed: Set a PIN replaces it; tested |
| 5 | The regular payment date ignored "Week starts on" | 6 | Fixed |
| 6 | Header hairline on when not scrolled; no year jump in the date dialog; segmented thumb right to left | 3 to 4 | Filed in `docs/BUGS.md` |

## Polish round, stage 4: the drawn pieces (23 November 2026)

- **Works:**
  - Edit a transaction, and "Add one like this".
  - Home: "Left in budgets" and Fees tiles that open their pages, "See all", and Forecast and Budgets at a glance switches.
  - Fees: six months as stacked bars.
  - Forecast: "How close it has been", and a one-time pulse on today's point.
  - Coming up: the bubble timeline and "Remind me the day before".
  - Categories: Day by day.
  - Appearance: Category colours. Home screen settings: The app opens on.
  - General: Date style and How amounts are written.
  - Accounts: Edit account and Delete (asks first, refused while entries use the account, offers to switch it off).
  - Removed: the dead `PlaceholderScreen` and the wrong "later update" note under Smart help.
- **Tested:** `flutter analyze` is clean and `flutter test` passes 1,126 tests. New tests cover each piece, plus:
  - start-up on Insights and Add
  - the full figure spoken under short amounts
  - the account delete rules
  - category colours in the theme and icon ink
  - Day by day fills and outlines
  - hermetic overrides for the shell and looks-regular tests

  Goldens were regenerated on purpose: appearance, categories_pie, smart_help, fees, forecast_history and regular. One bug review: 6 fixed with tests, 2 filed.
- **Not tested:** any of this on the Pixel 8 Pro or the emulator. The journey test was not rerun.

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | Editing an entry that already crossed a budget line warned again | 3 x 2 = 6 | Fixed: the warner counts the old entry as "before"; tested |
| 2 | "How close it has been" named the day within the budget month, not the date, when the month starts after the 1st | 4 x 2 = 8 | Fixed; tested with a month starting on the 25th |
| 3 | Under One colour or Greys, the three Fees parts turned the same colour | 2 x 3 = 6 | Fixed: fee parts keep their drawn colours; tested |
| 4 | Deleting the only account switched on left Add with nothing to offer | 2 x 3 = 6 | Fixed in the repository and on the screen; tested |
| 5 | Payments on near days wrote their figures and day numbers over each other | 4 x 2 = 8 | Fixed: a label that would overlap is left out; tested |
| 6 | Bars with more parts stood taller than a bar with the same total | 6 x 1 = 6 | Fixed: the whole bar is to scale, and the parts share it; tested |
| 7 | Edit account shows "Pick this first" off for the account Add falls back to | 2 x 2 = 4 | Filed in `docs/BUGS.md` |
| 8 | Typing in Add before an edited entry loads is overwritten | 1 x 2 = 2 | Filed in `docs/BUGS.md` |

## Pixel 8 Pro check (23 November 2026)

- **Seen on the phone** (debug build with demo data), dark: onboarding, Home, Fees, Insights, Forecast, Coming up, Categories with Day by day, Budgets, Settings, Appearance (Category colours set to Greys and back), Home screen (The app opens on), General (Date style, amounts), transaction detail, Edit, Add one like this (sticky amount), Accounts, Edit account, the Delete dialog (cancelled), App lock and the PIN keypad. Light: Home, Fees and Categories.
- **Fixed from what the phone showed**, each with a test:
  - Fees said "Nothing in October to compare with" beside a chart with October fees. Comparisons are the same days, so the sentence now says "by this day"; Categories rows with nothing to compare show their share alone instead of repeating it.
  - Day by day said "darker means more spent" in dark, where the busiest days are the lightest. Dark now says "brighter".
  - Coming up's empty note and the button under it did the same thing; the note lost its link.
  - Budgets with spending but no budget showed one "has no budget" line on an empty tab. It now lists every spending category, most spent first, with what was spent.
  - Under Greys or One colour, the purple and teal account colours turned the same slate. Account colours now keep their drawn colours (`accountColour`).
- **Journey test:** passes on the Pixel. It now scrolls a lazy list until the next control is built (`_reveal`).
- **Tested:** `flutter analyze` clean, `flutter test` 1,132 passing. Goldens regenerated on purpose: fees (light, dark) and categories_pie (light, dark).
- **Light mode, every screen on the list (23 November, same Pixel, demo data):** no faults found, so no code changed in this pass.
  - Budgets, Settings hub, Appearance, Home screen, General, Accounts and Edit account: checked earlier in the pass; fine.
  - Accounts' delete dialog ("Bank is used by 4 entries"): correct; Cancel left the account untouched.
  - App lock: toggle, "Set a PIN" and the reset warning read clearly. The PIN keypad uses the dark green lock screen in light mode too; this is deliberate, not a theme fault. Cancelled without setting a PIN.
  - Home, transaction detail, Edit transaction and "Add one like this" (pre-filled, sticky amount and direction on scroll, date dialog with Cancel and OK): all fine. Every form was closed without saving.
  - Coming up: checked in its empty state only. The populated timeline has not been seen in light, because the demo data has no regular payments.

| # | Bug | Score | Action |
|---|---|---|---|
| 1 | Fees comparison sentence contradicted its chart | 6 x 2 = 12 | Fixed; tested |
| 2 | Day by day legend wrong in dark | 5 x 2 = 10 | Fixed; tested |
| 3 | Budgets looked empty once anything was spent | 8 x 2 = 16 | Fixed; tested |
| 4 | Two account colours identical under Greys or One colour | 2 x 3 = 6 | Fixed; tested |
| 5 | Coming up empty state offered the same action twice | 4 x 1 = 4 | Fixed anyway (one line) |
| 6 | No-budget category list could shuffle ties past 32 categories | 1 x 2 = 2 | Fixed anyway (tie-break by Settings order) |
| 7 | Back links name a fixed screen when opened from Home | 4 x 1 = 4 | Filed in `docs/BUGS.md` |

