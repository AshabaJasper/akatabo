# Ship gate checklist: Akatabo

**Type: Mobile app (Core + M).** Track W (website) and Track A (web app) are NOT APPLICABLE: there is no website, no sign-in and no server.

Checklist from `~/.claude/ship-gate.md`. Status is PASS, MISSING (not done yet), BLOCKED (needs something from the owner or a Mac) or NOT APPLICABLE (with the reason). Evidence names a file, test or observed result. Last updated 19 November 2026, end of phase 1.

## Core

### C1. Design quality

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1 | Impeccable used for UI work | PASS (phase 1) | Loaded before the theme, widgets and shell; `PRODUCT.md` written from the design files |
| 2 | No one-sided accent stripes | PASS (phase 1) | None in `lib/`; the design has none |
| 3 | No generic template tells | PASS (phase 1) | Owner's own design system, two bundled families, one icon set |
| 4 | Real content, no fake figures | MISSING | No screen shows a figure yet. Rule: every number from the database or a model |
| 5 | Consistent system | PASS (phase 1) | `tokens.json` generates `tokens.g.dart`; `test/core/no_literals_test.dart` bans typed colours, sizes and radii |
| 6 | Text fills its space | MISSING | The browser script does not apply to Flutter; checked with widget tests and device screenshots per screen from phase 2 |

### C2. Accessibility

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1 | Native roles, one heading per screen | MISSING | Shell items carry button and selected semantics; screens from phase 2 |
| 2 | Switch and keyboard access, visible focus | MISSING | Phase 8 pass |
| 3 | Contrast 4.5:1 / 3:1 | PASS (tokens) | `tools/design/update_tokens.py` checks every brand pair in both themes and all six main colours |
| 4 | Touch targets | PASS (shell) | `test/app/shell_test.dart` runs `androidTapTargetGuideline` (48dp) and `labeledTapTargetGuideline` |
| 5 | Labels for icons | PASS (shell) | Icons are excluded from semantics unless labelled; nav and Add disc have names |
| 6 | Forms: visible labels, errors tied to fields | MISSING | `AkTextField` has a visible label and `errorText`; Add is phase 2 |
| 7 | Reduced motion, text scaling | MISSING | `AkSwitch` honours reduced motion; scale 1.3 and 2.0 tests in phase 8 |
| 8 | TalkBack pass | MISSING | Phase 8 on the emulator |

### C3. Security (MASVS for mobile)

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1-6 | HTTPS, headers, cookies, server banners, security.txt | NOT APPLICABLE | No server and no network calls. The APK has no `INTERNET` permission (`tool/check_permissions.ps1`) |
| 7 | Validate input | PASS (data layer) | `TransactionDraft.problems()`; database CHECK constraints on amount, fee and tax (`test/data/database_test.dart`) |
| 8 | Parameterised queries | PASS | drift builds every query; no string SQL besides `PRAGMA foreign_keys` |
| 9-11 | CSRF, CORS, SSRF | NOT APPLICABLE | No server |
| 12 | Uploads | NOT APPLICABLE | Nothing is uploaded. Backup files are read locally in phase 6 |
| 13 | Minimum personal data, encrypted at rest | MISSING | Data stays in the app sandbox; Android backup off. PIN and backup encryption in phase 6. The database itself is not encrypted (see PLAN.md) |
| 14 | No secrets in the repo or binary | PASS | The app has no keys or tokens |
| 15 | Lockfile, no known high vulnerabilities | MISSING | `pubspec.lock` committed; `flutter pub outdated` review in phase 8 |
| 16 | Third-party scripts | NOT APPLICABLE | No web content |
| 17 | Least-privilege keys | NOT APPLICABLE | No backend |
| 18 | Rate limits | NOT APPLICABLE as written; PIN attempts get growing delays in phase 6 |
| 19 | Automated scan | MISSING | MobSF or equivalent static scan of the release APK in phase 8 |

### C4. Privacy and legal

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1 | Privacy policy | BLOCKED | Needs the operator's name, contact and a hosted URL from the owner |
| 2 | Terms | BLOCKED | Owner decision |
| 3 | Jurisdiction | MISSING | Uganda Data Protection and Privacy Act 2019 applies to the operator; whether PDPO registration is needed when no data leaves the phone is a question for the owner |
| 4 | Cookies and embeds | NOT APPLICABLE | None |
| 5 | Analytics | NOT APPLICABLE | Owner decision: no analytics |

### C5. States and feedback

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1-5 | Loading, form errors, empty states, toasts, offline | MISSING | Built with each screen from phase 2; offline is the normal state |

### C6. Backend and uploads

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1-5 | Store first, idempotency, timeouts, health endpoint, uploads | NOT APPLICABLE | No backend |
| 6 | Versioned migrations | PASS (scaffold) | `drift_schemas/akatabo/drift_schema_v1.json` from `drift_dev make-migrations`; steps and generated tests from version 2 |

### C7. Operations

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1 | Monitoring and crash reporting | NOT APPLICABLE | Conflicts with "no network calls"; recorded as an owner decision |
| 2 | Email | NOT APPLICABLE | No email |
| 3 | Backups | MISSING | In-app backup and restore in phase 6 |
| 4 | Real-network testing | NOT APPLICABLE | No network |
| 5-6 | Environments, rollback | NOT APPLICABLE as written; Play staged rollout covers M21 |
| 7 | Docs | MISSING | README for building the app in phase 8 |

### C8. Performance

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1-4 | Web vitals, images, fonts, JS budget | NOT APPLICABLE as written | Mobile equivalents: fonts bundled (2 files, 578 KB); frame timing checked in phase 8 |

## Track M

| # | Item | Status | Evidence or reason |
|---|---|---|---|
| 1 | Google Play requirements | MISSING | targetSdk 36 set; AAB, Play App Signing and Data safety need the owner's Play account (BLOCKED) |
| 2 | App Store requirements | BLOCKED | No Mac for an iOS build |
| 3 | Account deletion | NOT APPLICABLE | No accounts. "Delete everything" is in phase 6 |
| 4 | Sign in with Apple | NOT APPLICABLE | No sign-in |
| 5 | Review readiness | MISSING | Phase 8 |
| 6 | Store listing | BLOCKED | Needs owner text, screenshots approval and icon artwork |
| 7 | Secrets in Keystore | MISSING | PIN hash goes in `flutter_secure_storage` in phase 6 |
| 8 | No cleartext traffic | PASS | `usesCleartextTraffic="false"`, no `INTERNET` permission |
| 9 | Obfuscated release | MISSING | Phase 8 build with `--obfuscate --split-debug-info` |
| 10 | Deep links | NOT APPLICABLE | None |
| 11 | Permissions only when needed | PASS (manifest) | Only `POST_NOTIFICATIONS` and `USE_BIOMETRIC`; asked when switched on, from phase 5 |
| 12 | Signing keys backed up | BLOCKED | Release is signed with the debug key; the owner must create and hold the upload key |
| 13 | Crash reporting | NOT APPLICABLE | No network; see C7.1 |
| 14 | Device matrix | MISSING | Android 16 emulator only so far; low-end phone and iPhone BLOCKED |
| 15 | Offline behaviour | PASS by design | The app never uses the network |
| 16 | Safe areas and keyboard | MISSING | Shell uses SafeArea; checked per screen |
| 17 | Icon, splash, name | MISSING | Name "Akatabo" set; icon artwork BLOCKED |
| 18 | Forced update path | NOT APPLICABLE | Needs a network check; owner decision |
| 19 | Notifications at a meaningful moment | MISSING | Asked only when a reminder is switched on (phase 5) |
| 20 | Versioning | MISSING | `0.1.0+1` |
| 21 | Staged rollout | BLOCKED | Needs the Play account |
| 22 | App size | MISSING | Release APK 47.7 MB before shrinking; phase 8 |
