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
