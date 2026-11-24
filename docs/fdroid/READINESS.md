# F-Droid readiness audit

Audited on 24 November 2026 against commit `9108b05` (`main`). Package `com.persmon.akatabo`, version `0.1.0+1`, Flutter 3.50.0 stable (Dart 3.14.0). The draft metadata is in [com.persmon.akatabo.yml](com.persmon.akatabo.yml).

**Summary.** Every package is under a free licence that is compatible with GPL-3.0. No package uses Google Play Services, Firebase, Play Core or another proprietary SDK, and the bundled models rebuild from `ml/` byte for byte. **One technical blocker:** `package:sqlite3` 3.9.1 (through `drift_flutter`) downloads a prebuilt `libsqlite3.so` from GitHub during the build, which F-Droid does not accept (section 2a). The other blockers are owner steps: making the repo public, the `v0.2.0` tag and release signing. Three checks can only run on an F-Droid build server (see "To verify on a build server").

## 1. Dependency licences

**How this was checked:** I parsed every package in `app/pubspec.lock` (165 entries: 36 direct, counting the Flutter SDK packages, and 129 transitive), read the `LICENSE` file in the matching pub cache folder, and classified it by its text. No package was missing a licence file and none were unclassified.

| Licence | Packages |
| --- | --- |
| BSD-3-Clause | 117 |
| MIT | 28 |
| Apache-2.0 | 9 |
| BSD-2-Clause | 2 |
| MPL-2.0 | 1 (`dbus` 0.8.1, transitive) |
| Flutter SDK (BSD-3-Clause) | 8 (`flutter`, `flutter_test`, `integration_test`, `flutter_localizations`, `flutter_web_plugins`, `flutter_driver`, `fuchsia_remote_debug_protocol`, `sky_engine`) |

All of these are GPL-3.0-compatible. Apache-2.0 is compatible with GPL-3.0 (not with GPL-2.0-only). MPL-2.0 is compatible through its section 3.3. `dbus` is only used on Linux desktop (by `package_info_plus` and `share_plus`) and is not compiled into the Android APK.

### Direct dependencies

| Package | Version | Licence | Notes |
| --- | --- | --- | --- |
| `material_ui` | 1.11.1 | BSD-3-Clause | Published by the Flutter team from `flutter/packages`, the same licence as Flutter. Its dependencies (`cupertino_ui`, `material_color_utilities`, `vector_math`, `intl`, `collection`) are BSD-3-Clause, except `material_color_utilities`, which is Apache-2.0. Not proprietary. |
| `flutter_riverpod` | 3.5.0 | MIT | |
| `riverpod_annotation` | 4.0.8 | MIT | |
| `drift` | 2.35.4 | MIT | |
| `drift_flutter` | 0.3.1 | MIT | Pulls `sqlite3` 3.9.1 (MIT) and `sqlite3_flutter_libs` 0.6.0+eol (MIT). SQLite itself is public domain. **`sqlite3` downloads a prebuilt native library by default: see section 2a.** |
| `path_provider` | 2.1.6 | BSD-3-Clause | On Android it pulls `jni` and `jni_flutter` (BSD-3-Clause, C code built with the NDK). |
| `path` | 1.9.1 | BSD-3-Clause | |
| `collection` | 1.19.1 | BSD-3-Clause | |
| `uuid` | 4.6.0 | MIT | |
| `clock` | 1.1.3 | Apache-2.0 | |
| `intl` | 0.20.3 | BSD-3-Clause | |
| `go_router` | 18.1.4 | BSD-3-Clause | |
| `fl_chart` | 1.3.1 | MIT | |
| `path_parsing` | 1.1.0 | MIT | |
| `local_auth` | 3.0.2 | BSD-3-Clause | Android side uses `androidx.biometric` (Apache-2.0). No Play Services. |
| `flutter_secure_storage` | 11.2.0 | BSD-3-Clause | Android side uses `com.google.crypto.tink:tink-android` 1.23.0 (Apache-2.0, open source). |
| `flutter_local_notifications` | 23.0.3 | BSD-3-Clause | Android side uses `androidx.core`, `androidx.media` and `gson` (all Apache-2.0). |
| `timezone` | 0.11.2 | BSD-2-Clause | Ships the IANA tz database (public domain). |
| `flutter_timezone` | 5.1.1 | Apache-2.0 | |
| `flutter_file_dialog` | 3.3.6 | BSD-3-Clause | Android side uses `androidx.documentfile` and kotlinx-coroutines (Apache-2.0). |
| `share_plus` | 13.3.1 | BSD-3-Clause | |
| `pdf` | 3.13.1 | Apache-2.0 | |
| `archive` | 4.7.1 | MIT | |
| `cryptography` | 2.9.0 | Apache-2.0 | Pure Dart. |
| `package_info_plus` | 10.2.2 | BSD-3-Clause | |

Dev dependencies (`build_runner`, `drift_dev`, `riverpod_generator`, `flutter_lints`, `riverpod_lint`, `mocktail`, `fake_async`, `flutter_launcher_icons`) are MIT, BSD-3-Clause or Apache-2.0. None of them ship in the APK.

The app's own Gradle dependencies are `androidx.appcompat:appcompat` 1.8.0 and `com.android.tools:desugar_jdk_libs` 2.1.5 (both Apache-2.0).

### Bundled assets

| Asset | Licence | Notes |
| --- | --- | --- |
| Bricolage Grotesque, Geist (`app/assets/fonts/`) | SIL OFL 1.1 | The licence texts ship as `OFL-*.txt` and are shown on About > Open-source licences (`lib/app/font_licences.dart`). |
| Icons (`lib/core/icons/icon_registry.g.dart`) | Project's own | Generated from the path table in `design/DESIGN_SYSTEM.md`. The repo does not name or mention an outside icon set. |
| Models (`app/assets/smart/*.json`) | Project's own | Trained on synthetic data only; see section 3. |
| App icon (`app/assets/icon/`) | Project's own | The owner's logo pick, drawn in code (`lib/core/brand/akatabo_mark.dart`) and written by `tool/render_brand_test.dart`. Artwork is CC BY-SA 4.0 (`design/brand/README.md`). |

## 2. Proprietary pieces and anti-features

- **Google Play Services, Firebase, Play Core, Crashlytics, ads, analytics:** none. I searched every plugin's `android/` folder in the pub cache for `com.google.android.gms`, `firebase` and `com.google.android.play`, and found no matches. The Gradle dependencies listed above are all open source.
- **Network:** the app has no network code, and `tool/check_permissions.ps1` fails the release APK if it asks for anything beyond `POST_NOTIFICATIONS` and `USE_BIOMETRIC` (plus AndroidX's app-private `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`). So the F-Droid anti-features `Tracking`, `Ads`, `NonFreeNet`, `NonFreeDep` and `NonFreeAdd` do not apply.
- **Prebuilt binaries fetched at build time:** `sqlite3` downloads one; see section 2a. `objective_c` 9.6.4 also has a build hook, but it is for iOS and macOS only and downloads nothing.
- **Prebuilt binaries in the source:** the repository has no `.jar`, `.aar`, `.so`, `.apk` or keystore files (`git ls-files`). The only binary in the pub cache is `jni-1.1.2/java/gradle/wrapper/gradle-wrapper.jar`, which is a build helper and does not ship in the APK. The draft recipe uses `scandelete: .pub-cache` so the scanner does not stop on it.
- **Flutter engine:** F-Droid builds Flutter apps with the Flutter SDK as a srclib (`flutter@3.50.0`) and uses the engine artefacts Google publishes for that tag. F-Droid accepts these for Flutter apps; check the current policy when you open the merge request.

## 2a. Blocker: `package:sqlite3` downloads a prebuilt SQLite

`sqlite3` 3.x bundles SQLite through a Dart build hook (`hook/build.dart`). By default the hook **downloads a precompiled `libsqlite3.so`** for each ABI from the package's GitHub releases and checks it against a sha256 hash (see the package's `doc/hook.md`, "Default binaries" and "Supply-chain security"). The local build confirms it: `app/.dart_tool/hooks_runner/shared/sqlite3/build/` holds four `download-*` folders. `sqlite3_flutter_libs` is marked `+eol` and no longer provides the library.

F-Droid builds everything from source and does not allow prebuilt binaries in the APK, so this has to change before the merge request. The library is open source (MIT wrapper, public-domain SQLite), so IzzyOnDroid and Play are not affected.

**Fix (a code change, not made here):** compile SQLite from source in the hook with the package's `source: source` user define:

```yaml
# app/pubspec.yaml
hooks:
  user_defines:
    sqlite3:
      source: source
      path: third_party/sqlite/sqlite3.c   # the SQLite amalgamation, public domain
```

Then vendor the official amalgamation (`sqlite3.c` and `sqlite3.h` from sqlite.org, about 9 MB, with its version and sha3 noted in a README beside it) into `app/third_party/sqlite/`. The hook then compiles it with the NDK on every build, F-Droid's included. After the change, check that `.dart_tool/hooks_runner/shared/sqlite3/build/` has no new `download-*` folder, run the full test suite (drift's tests run on the host's compiled SQLite) and the journey test on the Pixel, and keep the compile-time options listed in `doc/hook.md` unless there is a reason to change them.

`source: system` is not an option on Android: the platform's own SQLite is a private library that apps cannot load.

## 3. Can `app/assets/smart/` be rebuilt from `ml/`?

**Yes, byte for byte.** I extracted `ml/`, `app/assets/smart/` and `app/test/smart/fixtures/` from `HEAD` into a scratch folder, ran the synthetic data generator and all four exports with the versions pinned in `ml/README.md` (Python 3.13, scikit-learn 1.9.1, numpy 2.5.5, pandas 3.1.1), and compared the results with the committed files:

| File | Result |
| --- | --- |
| `category_model.json` | identical |
| `unusual_params.json` | identical |
| `regular_params.json` | identical |
| `forecast_params.json` | identical |
| `test/smart/fixtures/category_vectors.json` | same keys and values; floats differ only beyond 1e-12 (last-digit rounding), test-only |
| other three fixture files | identical |

The training data is synthetic and seeded (`ml/common/synth.py`), so no private data is involved and anyone can regenerate it.

**Correction for `ml/README.md`:** the documented command `python ml/category/export.py` fails with `ImportError` (the exports use package imports). The form that works, run from the repo root, is:

```bash
PYTHONPATH=ml python -m category.export   # likewise unusual, regular, forecast
```

The F-Droid build does not need to run the Python step: the JSON artefacts are plain-text source that can be reviewed and are reproducible as shown. If the F-Droid reviewers ask, `ml/` can be named as their source in the merge request.

## 4. Build recipe and reproducibility

- `app/pubspec.lock` is committed, and `flutter pub get --enforce-lockfile` fixes every package version and hash.
- Generated Dart (`*.g.dart`) is committed, so the build does not need `build_runner`.
- `compileSdk` 37 and `targetSdk` 36 (Flutter default). Flutter 3.50.0 asks for NDK 28.2.13676358 (r28c) (`FlutterExtension.kt`), and `build.gradle.kts` takes it (`ndkVersion = flutter.ndkVersion`), so `ndk: r28c` in the recipe matches.
- The release `buildType` currently signs with the **debug key** (`app/android/app/build.gradle.kts`). F-Droid signs with its own key, but it expects an **unsigned** APK, so the recipe needs release signing to be skipped when `key.properties` is absent (filed in `docs/BUGS.md`). It does block Play and IzzyOnDroid, and it blocks F-Droid reproducible builds signed by the developer.

## 5. Blockers and owner steps

| Item | Blocks | Owner | Status |
| --- | --- | --- | --- |
| `sqlite3` downloads a prebuilt `libsqlite3.so` (section 2a) | F-Droid | Code change, next session | BLOCKED: vendor the SQLite amalgamation and set `source: source`. |
| Repository is private | F-Droid, IzzyOnDroid | Owner yes | BLOCKED: F-Droid builds only from public source. |
| No release tag (`v0.2.0`) and `versionCode` is still `1` | F-Droid, IzzyOnDroid | Owner yes | BLOCKED: the recipe builds from a tag. Bump `version:` in `pubspec.yaml` to `0.2.0+2` (or whatever is agreed) before tagging. |
| Release signing key (`key.properties`, gitignored) | Play, IzzyOnDroid, developer-signed reproducible F-Droid builds | Owner keystore | BLOCKED: release builds are signed with the debug key. |
| Fastlane metadata (title, descriptions, screenshots, icon) | Store listing quality on all three | Owner: listing text and screenshots | MISSING: no `fastlane/` folder yet. The icon and feature graphic exist in `design/brand/store/`. F-Droid falls back to the merge-request summary, but screenshots are expected. |
| Final app icon | All stores | Done 24 November 2026 | PASS: the owner's logo pick. Themed and status-bar icons not yet seen on a device. |
| `AuthorName` and contact for the metadata | F-Droid listing | Owner | MISSING: left as a comment in the draft. |
| Conduct-report contact in `CODE_OF_CONDUCT.md` | Community files | Owner | Points to the maintainer's GitHub account until the owner names a private channel. |

## To verify on a build server

These can only be confirmed by running `fdroid build` with the draft recipe. They are not known blockers.

1. `fdroid scanner` passes with the `scandelete` and `scanignore` entries in the draft.
2. Two builds of the same tag give the same APK (Flutter AOT builds are usually reproducible when the path and the Flutter version match).
