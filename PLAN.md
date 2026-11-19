# Akatabo: build plan

Ship-gate type: **Mobile app (Core + M)**. Tracks W and A are not applicable (no website, no accounts, no backend).

## Context

Akatabo is a free, offline personal money tracker for Uganda. The folder holds the design only: `README.md`, `design/DESIGN_SYSTEM.md`, `design/tokens.json` and 34 screens in light and dark as HTML. The owner wants it built in Flutter (Android first, iOS second) to a publishable capstone standard covering app development, data visualisation and on-device machine learning, with four models that run on the phone.

This plan was written on 19 November 2026 after reading all of those files (68 screen files, in full), checking the installed toolchain, reading the current version of every package from pub.dev, and verifying the main package APIs against their current documentation.

**Where things go.** The project files are in the nested folder `C:\Users\ashab\OneDrive\Desktop\Projects\Apps\akatabo\akatabo\`. That is the project root: `app/`, `ml/`, `PLAN.md` and `PROGRESS.md` go there and the git repository is initialised there. No push; there is no remote.

**First actions after approval.** Write `PLAN.md` in the project root from this plan, `git init`, then start phase 1.

## Verified environment

- Flutter 3.50.0 stable, Dart 3.14.0, JDK 17, Android SDK platforms 35 and 36, an Android 16 (API 36) emulator running.
- Flutter 3.50 template: compileSdk 36, targetSdk 36, minSdk 24, Gradle 9.5.0, AGP 9.3.1, Kotlin 2.4.20, Kotlin DSL. Target API 36 is what Google Play requires today.
- Python 3.13.17, pip 26.2.
- No macOS: iOS code is written but an iOS build cannot be verified here. Recorded as BLOCKED, never PASS.
- No Visual Studio: no Windows desktop run. Tests and goldens run through `flutter test`.

## Downloads this plan needs (approval of the plan covers these)

- Pub and pip packages listed below.
- Android SDK platform 37 through `sdkmanager "platforms;android-37"`, because `flutter_local_notifications` 23 needs compileSdk 37 (targetSdk stays 36). If platform 37 is not available, pin that plugin to its last version that builds on 36 and record it.
- `BricolageGrotesque[opsz,wdth,wght].ttf` (408 KB), `Geist[wght].ttf` (169 KB) and both `OFL.txt` files from the `google/fonts` GitHub repository.
- SQLite binaries that the `sqlite3` package fetches from its GitHub releases at build time, checked by sha256. Build time only; the app makes no network calls.

## Architecture

```
akatabo/                     project root (git repo)
  design/                    existing; tokens.json and the icon table corrected (see "Design files")
  app/
    assets/fonts/            variable fonts for the app, static Geist for PDF, OFL texts
    assets/smart/            exported model artefacts (JSON)
    tool/                    gen_tokens.dart, gen_icons.dart (design files -> generated Dart)
    lib/
      main.dart
      app/                   app, router, shell_scaffold, lock_overlay
      core/theme/            tokens.g.dart, AkColors, AkType, AkMetrics (ThemeExtension), theme builder
      core/icons/            icon_registry.g.dart, AkIcon
      core/format/           money, percent, date
      core/time/             Period, PeriodCalculator, clock provider
      data/db/               AppDatabase, tables, generated migration steps
      data/repositories/     transaction, category, account, regular payment, settings
      data/settings/         typed setting keys
      data/seed/             default data; demo seed (debug builds only)
      domain/                totals, share, budget, forecast, comparison, fees, cash-flow calculators
      smart/                 text normaliser, category model, personal layer, suggester,
                             unusual detector, regular detector, forecast range, artefact loader
      services/              notifications, biometrics, PIN, files, privacy window,
                             export/ (csv, xlsx, pdf), backup/ (codec, restore planner)
      features/<name>/       screens + one providers file per feature
      widgets/               card, row, chip, segmented control, switch, bars/, charts/
    test/  integration_test/
  ml/                        Python: synthetic data, training, evaluation, export, README
  tools/render_design/       renders each design HTML to PNG for comparison
  PLAN.md  PROGRESS.md  SHIP_GATE.md  docs/BUGS.md
```

Rules that hold the structure together:

- **`domain/` and `smart/` import no Flutter.** Every figure on a screen comes from a function there. Rules are written once in Dart, never repeated in SQL.
- **Screens never type a colour, size or radius.** A test scans `lib/features` and `lib/widgets` for `Color(0x`, `Colors.`, numeric `fontSize:` and numeric radii and fails if any appears.
- **`tokens.json` stays the single source.** `tool/gen_tokens.dart` generates `tokens.g.dart`; a test fails if the generated file is stale.
- **The theme is built at runtime** from tokens plus settings (theme, main colour, corners, text size), because Appearance lets the person change all four.
- **Periods are an input.** Settings has "Month starts on" and "Week starts on", so every calculation takes a `Period`. Each transaction stores an indexed `localDay` (yyyymmdd) written at save time.
- **State:** Riverpod 3 with generated providers over drift `watch` streams. Automatic retry is switched off (`ProviderScope(retry: (_, __) => null)`) so a local database error shows at once and tests have no pending timers.
- **Navigation:** go_router `StatefulShellRoute.indexedStack` for Home, Insights, Budgets and Settings. Add sits on the root navigator, covers the shell and pops back to where the person came from. Sub-pages have no bottom bar, as drawn. `PopScope` for Android back.
- **Material widgets come from the `material_ui` package.** Flutter 3.50 deprecates `package:flutter/material.dart`.
- **The lock screen is an overlay** in the app builder, not a route, so nothing can navigate around it.

### Data model (drift, schema version 1)

Text UUID primary keys, with fixed well-known ids for the default categories and accounts, so "Add what is missing" on restore matches rows across phones. Money is `INTEGER` shillings. The database lives in the application support directory. Migrations use `drift_dev make-migrations` with schema snapshots and generated tests from version 1.

| Table | Fields beyond `DESIGN_SYSTEM.md`, and why |
| --- | --- |
| transactions | `localDay`; `payeeKey` (normalised description, for "What it went on", the range strip and "new payee"); `regularPaymentId` (the "regular" tag); `direction` also allows `transfer`, with `toAccountId` (owner decision 1) |
| categories | `isSystem`: Fees and tax is a reserved category whose totals come from the fee and tax fields |
| accounts | `kind`, `colourToken`, `openingBalance`, `askFeeEachTime`, `countInTotals` (all shown on New account) |
| regular_payments | `dismissed`, so a wrong detection can be removed |
| settings | key and value through typed keys (about 45 rows across six pages) |
| forecast_snapshots | the forecast and range saved on each day they are shown, so "How close it has been" reports what was really forecast. Months with no snapshot show nothing |

No table for what the classifier has learned: the personal layer is rebuilt in memory from the transactions table and updated on each save. "Forget everything it has learned" sets a `learningResetAt` setting. Deleting or restoring data then un-learns or re-learns by itself.

### Icons and fonts

- **Icons:** one `AkIcon` widget, a `CustomPainter` that draws paths parsed once by `path_parsing` (plus circles and rounded rectangles) on the 24 grid. Chosen over `flutter_svg` because it paints synchronously: `flutter_svg` decodes asynchronously and golden tests capture a blank box. A test parses the table in `DESIGN_SYSTEM.md` and compares it with the generated registry.
- **Fonts:** the variable files, renamed without brackets. Since Flutter 3.41 `FontWeight` drives the weight axis; text styles add `FontVariation('opsz', size)` for Bricolage to match the browser, and tabular figures for amounts.

### Charts

The owner's rule: a package where it matches exactly, custom where it cannot.

- **fl_chart:** the donut only (gapped slices; the centre total is stacked on top).
- **One `TrendChartPainter`** for the Insights and Forecast lines. fl_chart cannot place text at a data point ("1.28M today", "passes income"), draw the hollow crossing marker or pulse the today point.
- **Small painters:** range strip, payments timeline.
- **Layout widgets**, as the mocks draw them: daily bars, week and term bars, stacked fee bars (2px gaps), history bars with the dashed limit line, forecast-accuracy pairs (open-bottom dashed outline), share bars, cash-flow bars, budget bar with pace tick, heat calendar, Calendar period views.
- Every chart has a text summary and a screen-reader label (fl_chart provides none). No chart is drawn for zero data; it shows an empty state.
- Bar heights come from real data. The mocks' bars are not to scale, so comparison is of structure and style.

### The four models (no TensorFlow Lite)

All run in pure Dart from small JSON artefacts in `assets/smart/`. Each algorithm also exists as a Python reference in `ml/`, and a parity test gives both the same vectors and requires the same output, so what is evaluated in Python is what runs on the phone.

1. **Category suggestion.** scikit-learn TF-IDF character n-grams plus amount-bucket tokens, logistic regression, capped vocabulary, exported as JSON. On the phone a personal layer (exact-match memory first, then smoothed token counts) is blended with it, so a correction wins on the next similar entry and the person's own categories are reachable. "87% sure" is the blended probability computed on the device.
   *Evaluation:* split by merchant template, not by row; typos and mixed Luganda and English; compared with majority-class and keyword baselines; a learning curve of accuracy after k corrections.
2. **Month-end forecast.** The point forecast is the rule in `DESIGN_SYSTEM.md`: spent so far, plus the everyday daily rate (last 90 days) times days left, plus regular payments still due. Occurrences of regular payments and one-offs (above Q3 + 3 IQR for their category) are removed from the daily rate. Shown only after 7 days of entries. The range is a bootstrap of the person's own daily everyday spending for the days left plus the regular payments' bands, later adjusted by their own snapshot errors.
   *Evaluation:* backtest by day of month on synthetic months with effects the rule does not assume (weekday pattern, payday bursts, heavy tails); error and range coverage against run-rate and last-month baselines.
3. **Unusual payment.** A transparent score from three signals: distance of the amount from the person's usual for that category (median and MAD on log amounts), rarity of the hour for them, and whether the payee is new, with a minimum-history gate. "Rarely, Balanced, Often" moves the threshold.
   *Evaluation:* precision, recall and flags per 100 normal entries at the three settings, on injected anomalies not used for tuning. The real measure is the "This was me" rate, which only real use gives.
4. **Regular payments.** Group by `payeeKey`; at least three occurrences, regular gaps and an amount band; a minimum-interval rule so daily lunch is not called a bill; predicts the next date and range.
   *Evaluation:* series-level precision and recall and next-date error on synthetic data with jitter, skipped occurrences and distractors.

`ml/` holds a seeded synthetic generator of Ugandan-style descriptions (every file and column marked synthetic), the scripts, the export step and `ml/README.md` with method, data and measured result per model. Synthetic results are labelled as such and never presented as real-world performance.

### Security and privacy

- PIN: PBKDF2 hash in `flutter_secure_storage` (keystore-wrapped), with growing delays after wrong attempts. Biometrics through `local_auth` 3 (`MainActivity` becomes a `FlutterFragmentActivity`), requested only when switched on.
- Auto-lock after the chosen time away; "Hide amounts"; "Blank the screen in the app switcher" through a small platform channel.
- The database is not encrypted: a 4-digit PIN cannot protect a key. The app relies on the Android app sandbox, and no copy says the PIN encrypts data.
- Android cloud backup is switched off (`allowBackup="false"` plus exclusion rules). By default Android would upload the database to Google Drive, which breaks "nothing is uploaded".
- Backup file `.akatabo`: a readable header (format, schema and app version, counts, date range, key-derivation parameters), then gzip, then AES-256-GCM when a password is set. The key comes from Argon2id run in an isolate, timed on the emulator; PBKDF2 if it takes over about 2 seconds. A newer-version file is detected before decrypting.
- Restore merges by id; when the same id exists on both sides, the row with the newer `updatedAt` wins.
- CSV cells that start with `=`, `+`, `-` or `@` are escaped so a spreadsheet does not run them as formulas.
- **Permissions.** Only `POST_NOTIFICATIONS` and `USE_BIOMETRIC`. The notifications plugin also merges `VIBRATE`, which is removed in the manifest. `RECEIVE_BOOT_COMPLETED` is not added: reminders are rescheduled each time the app starts, so a reminder can be missed between a phone restart and the next open. A release script runs `apkanalyzer manifest permissions` on the built APK and fails on anything else, including `INTERNET`.
- Reminders use inexact scheduling. The weekly automatic backup runs when the app is next opened after a week, so no background-work permission is added.

## Packages (versions read from pub.dev on 19 Nov 2026)

| Package | Version | Why |
| --- | --- | --- |
| material_ui | 1.11.1 | Material widgets for Flutter 3.50 |
| flutter_riverpod, riverpod_annotation | 3.5.0, 4.0.8 | State that follows database streams and is easy to override in tests |
| drift, drift_flutter | 2.35.4, 0.3.1 | Typed SQLite, versioned migrations, in-memory tests. `sqlite3` 3.9.1 comes with it; the end-of-life `sqlite3_flutter_libs` is never added directly |
| go_router | 18.1.4 | Tab shell with pushed routes; this release fixes system back after switching tabs |
| fl_chart | 1.3.1 | The donut |
| path_parsing | 1.1.0 | Parses the icon path table |
| intl | 0.20.3 | Number and date formatting |
| uuid, clock | 4.6.0, 1.1.3 | Mergeable ids; testable "today" |
| local_auth | 3.0.2 | Fingerprint or face unlock |
| flutter_secure_storage | 11.2.0 | PIN hash in the keystore |
| flutter_local_notifications, timezone, flutter_timezone | 23.0.3, 0.11.2, 5.1.1 | Reminders at a local time |
| flutter_file_dialog, share_plus | 3.3.6, 13.3.1 | System save, open and folder dialogs with no storage permission; share sheet |
| pdf, archive | 3.13.1, 4.7.1 | PDF report; zip for the in-house Excel writer |
| cryptography | 2.9.0 | Argon2id, PBKDF2, AES-GCM |
| path_provider, package_info_plus | 2.1.6, 10.2.2 | App folders; version on the About rows |
| dev: build_runner, drift_dev, riverpod_generator | 2.17.1, 2.35.3, 4.0.10 | Code generation |
| dev: flutter_lints, riverpod_lint, mocktail | 6.0.0, 3.2.0, 1.0.5 | Lints; test doubles for plugin wrappers |
| dev: flutter_launcher_icons | 0.14.4 | App icon in phase 8 |
| Python: scikit-learn, pandas, numpy, matplotlib, pytest, fonttools | 1.9.1, 3.1.1, 2.5.5, 3.11.2, 9.2.0, 4.68.0 | Training, evaluation, plots, parity vectors, static Geist for PDF |

Not used, with reason:

- `excel`: needs `xml <7` while `pdf` needs `xml >=7.0.1`. Excel export is a small in-house writer.
- `flutter_svg`: asynchronous decode gives blank goldens.
- `file_selector`: cannot choose a save location on Android. `file_picker`: API changed in its last two major versions.
- `tflite_flutter`: large native library, no gain on short text and a small dataset.
- `google_fonts`: fetches at runtime.
- `alchemist`, `freezed`, `json_serializable`, `csv`, `very_good_analysis`, `patrol`: more machinery than one developer needs here.

The `pdf` package reads static fonts only, so Geist Regular and SemiBold are cut from the variable file with `fonttools` and bundled for the PDF report.

## Design files: corrections I will make and log

Each is recorded in `PLAN.md` and flagged in `PROGRESS.md` for a design check.

1. **`tokens.json` dark values.** Six tokens carry the light value in dark. The dark screens consistently use: `brand-deep` #12261F, `brand-bright` #3FB08A, `brand-text` #8FD0B5, `switch-on` #2F9E78, `surface-raised` #3A4A42, `screen-deep` #0C1A15.
2. **New tokens for values the screens use but the file lacks,** each noted with the screen it came from: type steps (34/38 hero, 24/28, 22, 16, 15, 13, 11), spacing (2, 6, 10, 14, 20), small radii (3, 4), the muted outline, text on the deep screens, the keypad key border, the five extra "Main colour" choices, and past-period category tints (drawn for five categories; the other seven and their dark values are derived by the same mix).
3. **Icon table.** About 40 icon paths are drawn in the screens but missing from the table. They are copied into it before use.
4. **`DESIGN_SYSTEM.md` says `google_fonts`, "three families" and `flutter_svg`.** The owner's decisions (two bundled fonts, one icon widget) win.

## Where the rules beat the screens (differences I will keep)

- Amount input at `figure-xl` 40/44 (screens draw 44/52).
- A day's money out includes fees and tax, so the mock's "53,000" day shows 54,000. Jev rated this reading 77% supported, so it is flagged, not settled.
- Fees "Up 12% on Oct" compares the same number of days, as the rule says.
- The Home forecast card states its range.
- Model results carry the `chip` icon or the model's own icon, which no mock does.
- Back links name the screen the person actually came from.
- Health uses the `heart` icon from the table (screens draw a cross).
- The today point on the forecast pulses once, as the Motion rule says (the HTML is static).

## Undrawn things to build from the rules and flag

Calendar Day, Week, Quarter and Year views; onboarding steps 2 and 3; Add in "Money in" and "Move money" states and with note and tax; set, change and forgot PIN (with no account, forgot PIN can only offer "delete everything, then restore a backup"); backup password entry; restore steps 1 and 3 and its three errors; edit and delete an account; pickers behind value rows; every confirmation dialog; the unusual-payment card with "This was me"; the suggestion pill before there is enough history to give a percentage; empty states for every list, chart and total; scrolling and large text on screens drawn at a fixed 844px.

## Build phases

After every phase: `dart format`, `flutter analyze`, `flutter test`, the bug review (bug table; fix scores of 5 or more, file the rest in `docs/BUGS.md`), a commit, and three lines in `PROGRESS.md`. The `impeccable` skill is loaded before UI work. Each screen is compared with its HTML render in both themes and kept differences are listed.

1. **Foundation.** `flutter create --org com.persmon --project-name akatabo --platforms android,ios app`; `material_ui`; lints; fonts; token and icon generators; theme; `AkIcon`; core widgets; database, repositories, typed settings; `Period`; formatting; the tab shell; default data and the demo seed (matching Home, Insights, Categories and Budgets); the design-render tool. **Every native plugin is added now** and a release build is made, because the build risk sits in AGP 9 and compileSdk 37, not in Dart code.
   *Proof:* generator, scan and icon-table tests; an in-memory database test on Windows; migration scaffold; release build with the permission script and a 16 KB page-alignment check (`zipalign -c -P 16`); shell goldens in both themes.
2. **Core loop.** Onboarding, Welcome, Home (empty and filled), Add, All transactions with search and day groups, One transaction, Calendar with five periods.
   *Proof:* unit tests for money out, total cost, transfers, shares, same-days comparison; widget tests for Add (amount, a few words, one tap on a category; validation; the saved row appears where the person came from); goldens.
3. **Understanding.** Insights, Categories, the category template, Fees and tax, Forecast, Regular payments, with the rule-based forecast and manual regular payments so the screens are real.
   *Proof:* unit tests for the forecast rule, the 7-day gate and the fee split (its three parts always sum to the total); painter goldens; empty-state tests.
4. **Planning.** Budgets, Set a budget, carry-over, warn level, suggested amount from six months of history.
   *Proof:* unit tests for pace, all four statuses at their boundaries, daily allowance.
5. **Customising.** The six Settings pages, Edit a category, New account, Money-in categories, Filters, Choose dates, pickers.
   *Proof:* tests that each setting changes behaviour; theme rebuild tests; notification permission asked only when a reminder is switched on.
6. **Keeping data safe.** PIN and biometric lock, CSV, Excel and PDF export, backup with optional password, restore with preview and merge.
   *Proof:* backup round-trip equals the original; wrong password, damaged file, newer version; merge counts; the Excel file reopened with a Python reader; key-derivation timing.
7. **The four models.** `ml/` generator, training, evaluation, export; Dart inference; wiring into Add, Home, Insights, Budgets, One transaction and Regular payments.
   *Proof:* Python-to-Dart parity tests; a test that a correction changes the next suggestion; `pytest`; measured results in `ml/README.md`.
8. **Finish.** Every empty, validation, confirmation and error state; accessibility (44px targets, contrast in both themes, labels, text scale 1.3 and 2.0 without clipping, reduced motion, a TalkBack pass on the emulator); licences page with both OFL texts; app icon; release build with shrinking and obfuscation; `SHIP_GATE.md` filled with PASS, MISSING/BLOCKED or NOT APPLICABLE and evidence.

## Verification

- `flutter analyze` clean and `flutter test` green at every phase; output recorded in `PROGRESS.md`.
- Goldens at 390 by 844 in both themes, with real fonts loaded in `test/flutter_test_config.dart` and the clock fixed at 19 November 2026. Generated and checked on this machine only, since goldens differ across operating systems.
- Design renders: `tools/render_design` copies each HTML to the scratch folder, points its fonts at the bundled files, and screenshots the 390 by 844 frame with headless Chrome. `design/` is not touched. Compared side by side; never a pixel-difference gate.
- `flutter test integration_test` on the Android 16 emulator: first launch, add three entries, correct a category, set a budget, lock and unlock, export, back up, wipe, restore.
- `flutter build apk --release`, then the permission and page-alignment checks.
- `pytest` in `ml/`.
- Native text is checked with widget tests and device screenshots; the browser text-wrap script does not apply to Flutter widgets.

## What I will stop and ask for

Anything that costs money, creating accounts, publishing or uploading, signing keys, and changes to the owner's listed decisions.

## Open points for the owner

Decided by the owner on 19 Nov 2026:

1. **Cash withdrawals are transfers.** A withdrawal moves money from a wallet or bank account to Cash. The amount is not money out; its fee and tax are.
   - Add gets a third choice, "Move money", beside Money out and Money in (not in the drawn screen, so flagged for a design check). It asks for the amount, from-account, to-account, fee and tax, and no category.
   - Totals, shares, budgets and the forecast ignore transfer amounts and include their fee and tax.
   - Fees and tax: a fee on a transfer to a Cash account is "Withdrawing cash"; every other fee is "Sending money"; all tax, from any entry, goes in the "Tax" part. The row reads "Tax on withdrawals" only while all tax came from withdrawals.
   - The All transactions mock counts the withdrawal in the day's net; the app will not. Listed as a kept difference.
2. **Android application id: `com.persmon.akatabo`.**

Not blocking; I build the sensible version and flag it:

- Language list (English only until a person supplies translations); currency (UGX only).
- "Main colour", "Corners" and "Text size" are built as drawn, with the extra colours added as tokens.
- The overall figure on Budgets ("846,000 of 900,000") is the sum of the category budgets.
- Tax on a money-out entry sits under an optional "More" row on Add, beside the note.
- The weekly summary notification uses figures worked out when the app was last open.
- If the chosen backup folder cannot be remembered across restarts, the weekly backup asks for the folder again.
- Crash reporting and a forced-update check (ship-gate items) conflict with "no network"; recorded as NOT APPLICABLE with that reason.
- The project sits in OneDrive, which can lock build files; if builds fail for that reason I will report it.

Launch blockers that need real inputs from the owner (never invented): signing key and its backup, Play developer account, privacy policy facts and a contact for "Send feedback", store listing text and screenshots, app icon artwork, confirmation that "Akatabo" means "little book" and is free in the stores, a Mac for the iOS build.

Real data needed to evaluate the models properly: a few hundred of the owner's own real entries with the category they would choose; at least three months of dated entries for the forecast backtest; entries they consider unusual; their actual recurring bills with dates; common local words and merchant names to check coverage.

## Decision log

Routine decisions made while building, newest last. Each one marked **design check** changes or adds to the owner's design files and is listed in `PROGRESS.md` for review.

### Phase 1 (19 November 2026)

- **Git identity** is set for this repository only (`user.name`, `user.email`), not globally. No remote; nothing is pushed.
- **compileSdk 37, targetSdk 36.** `flutter_local_notifications` 23 needs compileSdk 37; Play requires target 36. Android platform `android-37.0` installed.
- **`androidx.appcompat:appcompat:1.8.0`** added because `local_auth` 3 needs `FlutterFragmentActivity` and an AppCompat theme. **`desugar_jdk_libs` 2.1.5** for the notifications plugin.
- **Release builds are signed with the debug key** until the owner provides an upload key (launch blocker, marked in `build.gradle.kts`).
- **Six dark tokens corrected** to the values the dark screens use (brand-deep, brand-bright, brand-text, switch-on, surface-raised, screen-deep). **design check**
- **Tokens added** for values the screens use but `tokens.json` lacked: type steps, spacing (2, 6, 10, 14, 20), `radius-xs`, the muted outline, text on deep screens, heat steps, range band, past-period category tints, a `size` section (target, row, input, button, nav, tiles, icons, switch, bars, dot, pill, the Add grid cell), and five more main colours derived from the green so every brand pair passes contrast. Each carries a `note`. **design check**
- **26 icons added to the icon table** from the screens; **grip** is drawn stroked in the table (the screens fill it). **design check**
- **Health uses the `medical` cross** now that it is in the table, as the screens draw it. This replaces the earlier plan to use `heart`.
- **Section eyebrows use `caption` (500)** as the rule says; the screens draw them at 600. Kept difference.
- **Corners setting:** Rounded 1, Slight 0.4, Square 0 times every radius token, from the drawn 10px / 4px / 0px buttons. Switches and discs stay round.
- **Text size setting:** Small 13/14, Standard 1, Large 16/14 times every type token, from the drawn 13 / 14 / 16px buttons. The phone's own text size applies on top.
- **Generated code checks itself:** `tokens.g.dart` and `icon_registry.g.dart` carry an FNV-1a hash of their source; a test fails when the design file changes and the Dart is not regenerated.
- **Formatter width 100** (`analysis_options.yaml`), so widget trees stay readable.
- **Direction values are `moneyOut`, `moneyIn`, `transfer`** (`in` is a Dart keyword).
- **Default categories and accounts** are those drawn on Add, Settings > Categories and Money-in categories, with fixed ids (`cat.food`, `acct.mtn`). MTN MoMo is the default account, as drawn. No default budgets: the drawn budgets are sample data.
- **Week starts on Sunday by default**, as drawn on Settings > General. Month starts on the 1st.
- **A month that starts on the 25th of October is named October** (it is named after the month it starts in). **design check**: the design does not say.
- **The clock in tests:** a clock fixed around the whole test run does not reach test bodies, so tests that read the time wrap their body in `atTestNow`; widgets will read "today" through a clock provider that widget tests override.
- **The debug demo seed moves to phase 2**, where Home and Insights first need it.

### Phase 3 (19 November 2026)

- **The forecast range is deterministic.** The plan's bootstrap is replaced by plus or minus one standard deviation of daily spending, scaled by the square root of the days left, plus the regular payments' low and high amounts. The result is clamped so it always contains the point. Reason: it is reproducible in tests and needs no random seed on the phone. The range is a first estimate and is not yet checked against real months.
- **One-offs in thin categories use the pooled line.** A category with fewer than four entries uses the outlier line from all spending pooled, so a single school payment is still recognised as a one-off.
- **Insights has no period stepping.** The period segment (Week, Month, 3 months, Year) changes the view; Earlier and Later are not built. Design check: the drawn screen has no stepper.
- **Categories covers the current month only.** Past months are reachable from Insights later.
- **Not built in phase 3:** Edit a category, the budget row (phase 4), the "See all" link, the six-month stacked fee chart, the "How close it has been" snapshot section, the remind toggle, the bubble timeline, and the day-by-day heat strip on Categories.
- **Manual regular payments default to Bills.** The form does not ask for a category.
- **Copy:** "You added these by hand." sits under the regular payments total, because detection from entries is not built yet and the person should see where each figure came from.
- **Fees rules, as decided by the owner:** a fee on a transfer to a Cash account is "Withdrawing cash"; every other fee is "Sending money"; all tax is "Tax", or "Tax on withdrawals" only when every tax came from withdrawals.
- **Monthly and Yearly step by calendar month and year** (intervals 30 and 365), keeping the day of the month and clamping it to shorter months. Other intervals step by days.
- **A regular payment's entries are matched by payee.** Until detection links entries to payments, an entry whose payee key equals an active regular payment's is left out of the everyday rate, and a payment due today that already has such an entry today is not added again.
- **The rest of today is forecast.** Everyday spending still to come is the rate less what was spent today (never below zero), plus the rate times the days after today. The drawn rule counts only the days after today; design check.
- **One-off spread floor:** Q3 + 3 × max(IQR, Q3 / 4), so a category of equal fares does not turn every slightly larger amount into a one-off.
