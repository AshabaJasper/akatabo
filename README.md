# Akatabo

A free money tracker for Uganda. People add what they spend and receive, and the app shows where the money went, what it cost in fees, how budgets are doing and where the month is heading. No account, no adverts, no phone permissions. All data stays on the phone.

This folder is the starting point for building the app. Right now it holds the design only. The code goes in here too, beside `design/`.

## What is in this folder

| Path | What it is |
| --- | --- |
| `CLAUDE_CODE_PROMPT.md` | The prompt to give Claude Code to start the build. |
| `design/DESIGN_SYSTEM.md` | The rules: colours, type, icons, charts, settings, the data model, how every number is worked out, and the handoff checklist. Read this first. |
| `design/tokens.json` | Every colour (light and dark), text style, spacing step and corner radius, by name. |
| `design/index.html` | A gallery of all 34 screens in the light theme. Open it in a browser. |
| `design/index-dark.html` | The same 34 screens in the dark theme. |
| `design/screens/` | One HTML file per screen. `Main.html` is Home in light; `MainDark.html` is Home in dark. Links between screens work. |

## How to look at the design

Double-click `design/index.html`. Click any screen to open it full size, then use the links and buttons inside it to move around. The fonts load from Google Fonts, so the first time you need to be online.

The screens are still pictures of the app, not the app: buttons that change something on the same screen (the calendar's Day, Week, Month switch, the onboarding Next button, the PIN keypad) do not respond here. Each file shows that screen's starting state.

## Things to know before building

- Every figure on the screens is sample data. Nothing in the real app may be hard-coded.
- "Akatabo" is meant as Luganda for "little book". Confirm the meaning and that the name is free in the app stores.
- Not drawn yet: the "Forgot your PIN" flow, the time and day pickers behind value rows in Settings, and confirmation dialogs. Build them from the rules in `DESIGN_SYSTEM.md`.
- The dark screens were produced by mapping each light colour to its dark token, so check them by eye as they are built.
