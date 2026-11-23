# Handoff

Where Akatabo stands, for the next working session. Written 23 November 2026.

## State

- Branch `main`, pushed to a private GitHub repository. The 14 local `worktree-agent-*` branches were never pushed and are not needed.
- Phases 1 to 8 of `PLAN.md` are done. The polish round after the owner tried the app on a Pixel 8 Pro is done too, including stage 4: every piece drawn in `design/screens/` is now built. See the last sections of `PROGRESS.md` and the polish round entries in the decision log of `PLAN.md`.
- `flutter analyze` is clean and `flutter test` passes. Goldens are made on Windows and only match there.
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

Before each commit, run `dart format lib test`, then `flutter analyze`, then `flutter test`. Then do a bug review: score each bug frequency x severity, fix 5 or more with a test, and file the rest in `docs/BUGS.md`. Update a golden only when its picture is meant to change, with `flutter test --update-goldens <file>`, and name it in the commit.

Tests enforce these rules:

- Screens use tokens only (`design/tokens.json`, then `dart run tool/gen_tokens.dart`).
- There is no Material icon font, so icons are `AkIcons` vectors.
- Code uses `material_ui`, not `material.dart`.
- App-level widget tests override every provider that reaches the database. A live drift stream never settles under the test clock, and `path_provider` has no plugin in tests.

## Next

1. **Light mode on the device.** The Pixel 8 Pro (`3B161FDJG002MD`) check on 23 November covered every stage 4 screen in dark, but only Home, Fees and Categories in light. Still to see in light: settings screens, Add, Budgets, Coming up and the PIN keypad. The journey test passes on the Pixel: `flutter test integration_test -d 3B161FDJG002MD`.
2. **Design check** for the undrawn pieces: Edit account and Delete, the "Start" card on Home screen settings, and the Date style choice list.
3. **Small filed bugs** in `docs/BUGS.md`.

## Needs the owner

These need the owner:

- signing key
- Play developer account
- privacy policy facts and a contact (also for "Send feedback")
- final icon artwork
- store listing
- a Mac for iOS

See `SHIP_GATE.md`.
