# Contributing to Akatabo

Thank you for helping. Akatabo is a free, offline money tracker for Uganda. Everything stays on the phone: the app has no network code, and the release APK does not ask for the `INTERNET` permission. Please keep it that way.

By taking part you agree to the [Code of Conduct](CODE_OF_CONDUCT.md). To report a security problem, follow [SECURITY.md](SECURITY.md) instead of opening an issue.

## Licence of contributions

Akatabo is licensed under the GNU General Public License, version 3 only (`GPL-3.0-only`, see [LICENSE](LICENSE)). When you send a pull request, you agree that your contribution is released under the same licence. Add only code, fonts, images and data that you wrote yourself or that come under a licence compatible with GPL-3.0, and say where third-party material came from in the pull request.

## What you need

- Flutter **3.50.0** stable (Dart 3.14.0). CI uses this exact version. Other versions may change goldens or analyzer results.
- JDK 17 and the Android SDK with platforms 36 and 37 (`compileSdk` is 37).
- Python 3.13 only if you change the on-device models in `ml/`.

## Build and run

The Flutter app is in `app/`. Run these from that folder:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

To see the app with sample entries, run a debug build with `--dart-define=AKATABO_DEMO=true`. Release builds never add sample data.

A release build, and the check that it asks only for notifications and biometrics:

```powershell
flutter build apk --release --obfuscate --split-debug-info=build/symbols
pwsh tool/check_permissions.ps1
```

## Tests

- `flutter analyze` must report no issues.
- `flutter test` runs the unit, widget, golden and accessibility tests.
- `flutter test integration_test -d <device>` runs the whole journey on an emulator or phone. It uses an in-memory database and leaves nothing on the device.
- Add a test with each fix or feature. A bug fix comes with a test that fails without the fix.

### Golden tests are Windows-only

Golden images (`test/**/goldens/*.png`) are made on Windows, and they only match on Windows because font rendering differs on Linux and macOS. On other systems, run the tests with goldens switched off:

```bash
AKATABO_SKIP_GOLDENS=1 flutter test
```

All other checks in those tests still run. CI runs the full suite with goldens on `windows-latest`.

If your change alters a screen on purpose, regenerate its goldens on Windows and commit the new images with the change:

```powershell
flutter test --update-goldens test/features/<area>/<file>_test.dart
```

Look at each changed image before you commit it, and name the updated goldens in the commit message. When a golden fails, Flutter writes the difference images to `failures/` folders, which git ignores.

## Design tokens: no hard-coded values

`design/tokens.json` is the only source of every colour, text style, spacing step, radius and component size. Screens read these values through the theme (`AkColors`, `AkType`, `AkMetrics`). Do not type a colour, font size or spacing value directly in a widget.

To add or change a value:

1. Edit `design/tokens.json` and give the token a `note` that says where it is used.
2. Regenerate the Dart from the `app/` folder:

   ```powershell
   dart run tool/gen_tokens.dart
   dart run tool/gen_icons.dart
   ```

3. Commit `design/tokens.json` and the regenerated `lib/core/theme/tokens.g.dart` (or `icon_registry.g.dart`) together. `test/core/generated_test.dart` fails if a generated file does not match its source.

`test/core/theme_contrast_test.dart` checks text and background token pairs for WCAG AA contrast in light and dark. A new pair must pass it.

## Generated code

Drift tables and Riverpod providers are generated, and the generated files are committed. After you change a table or a provider, run this from `app/`:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## On-device models

The four models in `app/assets/smart/` are exported from the Python code in `ml/`, trained on synthetic data only. See [ml/README.md](ml/README.md). Each export also writes parity vectors to `app/test/smart/fixtures/`, and the Dart tests require the same outputs as Python. If you change a model, rerun its export and commit the artefact and the vectors together.

## Privacy rules

- No network access, analytics, crash reporting, ads or tracking. Do not add a package that needs `INTERNET` or Google Play Services.
- Do not add a dependency under a licence that is not compatible with GPL-3.0. Name the package and its licence in the pull request.
- Real financial records never go into tests, fixtures or issues. Use the synthetic data generators.

## Commit messages

Write one plain sentence that says what changed, in the present tense. Start with the area when it helps, for example:

```text
Accounts: Edit account and Delete, refused while entries use it
Forecast: How close it has been, and the today point's one pulse
```

Name any goldens you updated, for example `Golden appearance_light/dark updated`. Keep each commit to one change, and do not mix formatting with behaviour changes.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Make the change with its tests.
3. Run `flutter analyze` and `flutter test` (with goldens on Windows, or `AKATABO_SKIP_GOLDENS=1` elsewhere).
4. Open the pull request and fill in the template. CI must pass before review.

For a large change, open an issue first so we can agree on the approach before you spend time on it.
