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
- **Phase 4 statuses:** Over (spent above the budget), then Nearly used (spent at or above the warn level), then A little ahead (spent above pace), then On track. Pace is the day of the budget month over its length, so it follows "Month starts on".
- **Carry-over is one month and does not compound.** Last month's unspent part is added to this month's budget, never last month's carry. It applies only once the budget has covered a whole month: a `budgetSince` day (schema v2) is set when a budget is created or carry-over is switched on, kept when the amount or warn level changes, and cleared when the budget is removed.
- **Suggested budget:** the 80th percentile of the last six months' money out in the category (index ceil(0.8n) - 1 of the sorted months), rounded up to 10,000. It needs at least three months with spending; months with none count as zero.
- **Warn levels are 60, 70, 80 and 90 percent**, 80 by default.
- **The daily allowance is rounded down to the hundred**, so it never promises more than is left. On the last day it shows what is left for today.
- **The overall figure is net:** the sum of the budgets less the sum of what was spent, so an overspend in one category reduces what is left overall.
- **Fees and tax cannot be budgeted.** It is a system category whose total comes from fee and tax fields.
- **Eyebrow section labels stay** on Budgets and Set a budget, as the design system draws them.
- **The budget bar's pace tick** uses the `size-stroke` token in ink.
- **Settings hub rows map to phases.** General, Appearance, Accounts, Home screen, Categories, Smart help, Reminders, Edit a category, New account, Money-in categories, Filters, Choose dates and the pickers are built in phase 5. Privacy and security and Data and backup belong to phase 6.
- **Home sections are switchable only where they exist.** The header figures, "Where it went" and "Latest" can be switched off. The drawn forecast card and "Budgets at a glance" do not exist on Home yet and get no switch.
- **Settings values apply at once.** Each switch or segment writes to storage and the screens that read it rebuild from the stored settings stream.
- **Tests replace the live settings stream** with a fixed one in widget tests (a live drift stream does not settle under the test clock). Saved values are checked in the database, and the providers are tested against a real in-memory database.
- **Account kind "Other" uses the bank colour** until a colour token for it is added to tokens.json (design check).
- **Hiding a category** removes it from Add and its lists but keeps past entries. Fees and tax is a system category and cannot be hidden.
- **Switch rows show their own label.** `AkSwitch` draws only the switch and carries the label for screen readers; `SettingsSwitchRow` draws the visible text beside it.
- **Edit a category covers name, icon, colour, budget and delete;** order is changed on Categories by dragging the grip, by the grip's menu, or by screen-reader actions. A name another category already uses (trimmed, ignoring case) is refused, and the check runs inside the save's database transaction.
- **Fees and tax is not listed in Categories settings.** Its total comes from fee and tax fields, so it has nothing to rename, hide or budget. The drawn "Filled from the fee you enter" row is left out (design check).
- **Money-in categories have their own screen,** reached by one row on Categories that names them ("Salary, business, gifts"), as drawn.
- **A hidden category says so in words** under its name ("Hidden, no budget"), not only through its switch.
- **Each Main colour swatch has a 1px `ink-muted` edge.** In dark, some main colours sit below 3:1 against the card (Charcoal 1.76); the edge keeps every disc visible. The contrast test checks it in both themes.
- **Budget warning is an on/off switch** that uses each budget's own warn level, set on Set a budget. The drawn Smart help control is "reaches 70% / 80% / 90% / Never"; one level per budget avoids two settings that disagree (design check).
- **The category chart choice is Pie, Bars or List only,** as drawn, and Insights follows it.
- **Smart help switches for the phase 7 models are stored only.** The switches save, but the models they control arrive in phase 7.
- **Reminders are rescheduled each time the app opens and when it goes to the background,** so the weekly summary carries recent figures. The notification small icon is a monochrome vector (`ic_stat_akatabo`), kept from resource shrinking by `res/raw/keep.xml`.
- **New account is built as drawn:** name, kind, colour, what is in it today, and three switches. Kinds are Mobile, Cash, Bank and Other; `mobile` was added because the design offers "Mobile" and never asks which network (kinds are text, so no schema change). A new account's colour follows its kind until one is picked; the six choices are the four account colours plus purple and teal, as drawn. A swatch under 3:1 against the page gets a 1px muted edge (only yellow in light). The back link says "Accounts", where it opens from. The name allows 40 characters, like category names.
- **"Ask for the fee each time"** decides where Add puts the fee box for money out and Move money: in the form when the paying account asks, otherwise under "More details" beside Tax, so a fee can still be recorded. Money in never shows a fee. New installs start with MTN, Airtel and Bank asking and Cash not, as Add draws the fee box with MTN MoMo.
- **Schema v3** adds `balanceAt` to accounts and gives existing installs the same fee setting on the default MTN, Airtel and Bank accounts. Before v3 no screen could set the fee choice on them, so no choice of the person's is overwritten.
- **A balance counts from the moment it was set.** "What is in it today" is stored with the moment it was true (`balanceAt`); only entries dated from then on change the balance, so a back-dated entry is not counted twice. The default accounts start with no balance ("Not set", left out of the Total) rather than a made-up 0, and New account left empty does the same. Tapping an account under "What is in them today" says what is in it now.
- **One account is picked first when you add.** Saving New account with "Pick this first" on takes it from the old one, and General has a "Picked first when you add" row under "Numbers and entry" using the shared choice sheet. Add, General and the hint all use one rule: the marked account, or the first switched-on account if it is switched off.
- **"Count it in my totals" applies only to account balances (design check).** No drawn screen shows a balance; spending, money in, fees, budgets and the forecast count every entry. Settings > Accounts gains "What is in them today": each account's balance (opening amount, plus money in, less money out with its fee and tax, plus or minus moves), a Total of the counted ones, and a note naming any not counted or not set. This section, its sheet and their copy are not drawn.
- **Deferred from the drawn settings, to build later (design check):** Category colours (Colourful, One colour, Greys) on Appearance; "The app opens on" (Home, Add, Insights); Date style and "How amounts are written" (1,284,000 or 1.28M) on General. Each needs every screen that draws a category tile, a date or an amount to read the setting, which is wider than phase 5.
- **Choose dates is held in memory and not saved.** The chosen range resets to All dates when the app opens. It is reached at `/filters/dates`, from the Dates row on Filters.
- **Only the choice is held, not its dates.** A preset's days are worked out when read (`chosenPeriodProvider`), so "Last 7 days" moves on at midnight and "This month" follows "Month starts on". Saving a setting never resets the choice.
- **Choose dates applies on its button.** Presets show their own length ("Show these 7 days"). A custom range counts both ends.
- **Custom range tap rule changed from the drawn hint (design check).** The drawn rule, "a tap before the start moves the start, any later tap moves the end", could never move the start later: 10 to 15 November could not be picked from 1 to 30 November. Now a tap on a range of more than one day starts a new one-day range, and the next tap sets the other end. The hint reads "Tap the first day, then the last day. A third tap starts again."
- **Custom range months start on the person's week start,** and the grid shows one month at a time with previous and next buttons (the drawn screen shows only November).
- **Filters are held in memory, like Choose dates,** and apply at once; the button counts the matching entries and returns to the list. All dates is the default, so opening All transactions shows every entry, as before Filters existed. Choose dates gained an "All dates" chip to go back to it.
- **Search words and the money in or out choice live in the filter,** so the Filters count and the list use one rule (`matchesFilter`) and always agree. Clear all on Filters keeps them, because they have their own controls on the list.
- **The day view ignores Filters and dates.** A day opened from Calendar uses only its search box and direction, and stays newest first with its day heading.
- **Largest is one flat list,** biggest first, without day headings; Newest and Oldest stay grouped by day.
- **A lowest amount above the highest applies no limit** and says so under the fields; Show is disabled until the pair is in order.
- **Filters list every account, switched off or not,** because an account switched off later still has entries.

### Phase 6 (20 November 2026)

- **Three builders in worktrees, one lead.** Lock, export and backup were built in parallel on their own branches and merged on `main`; the lead owned the routes, the Privacy and data skeleton, About and the docs, so no two builders edited the same file.
- **Export file names say the period:** `akatabo-2026-11.csv`, `akatabo-2026.xlsx`, `akatabo-2026-11-03-to-2026-11-15.pdf`, `akatabo-all-2026-11-20.csv`. The person picks where the file goes (system save dialog) or shares it (share sheet); nothing is written without that choice.
- **Export columns:** Date, Type, Description, Category, Account, To account, Amount, then Fee and Tax when "Fees and tax as their own column" is ticked, Money out, Money in, and Note when ticked; category totals with budgets go on their own sheet or section. CSV cells that start with `=`, `+`, `-` or `@` are escaped. Excel is the in-house writer; the PDF uses the static Geist cut, with a `brand-deep` note card. Custom shows From and To rows on Export itself, starting on this month up to today.
- **The segmented control sizes itself to its labels.** `AkSegmented` keeps equal widths while every label fits; otherwise, if all labels fit side by side, each segment gets width in proportion to its label. "This month" no longer wraps on Export (text-fill rule).
- **The lock is a 4-digit PIN,** hashed with PBKDF2-HMAC-SHA256 at 60,000 rounds in a background isolate and kept in secure storage. Four wrong tries are free; then the waits are 30 seconds, 1 minute, 5 minutes, 15 minutes and an hour from the ninth on. Waits are timed against the phone's time since boot, so moving the date does not shorten them.
- **"Lock after" offers Right away, 1, 5 and 15 minutes away** (default 1 minute). File pickers and the fingerprint prompt do not count as away.
- **The lock is on only while the setting is on and a PIN is stored,** so neither alone can shut the person out. "Change PIN" is a row under the lock (not drawn; design check).
- **Forgot PIN can only start again.** With no account, the only way back in is to delete everything on the phone and restore a backup; the dialog says so, and afterwards the app opens on Privacy and data. "Delete everything on this phone" on Privacy and data runs the same step, so the PIN goes too.
- **Hide amounts shows dots until a figure is tapped; one tap reveals every figure** until the app next goes out of sight. Chart axis labels and the transaction detail screen do not hide yet (filed).
- **Blank the screen in the app switcher is on by default** and shown on Android only; iOS has no handler yet, so the row is left out there rather than offering a switch that does nothing.
- **The backup file (`.akatabo`)** has a readable header, then gzip, then AES-256-GCM when a password is set. The key comes from Argon2id (19 MiB, 2 passes) in a background isolate, or PBKDF2 at 310,000 rounds when Argon2id takes over about two seconds. The password is never stored; a protected weekly backup asks for it each time. Files over 64 MB, or that unzip past the limit, are refused.
- **Settings that belong to this phone are never restored:** keys starting `backup.`, `lock.`, `privacy.` or `security.`, and onboarding done. A restored backup cannot switch on a lock without the PIN that goes with it.
- **Restore defaults to "Add what is missing";** "Replace everything" asks first and says how many entries only this phone has. When the same id is on both sides, the newer `updatedAt` wins. It all happens in one transaction or not at all.
- **The weekly backup runs when the app is opened a week after the last one,** into the folder the person chose. If the phone forgets the folder after a restart, it asks again.
- **About shows Version and Open-source licences only.** The licence page carries both fonts' OFL texts. "Privacy policy" and "Send feedback" are drawn but left out until the owner supplies the policy and a contact (launch blockers).
- **Not drawn, built from the rules (design check):** set, change and forgot PIN; the lock screen's wait message; the backup password entry; restore steps 1 and 3 and its errors; every confirmation dialog in this phase.
- **A default row this phone never edited gives way to the backup's edited copy.** The defaults are seeded with the moment the app was first opened (or Delete everything ran), which is later than any older backup, so plain "newer wins" kept a blank Cash or Food over the person's balance and budget. A phone row with `createdAt` equal to `updatedAt` was never edited; when the backup's copy was, the backup's copy wins. A phone edit made after the backup still wins.
- **System file and folder dialogs and the share sheet do not count as "away" for the lock,** so "Lock after: Right away" does not lock the app while a backup or export is being saved.

### Phase 7 (20 November 2026)

- **Three builders in worktrees, one lead,** as in Phase 6: category suggestion; unusual and regular payments; the forecast range. The lead wrote the shared synthetic generator (`ml/common/synth.py`) first, so all three trained and tested on the same seeded data, and kept `ml/README.md` and the docs.
- **Every model number is synthetic and labelled so.** `ml/README.md` says what the numbers do not show and lists the real data needed to evaluate the models properly.
- **Parity is exact by construction:** median, MAD, sums, percentiles and rounding are written by hand in both languages, and the forecast bootstrap uses a fixed xorshift32 generator in both, so Dart reproduces Python to 0 (integers) or under 1e-9 (doubles).
- **The suggestion pill shows at 70% sure or more,** after 5 categorised entries of the person's own since "Forget everything it has learned", once 3 letters or digits are typed. The newest category for a known payee always scores at least 0.72, so a correction shows the next time. The suggested tile is also preselected; picking another one saves a correction. While suggestions are on, the Category heading row is 44px tall (drawn 28px) so the grid does not jump as the pill comes and goes (design check).
- **"This was me" is saved on the entry** (`flagDismissed`, already in the schema), not only for the session, so the share of flags people wave away can be measured. **"Only unusual" on Filters uses the detector's own flags;** before, it read `flaggedUnusual`, which nothing writes, and always showed nothing.
- **Regular payments never calls a near-daily payment a bill** (median gap under 5 days), and Dismiss on "Looks regular" saves a dismissed row so it is not offered again.
- **The first forecast shown each day is saved** as a snapshot; past months' errors only ever widen the range. A rule that could narrow it lost coverage when there were only one or two months of history.
- **Insights has no unusual note:** the drawn Insights screen has no place for one.
- **Design checks:** the "Looks regular" section, the unusual card and the range sentence on Home and Forecast are not drawn. The Home card repeats the point figure ("Heading for UGX 175k", then "most likely 175k") and then shows an exact difference (175,395); the wording is to be settled. The Home forecast card has no switch of its own under Appearance.
- **"This was me" does not change `updatedAt`.** Category suggestion reads `updatedAt` as when the category was last chosen; answering a flag is not choosing one. A restore that merges an older copy of the entry may bring the flag back.
- **"Only unusual" follows the Smart help switch:** with "Point out unusual payments" off, nothing is marked unusual anywhere.
- **The forecast reads only the current month's rows and waits for reloads,** so the forecast saved first on the 1st is never worked out from last month's entries.

### Phase 8 (20 November 2026)

- **Touch target is 44 x 44** on every control, checked on 32 screens in both themes. Android's 48 dp is met by the primary controls (tabs, Add, Save); picker swatches stay at 44, as drawn.
- **Contrast is checked on exact token pairs** (`theme_contrast_test.dart`), not with Flutter's pixel-sampling guideline, which measured anti-aliased edges of small text (it read #55635C as #818B86). Two tokens were nudged to pass 4.5:1: `money-out-soft` light #F3D5C7 to #F7E3D9, and `acct-cash` #6F8A2A to #74902C in both themes. Each has a usage note in `tokens.json`.
- **Large text:** rows that put pills beside a title are `Wrap`s, so pills move down only when there is no room. The Add category grid shows 3 across from text scale 1.6. Nothing clips at 2.0.
- **Reduced motion:** page transitions stand still when the phone asks for less motion. The forecast "pulse" in the plan was never built, so there is nothing else to stop.
- **States:** one shared helper (`lib/widgets/ak_message.dart`) for "could not load" and "could not be saved". A screen whose data fails to load says so instead of a blank box or "UGX 0". A failed delete or save keeps the item and says so.
- **App icon is provisional:** the wordmark "A" in Bricolage Grotesque Bold, accent on brand-deep, drawn by `tool/render_icon_test.dart` and sized by `flutter_launcher_icons`. Final artwork is a launch blocker.
- **Release build shrinks code and resources with R8** and is obfuscated, with symbols kept in `build/symbols`.
- **Accessibility tree check on the emulator** (what TalkBack reads; a live TalkBack listen-through is still to do) found one unnamed field (the Add amount, read as "0"); text fields that carry a label now merge it onto the edit box.
- **Home's first-day step 2, "Check your categories", now opens Categories,** like the other two steps; it was text only.

### Polish round (20 to 21 November 2026)

After the owner tried the app on a Pixel 8 Pro. Owner decisions: a new private GitHub repo, App lock on its own page, build everything drawn.

- **The plus in the Add disc is 28px** (`size-icon-add`); the disc stays 48px.
- **Settings hub built to `Settings.html`**, three grouped cards; App lock joined the third card as its own row, and Privacy and security took the phone icon.
- **Own date dialog, no stock picker.** The stock date picker drew `Icons.*` glyphs from the MaterialIcons font, which the app does not bundle (`uses-material-design: false`), so it showed boxes with crosses. `AkDateDialog` is built on `AkMonthGrid`, the grid Choose dates already had, now shared in `lib/widgets/ak_month_grid.dart`.
- **The time picker opens for typing (`TimePickerEntryMode.inputOnly`), not on the dial** as the plan first said. Typing draws no icon, is faster on a phone keyboard, reads better with TalkBack, and the tests can type a time.
- **PIN keypad:** the space left over is split above the title and between the message and the keypad (2 : 3), instead of one gap pushing the keypad down; keys grow with the screen up to 84px (`size-pin-key`), never below 44.
- **Add keeps the kind and the amount in view.** They sit in a header above the scrolling form, with a hairline once the form scrolls. Below 520px of room (`size-pinned-form-min`, which counts the keyboard) or above text scale 1.3 the amount scrolls with the form. A `GlobalKey` carries the amount field across the move, so it keeps focus and the keyboard.
- **Move money always shows "Fee to move it"**, whatever the account's "Ask for the fee each time".
- **Motion timing is Dart constants (`AkMotion`: 160ms, ease-out cubic), not tokens.** `tokens.json` has no motion group and durations are not something a designer changes per theme; one file keeps them in one place, and `AkMotion.of` returns zero when the phone asks for less motion. `AkSegmented` slides its thumb with it; `AkSwitch` uses it.
- **Calendar says "3 months"**, like Insights.
- **Empty first day fills the screen:** the drawn dashed chart note (`size-icon-lg`, 28px trend icon), the drawn "Used Akatabo before?" restore row, a row to add a regular payment and the three lines from `Welcome.html`. The last two are not drawn (design check).
- **Empty Budgets lists the spending categories**, each opening Set a budget, instead of sending people through Settings > Categories. The `from=budgets` back label went with it.
- **Every empty note that something can fill has one action** (`DESIGN_SYSTEM.md` rule).
- **App lock page** (`/settings/lock`, undrawn around SetPrivacy.html's rows): the PIN row always shows. With the lock off it reads "Set a PIN" and runs the same flow as the switch, so a PIN never exists with the lock off; a PIN left behind by a failed clear is replaced, never asked for. The rows wait for the PIN check, so a stored PIN cannot be replaced unasked while it loads.
- **Back links name where the person came from** on Restore (Home), App lock (Privacy and data) and New regular payment (Home).

### Polish round, stage 4: the drawn pieces (22 to 23 November 2026)

- **Edit reuses Add** (`/add?edit=id`, `/add?like=id`). Editing keeps the id and the moment; "Add one like this" copies the entry with today's time. The repository's `update` moves `updatedAt`.
- **Home tiles open their pages**: Left in budgets (or Over budget) goes to Budgets, Fees to Fees. Budgets at a glance shows the top three budgets and is off by default, as drawn.
- **Fees by month is a stacked bar chart** (`StackedBars`), with fees, tax and withdrawing cash as the three parts.
- **Forecast "How close it has been"** uses the best snapshot of each of the last three months. A month with no snapshot is left out, not shown as zero.
- **The today point pulses once** (`AkMotion.pulse`, 1,200ms), and not at all under reduced motion.
- **Coming up draws bubbles by area**: the radius follows the square root of the amount, so a payment twice as big looks twice as big. "Remind me the day before" is the same setting as the reminder in Smart help, through one shared `switchReminder`.
- **Day by day** reuses Calendar's `heatStep` and the shared `heatColour`, so both grids agree.
- **Category colours is a theme swap**, not a data change. One colour sets every `cat-` token to the main colour, and Greys sets them to slate. Stored colours stay, so Colourful brings them back. The icon ink follows the drawn fill, not the stored name. The colour picker in Edit a category still shows the real colours. The `-past` tints are unused and left alone.
- **"The app opens on" is read at start-up**, like the onboarding flag, because the settings stream has not loaded before the first frame. Add opens over Home (pushed after the first frame), so closing or saving it lands on Home rather than an empty stack. The choice sits on the Home screen settings page, where SetAppearance.html draws it.
- **Date style** has three options: in words (each screen keeps its own wording, so the default changes nothing), 19/11/2026, and 2026-11-19. It applies to full dates on screens (entry detail, regular payments, backup dates). Exports keep their own fixed formats, because a CSV must sort.
- **How amounts are written** changes only a screen's main figure (`AkHeadlineAmount`). Rows, receipts and exports stay in full. A screen reader always hears the full figure, because "1.28M" read aloud loses the amount.
- **Edit account reuses New account** (`/settings/accounts/edit/:id`) without the balance field, which the Accounts page sets. MTN and Airtel show as Mobile and keep their own kind unless another is picked. Delete asks first. It is refused while any entry uses the account, paid from it or moved to it, and offers "Switch it off" instead. The only account is never deleted. If the default account is deleted, the default passes to the next account that is switched on.
- **The "later update" note under Smart help is removed, not reworded.** The features work, and SetSmart.html draws no note there. `PlaceholderScreen` was dead code and is deleted.
- **Tests stay hermetic:** app-level tests override every provider that reaches the database (`previousMonthRowsProvider`, `allCategoriesProvider`, `allAccountsProvider`). A live drift stream never settles under the test clock.
