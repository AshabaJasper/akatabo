# Akatabo app

The Flutter app for Akatabo, the offline money tracker described in `../README.md` and `../PLAN.md`. Android first; the iOS project is in place but has not been built (no Mac).

## Requirements

- Flutter 3.50 stable (Dart 3.14), JDK 17, Android SDK platforms 36 and 37.
- Python 3.13 only for the models in `../ml/`.

## Everyday commands

Run from this folder.

```powershell
flutter pub get
flutter analyze
flutter test
```

`flutter test` runs the unit, widget, golden and accessibility tests. Goldens are made on Windows and only match there.

Code generation (drift tables, Riverpod providers):

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Design tokens and icons are generated from `../design/`:

```powershell
dart run tool/gen_tokens.dart
dart run tool/gen_icons.dart
```

## The whole app on a device

The journey test unlocks with a PIN, adds three entries, sets a budget, backs up, deletes everything and restores. It uses an in-memory database and fake file dialogs, so it leaves nothing on the device. Run it on an emulator:

```powershell
flutter test integration_test -d emulator-5554
```

To see the app with sample entries, run a debug build with `--dart-define=AKATABO_DEMO=true`. Release builds never add sample data.

## Release build

```powershell
flutter build apk --release --obfuscate --split-debug-info=build/symbols
pwsh tool/check_permissions.ps1
```

The release build shrinks code and resources with R8. Keep `build/symbols` for each release: it is needed to read an obfuscated stack trace. The permission script fails if the APK asks for anything beyond notifications and biometrics (no `INTERNET`).

The release is signed with the debug key until the owner creates an upload key. Store the key and its passwords off this computer.

## App icon

The icon is provisional. `tool/render_icon_test.dart` draws it from the tokens, then `flutter_launcher_icons` writes the Android and iOS sizes:

```powershell
flutter test tool/render_icon_test.dart
dart run flutter_launcher_icons
```

Replace `assets/icon/*.png` with the final artwork and run the second command.

## Where things are

| Path | What it holds |
| --- | --- |
| `lib/domain/`, `lib/smart/` | Every calculation and the four on-device models. No Flutter imports. |
| `lib/data/` | drift database, repositories, typed settings, default data |
| `lib/features/` | One folder per screen or group of screens |
| `lib/widgets/` | Shared controls, charts and messages, the month grid and the date and time dialogs (`ak_month_grid.dart`, `ak_pickers.dart`) |
| `lib/core/theme/` | Generated tokens (`tokens.g.dart`), the theme, motion timing (`ak_motion.dart`) and still page transitions |
| `lib/services/` | Backup and restore, export, notifications, PIN and biometrics |
| `assets/smart/` | Model files exported from `../ml/` |
| `drift_schemas/` | Database schema snapshots for migrations |

## Data and backups

Everything stays in the app's private folder. Android cloud backup is switched off. People back up with "Save a backup file now" (an `.akatabo` file, optionally protected with a password) and restore it from Settings, Privacy and data.
