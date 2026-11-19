# Prompt for Claude Code

Open this folder (`akatabo`) in Claude Code and paste everything below the line.

---

You are building Akatabo, a free personal money tracker for people in Uganda, as a Flutter app for Android first and iOS second. I am the owner and I want it finished to a standard I can publish and show as a capstone project covering app development, data visualisation and on-device machine learning.

## Read these before writing any code

1. `README.md` in this folder.
2. `design/DESIGN_SYSTEM.md`, all of it. It is the source of truth for colours, type, icons, charts, settings, the data model, how every number is worked out, which states must exist, and what is not designed yet. Where a screen and this file disagree, this file wins.
3. `design/tokens.json`.
4. Every file in `design/screens/`. Each is one screen as plain HTML with inline styles, so the exact sizes, spacing, colours and copy are in the markup. `Name.html` is the light theme and `NameDark.html` the dark one. `design/index.html` is the gallery.

Then write `PLAN.md` in this folder: the architecture, the folder layout, the packages you chose with one line of reasoning each, and the build phases. Check current stable versions of Flutter and every package before choosing; do not rely on memory for version numbers.

## Decisions already made

- Flutter and Dart, in a `app/` folder beside `design/`. One codebase, Android first.
- No backend, no account, no analytics, no adverts, no network calls at runtime. All data lives in a local SQLite database on the phone. Bundle the two fonts (Bricolage Grotesque and Geist) as assets; do not fetch them at runtime.
- No phone permissions except notifications and biometrics, both asked for only when the person switches that feature on. Never request SMS, contacts, location or storage-wide access.
- All money is whole shillings stored as integers.
- Light and dark themes, both built from `tokens.json` only. No colour, size or radius may be typed into a screen; everything comes from the theme.
- Icons are drawn from the path table in `DESIGN_SYSTEM.md` through one icon widget. No icon font, no emoji.
- Charts must match the designs. Use a chart package where it can match exactly, and custom painting where it cannot.
- Every figure on the design screens is sample data. Nothing may be hard-coded; every number on screen comes from the database or a model.

## The four models, all on the phone

1. Category suggestion: from the description, amount and the person's own past choices. A correction by the person must take effect on their next similar entry.
2. Month-end forecast with a likely range, exactly as defined in `DESIGN_SYSTEM.md`.
3. Unusual-payment flag, using amount, time of day and whether the payee is new.
4. Regular-payment detection from repeating entries.

Put model training and evaluation in a `ml/` folder as Python notebooks or scripts, with the trained artefacts exported in a form the app runs on the device without a server. For each model write down, in `ml/README.md`, the method, the data it was evaluated on, and the measured result. There is no labelled dataset yet: build a small synthetic seed set of realistic Ugandan transaction descriptions, label it clearly as synthetic, and never present a number measured on it as a real-world result. Tell me what real data you need from me to evaluate properly.

## Build order

Follow the "Screens" section of `DESIGN_SYSTEM.md`:

1. Foundation: project, theme from tokens, fonts, icon widget, database and data model, the five-tab shell, seed data for development only.
2. Core loop: Onboarding, Welcome, Home (empty and filled), Add a transaction, All transactions, One transaction, Calendar.
3. Understanding: Insights, Categories, Inside a category, Fees and tax, Forecast, Regular payments.
4. Planning: Budgets, Set a budget.
5. Customising: every Settings page, Edit a category, New account, Money-in categories, Filters, Choose dates.
6. Keeping data safe: PIN and biometric lock, Export (CSV, Excel, PDF), backup file with optional password, Restore with preview.
7. The four models, wired into the screens that show their results.
8. Finish: empty states, validation, confirmations, error states, accessibility (44px targets, contrast, screen-reader labels, text scaling), and release preparation.

## How to work

- Work through the phases on your own without asking me to approve each step. Make routine decisions yourself and record them in `PLAN.md`.
- Stop and ask me only for: anything that costs money, creating accounts, publishing or uploading anything, signing keys, and any change to the decisions listed above.
- After each phase: run the analyser and the tests, fix what fails, commit with a clear message, and write three lines in `PROGRESS.md` saying what works, what was tested and what was not.
- Write unit tests for every rule in "Rules for the numbers" in `DESIGN_SYSTEM.md`, and widget tests for Add a transaction, because it is the screen people use most. Saving a transaction must take an amount, a few words and one tap on a category.
- Compare each screen you build against its HTML file in both themes before calling it done, and list any difference you chose to keep.
- If something in the design is missing or contradicts itself, build the most sensible version from the rules, mark it in `PROGRESS.md` for a design check, and carry on.
- Do not invent facts about me, the product or its users. A missing fact is a question for me.

Start by reading the files listed above and writing `PLAN.md`. Then begin phase 1.
