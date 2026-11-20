# Handoff

Where Akatabo stands, for the next working session. Written 21 November 2026.

## State

- Branch `main`, pushed to a private GitHub repository. The 14 local `worktree-agent-*` branches were never pushed and are not needed.
- Phases 1 to 8 of `PLAN.md` are done, plus a polish round after the owner tried the app on a Pixel 8 Pro (see the last section of `PROGRESS.md` and the "Polish round" entry in `PLAN.md`'s decision log).
- `flutter analyze` is clean and `flutter test` passes (1,069 tests). Goldens are made on Windows and only match there.
- Not published. The launch blockers that need the owner are at the top of `SHIP_GATE.md`.

## How to run

From `app/`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
flutter test integration_test -d emulator-5554
```

Before each commit: `dart format lib test`, `flutter analyze`, `flutter test`, then a bug review (score each bug frequency x severity; fix 5 or more with a test, file the rest in `docs/BUGS.md`). Update a golden only when its picture is meant to change, with `flutter test --update-goldens <file>`, and name it in the commit.

Rules that tests enforce: screens use tokens only (`design/tokens.json`, then `dart run tool/gen_tokens.dart`); no Material icon font, so icons are `AkIcons` vectors; `material_ui`, not `material.dart`.

## Next: drawn pieces the app still lacks

Each follows its design file in `design/screens/` in both themes, with figures from `lib/domain/`.

| Piece | Design | Where |
|---|---|---|
| Edit a transaction, and "Add one like this" | TransactionDetail.html | `transaction_detail_screen.dart`; Add gains an edit mode (`Routes.add?edit=id`, `?like=id`) and the repository an `update` that keeps the id and moves `updatedAt` |
| Home: "Left in budgets" tile, tappable Fees and Budgets tiles, Where it went "See all" | Main.html | `home_screen.dart` (`_StatTile`, `_WhereItWent`) |
| Home settings: Forecast card and Budgets at a glance switches | SetAppearance.html | `home_settings_screen.dart`, `home_layout.dart` |
| Fees: six-month stacked chart | Fees.html | `fees_screen.dart`, a new chart in `widgets/charts/` |
| Forecast: "How close it has been" | Forecast.html | `forecast_screen.dart`, reading `forecast_snapshots`; a month with no snapshot shows nothing |
| Coming up: bubble timeline, "Remind me the day before" | Upcoming.html | `regular_payments_screen.dart`, the notifications service |
| Categories: "Day by day" strip | Categories.html | `categories_screen.dart` |
| Appearance "Category colours", "The app opens on"; General "Date style", "How amounts are written" | SetAppearance.html, SetGeneral.html | the settings screens, typed setting keys, the formatters |
| Forecast today-point pulse (once; still under reduced motion, use `AkMotion`) | the motion rule in `DESIGN_SYSTEM.md` | the trend painter in `widgets/charts/` |
| Edit and delete an account (confirm first; refuse delete while entries use it, offer hide) | undrawn, from the rules | `accounts_settings_screen.dart` |

Also: remove the unused `PlaceholderScreen`, and replace the wrong "arrives in a later update" note in `smart_settings_screen.dart` (and its test).

## Still to check on a device

Nothing from the polish round has been seen on the Pixel 8 Pro yet: Home's first day, empty Budgets, Settings, App lock, the PIN keypad, Add (scrolled, and Move money), the date dialog and a segmented control, in light and dark. Rerun the journey test on the emulator too.

## Needs the owner

Signing key, Play developer account, privacy policy facts and contact (also for "Send feedback"), final icon artwork, store listing, and a Mac for iOS. See `SHIP_GATE.md`.
