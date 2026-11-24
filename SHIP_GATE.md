# Ship gate checklist: Akatabo

**Type: Mobile app (Core + M).** Track W (website) and Track A (web app) are NOT APPLICABLE: there is no website, no sign-in and no server.

Checklist from `~/.claude/ship-gate.md`. Status is PASS, MISSING (not done yet), BLOCKED (needs something from the owner or a Mac) or NOT APPLICABLE (with the reason). Evidence names a file, test or observed result. Last updated 21 November 2026, polish round.

**Verdict: not ready to publish.** The app works end to end on the Android 16 emulator, but the launch blockers below need the owner.

## Launch blockers (need the owner)

1. ~~Final app icon artwork~~: done 24 November 2026. The owner picked the "notebook + line" mark; icons, splash and logo are drawn from it (`design/brand/`).
2. An upload signing key, its passwords, and an off-device backup of both. The release is signed with the debug key.
3. A Google Play developer account (AAB upload, Play App Signing, Data safety form, content rating, closed testing).
4. Privacy policy facts: the operator's name, a contact address, and a hosted URL. The same contact is needed for "Send feedback".
5. Store listing text, approved screenshots, and confirmation that "Akatabo" means "little book" and is free to use in the stores.
6. A Mac with Xcode 26 for the iOS build, its privacy manifest and the App Store items.

## Core

### C1. Design quality

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1 | Impeccable used for UI work | PASS | Loaded before UI work in every phase; `PRODUCT.md` written from the design files |
| 2 | No one-sided accent stripes | PASS | None in `lib/`; the design has none |
| 3 | No generic template tells | PASS | Owner's own design system, two bundled font families, one icon set |
| 4 | Real content, no fake figures | PASS | Every figure comes from the database or a model. Sample entries only with `--dart-define=AKATABO_DEMO=true` (`lib/main.dart`). Model results from synthetic data are labelled synthetic in `ml/README.md` |
| 5 | Consistent system | PASS | `tokens.json` generates `tokens.g.dart`; `test/core/no_literals_test.dart` bans typed colours, sizes and radii in screens |
| 6 | Text fills its space | PASS | The browser script does not apply to Flutter. `test/a11y/screen_sweep_test.dart` opens 32 screens at text scale 1.0, 1.3 and 2.0 with no layout errors; rows that broke early became `Wrap`s that move down only when out of room, and the goldens match their old masters at normal size |

### C2. Accessibility

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1 | Native roles, headings | PASS | Section titles and eyebrows carry header semantics (`AkSectionTitle`, `AkEyebrow`); buttons, switches and text fields carry native roles. Seen in the emulator's accessibility tree |
| 2 | Switch and keyboard access, visible focus | MISSING | Reorder has menu and screen-reader actions besides dragging. No keyboard or Switch Access pass has been done |
| 3 | Contrast 4.5:1 / 3:1 | PASS | `test/core/theme_contrast_test.dart` checks exact token pairs in both themes, including 17 pairs in the shared controls. Two tokens were nudged to pass (`money-out-soft` light, `acct-cash`). The pixel-sampling guideline is not used: it measured anti-aliased edges, not the colours |
| 4 | Touch targets | PASS | 44 x 44 on every control of 32 screens in both themes (`screen_sweep_test.dart`), above WCAG 2.5.8. Primary controls (tabs, Add, Save) also meet Android's 48 dp; picker swatches are 44 as drawn |
| 5 | Labels for icons and controls | PASS | `labeledTapTargetGuideline` on every screen. The emulator TalkBack pass found the Add amount field announced only as "0"; fixed with `MergeSemantics`, tested in `test/a11y/field_names_test.dart` |
| 6 | Forms: visible labels, errors tied to fields | MISSING | New account, Edit a category, budget and backup password put errors on the field. Add shows its problems in one list above Save, not on each field (`docs/BUGS.md`) |
| 7 | Reduced motion, text scaling | PASS | Page transitions stand still when the phone asks for less motion (`lib/core/theme/still_transitions.dart`, `test/core/still_transitions_test.dart`); `AkSwitch` and the sliding thumb of `AkSegmented` too (`AkMotion.of`). Text scale 2.0 on every screen as in C1.6 |
| 8 | Screen reader pass | MISSING (partly done) | Done: the release APK's accessibility tree (what TalkBack reads) on the Android 16 emulator for Onboarding, Welcome, Home, Add, Settings and Budgets. Every control named except the Add amount field, now fixed and tested in `test/a11y/field_names_test.dart`; the current tab is marked selected. Not done: listening to TalkBack while swiping through each screen (spoken words, focus order), and re-checking the fix on the device. iOS VoiceOver BLOCKED (no Mac) |

### C3. Security (MASVS for mobile)

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1-6 | HTTPS, headers, cookies, server banners, security.txt | NOT APPLICABLE | No server and no network calls. The release APK has no `INTERNET` permission (`tool/check_permissions.ps1`, run on 20 Nov 2026) |
| 7 | Validate input | PASS | `TransactionDraft.problems()`; database CHECK constraints on amount, fee and tax (`test/data/database_test.dart`); restore validates the file before reading it |
| 8 | Parameterised queries | PASS | drift builds every query; no string SQL besides `PRAGMA foreign_keys` |
| 9-11 | CSRF, CORS, SSRF | NOT APPLICABLE | No server |
| 12 | Uploads | NOT APPLICABLE | Nothing is uploaded. A chosen backup file is checked by its first bytes and a 64 MB limit before it is read (`lib/services/backup/backup_files.dart`) |
| 13 | Minimum personal data, protected at rest | PASS | No account, no identifiers. PIN stored as a PBKDF2 hash in `flutter_secure_storage`; backup files optionally AES-256-GCM with Argon2id. The database is not encrypted, by decision: a 4-digit PIN cannot protect a key (`PLAN.md`); it relies on the app sandbox, and Android cloud backup is off |
| 14 | No secrets in the repo or binary | PASS | The app has no keys or tokens. A pattern search of `lib/`, `android/` and `ios/` found only the backup cipher's variable names. gitleaks is not installed here |
| 15 | Lockfile, no known high vulnerabilities | PASS | `pubspec.lock` committed; `flutter pub get` reported no security advisories. Nine packages have newer major versions, held back on purpose |
| 16 | Third-party scripts | NOT APPLICABLE | No web content |
| 17 | Least-privilege keys | NOT APPLICABLE | No backend |
| 18 | Rate limits | PASS (PIN) | Wrong PINs get growing delays measured from phone start-up time, so changing the clock does not skip them (`lib/services/security/pin_store.dart`) |
| 19 | Automated scan | MISSING | No MobSF or equivalent static scan of the release APK has been run |

### C4. Privacy and legal

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1 | Privacy policy | BLOCKED | Needs the operator's name, contact and a hosted URL. The facts the app can support: no data leaves the phone, no analytics, no account, cloud backup off |
| 2 | Terms | BLOCKED | Owner decision |
| 3 | Jurisdiction | BLOCKED | Uganda Data Protection and Privacy Act 2019 applies to the operator. Whether PDPO registration is needed when no data leaves the phone is for the owner to confirm |
| 4 | Cookies and embeds | NOT APPLICABLE | None |
| 5 | Analytics | NOT APPLICABLE | Owner decision: no analytics |

### C5. States and feedback

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1 | Loading, errors, retry | PASS | Phase 8 audit of every screen. Screens whose data cannot load now say so instead of a blank box or a false "UGX 0" (Home, Insights, All transactions, Categories, One category, Fees and tax, Forecast, Regular payments, One transaction, Privacy). `test/features/failure_states_test.dart` |
| 2 | Form errors | MISSING | See C2.6 |
| 3 | Empty states | PASS | Every list, chart and total has a sentence and, where something can fill it, one action: "Add a transaction" (Insights, Categories, One category, Fees and tax, Forecast) or "Add a regular payment". Home's first day has three tappable steps, the drawn dashed chart note, a restore row, a regular payment row and what the app does (`test/features/home/first_day_steps_test.dart`). Empty Budgets lists each spending category, opening Set a budget (`test/features/budgets/budgets_test.dart`). Updated 21 November 2026 |
| 4 | Messages after actions | PASS | Failed saves, deletes and removals now report and keep the item (`lib/widgets/ak_message.dart`, `saveOrSay`); backup, export, restore and delete everything confirm what happened |
| 5 | Offline | NOT APPLICABLE | The app never uses the network |

### C6. Backend and uploads

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1-5 | Store first, idempotency, timeouts, health endpoint, uploads | NOT APPLICABLE | No backend |
| 6 | Versioned migrations | PASS | `drift_schemas/akatabo/drift_schema_v1.json` from `drift_dev make-migrations`; steps and generated tests start at version 2 |

### C7. Operations

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1 | Monitoring and crash reporting | NOT APPLICABLE | Conflicts with "no network calls"; owner decision |
| 2 | Email | NOT APPLICABLE | No email |
| 3 | Backups | PASS | In-app backup, weekly backup and restore with preview and merge. The emulator journey test backs up, deletes everything and restores three entries and a budget (`integration_test/app_journey_test.dart`, passed 20 Nov 2026) |
| 4 | Real-network testing | NOT APPLICABLE | No network |
| 5-6 | Environments, rollback | NOT APPLICABLE as written | No server. Play staged rollout covers M21 |
| 7 | Docs | PASS | `app/README.md`: build, test, journey test, release, icon, layout. `ml/README.md` for the models |

### C8. Performance

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1-4 | Web vitals, images, fonts, JS budget | NOT APPLICABLE as written | Mobile equivalents: fonts bundled (2 files); no images beyond the icon; models are small JSON files. Frame timing on a low-end phone not measured (see M14) |

## Track M

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1 | Google Play requirements | BLOCKED | targetSdk 36, 64-bit, 16 KB page alignment verified (`zipalign -c -P 16`). AAB upload, Play App Signing, Data safety and content rating need the owner's Play account |
| 2 | App Store requirements | BLOCKED | No Mac. No `PrivacyInfo.xcprivacy` yet; it must be written and checked with Xcode's privacy report |
| 3 | Account deletion | NOT APPLICABLE | No accounts. "Delete everything on this phone" asks first and is tested |
| 4 | Sign in with Apple | NOT APPLICABLE | No sign-in |
| 5 | Review readiness | BLOCKED | No account is needed to review. Needs the store listing and policy URL |
| 6 | Store listing | BLOCKED | Needs owner text, approved screenshots and icon artwork |
| 7 | Secrets in Keystore | PASS | PIN hash in `flutter_secure_storage` (Keystore-wrapped) |
| 8 | No cleartext traffic | PASS | `usesCleartextTraffic="false"`, no `INTERNET` permission |
| 9 | Obfuscated release | PASS | `flutter build apk --release --obfuscate --split-debug-info=build/symbols` with R8 code and resource shrinking (`android/app/build.gradle.kts`); built 20 Nov 2026 |
| 10 | Deep links | NOT APPLICABLE | None |
| 11 | Permissions only when needed | PASS | Release APK holds only `POST_NOTIFICATIONS`, `USE_BIOMETRIC` and the system's own receiver permission; notifications asked when a reminder is switched on; the app works with both denied |
| 12 | Signing keys backed up | BLOCKED | Signed with the debug key; the owner must create and hold the upload key |
| 13 | Crash reporting | NOT APPLICABLE | No network; see C7.1 |
| 14 | Device matrix | BLOCKED | Android 16 emulator only, at 360 x 780 and 390 x 844 in tests, light and dark, text scale to 2.0, TalkBack. A low-end Android phone and an iPhone have not been used. The owner's Pixel was not used for installs |
| 15 | Offline behaviour | PASS | The app never uses the network |
| 16 | Safe areas and keyboard | PASS | Screens use `SafeArea`; the journey test types into Add and reaches Save with the keyboard up on the emulator |
| 17 | Icon, splash, name | PASS (Android) / BLOCKED (iOS check) | Final mark from `lib/core/brand/akatabo_mark.dart`. Adaptive, monochrome and legacy icons, notification icon, Android 12+ and older splash in light and dark. Seen on the Pixel 8 Pro 24 Nov: launcher icon, splash light and dark, Home logo light and dark. Logo also on the About licence screen, the PDF report header (PNG, unit-tested) and notification large icon (not yet seen on device). iOS icon and light/dark launch screen generated (`test/core/ios_launch_test.dart`), not seen without a Mac. Themed icon and status-bar icon not yet seen on a device |
| 18 | Forced update path | NOT APPLICABLE | Needs a network check; owner decision |
| 19 | Notifications at a meaningful moment | PASS | Permission asked only when a reminder is switched on (phase 5 tests) |
| 20 | Versioning | MISSING | `0.1.0+1`; no "What's new" text yet |
| 21 | Staged rollout | BLOCKED | Needs the Play account |
| 22 | App size | PASS (watch) | Release APK 66.4 MB holding three ABIs, after R8 shrinking. An AAB would deliver one ABI per phone; not built yet |
