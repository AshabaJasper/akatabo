# Akatabo

A free money tracker for Uganda. People add what they spend and receive, and the app shows where the money went, what it cost in fees, how budgets are doing and where the month is heading. No account, no adverts, no phone permissions. All data stays on the phone.

The app is built and runs end to end on Android. It is not published: the launch blockers at the top of `SHIP_GATE.md` need the owner.

## What is in this repository

| Path | What it is |
| --- | --- |
| `app/` | The Flutter app (Android first; iOS not built, no Mac). Start with `app/README.md`. |
| `design/` | The design: `DESIGN_SYSTEM.md` (the rules), `tokens.json` (every colour, type style, size and radius), and one HTML file per screen in `design/screens/`. Open `design/index.html` for the gallery. |
| `ml/` | The four on-device models (category suggestion, forecast, unusual payments, regular payments): training, parity tests and exports into `app/assets/smart/`. |
| `PLAN.md` | The build plan and the decision log, phase by phase. |
| `PROGRESS.md` | What each phase delivered, what was tested and what was not. |
| `SHIP_GATE.md` | The launch checklist (Mobile app: Core + M), with evidence per item and the launch blockers. |
| `PRODUCT.md` | Who the app is for and how it should feel. |
| `docs/BUGS.md` | Open bugs below the fix threshold, with how to trigger each, and the fixed ones. |
| `docs/HANDOFF.md` | Where the work stands and what is next. Read this first in a new session. |
| `CLAUDE_CODE_PROMPT.md` | The prompt that started the build. |

## Quick start

```powershell
cd app
flutter pub get
flutter analyze
flutter test
flutter run
```

Requirements, the journey test, release builds and the icon are in `app/README.md`.

## Things to know

- Every figure in the design files is sample data. Nothing in the app is hard-coded; sample entries appear only in a debug build run with `--dart-define=AKATABO_DEMO=true`.
- Screens use design tokens only. Colours, sizes, radii and type come from `design/tokens.json` through `dart run tool/gen_tokens.dart`; a test fails if a screen types a colour or size.
- The app bundles no Material icon font. Every icon is a vector in `AkIcons`, so stock widgets that draw `Icons.*` glyphs (the stock date picker among them) are not used.
- "Akatabo" is meant as Luganda for "little book". Confirm the meaning and that the name is free in the app stores.
