# Changelog

All notable changes to Akatabo are written here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

The text people see in the stores comes from `fastlane/metadata/android/en-US/changelogs/`, one short file for each version code. This file has the longer account.

## [0.2.0] - Unreleased

The first public release. The app is built for Android; it is not on a store yet.

### Added

- **Goals.** The Budgets tab is now Goals, with a Savings | Budgets switch. Savings goals have a target amount and an optional date, and show progress, the pace needed and when you will reach them at the current pace. Each amount you set aside or take out notes the account the money sits in. A goal can remind you weekly (Sunday evening) or monthly (the 1st, in the morning) with what to put aside to stay on track. Goals appear on Home and in the calendar, and they are in backups and in Delete everything.
- **Payments in other currencies.** Type the amount and the rate you were given. The entry is kept in whole shillings, so totals, budgets and the forecast work as before, and it remembers the amount and rate. A new Currencies and rates page lists the rates you have typed. Backups and CSV exports carry the new columns, and older backup files still restore.
- **A fuller forecast.** The month's forecast now shows a safe amount to spend each day, the pace against the same days last month, each regular payment it is counting, the one-off payments it left out, and how close past forecasts were.
- **A fuller App lock page.** A status card, fingerprint or face unlock where the phone has it (offered automatically on the lock screen, with a PIN fallback), the waiting times after wrong PINs, and Lock now.
- **Reminders and Smart help are two pages.** Each reminder shows when it will next fire, and there is a button to send a test notification and one to open the phone's notification settings.
- **Phone permissions page.** Shows what the phone allows Akatabo, read live, and what the app never asks for.
- **Settings search.** Find a Settings page by its name or a related word.
- **About Akatabo page.** The version, the licence (GPL-3.0), the open-source licences and a button to copy the project link.
- **Set a budget** has a "Carry over what is left" row with its own switch.
- **A new logo and icon set,** including the themed icon, the splash screen and the notification icon.
- **Money colours.** Red for money out and green for money in, with an option in Appearance to switch back to orange and blue.
- **Tablets and foldables.** At 840dp wide or more, the tabs move to a navigation rail with Add at the top, the content is capped and centred, and Home shows the latest entries beside the summary. On a foldable, the fold sets where Home's two panes split, and on a phone half-open like a laptop the tab screens stay on one half. Phones held upright are unchanged.
- **Screenshots** in the README and the store listings, drawn from the real app with made-up entries by a test, so they can be drawn again after a change.

### Changed

- The database moves to version 5 for savings goals. Phones on an earlier version are moved over when the app opens, and nothing is lost.
- If the stored settings cannot be read when the app opens, the lock now decides from the PIN instead of leaving a blank screen.
- Text and rows are one step larger throughout.
- On Add, each problem now shows under the field it is about (the amount, the rate, or the account), clears once that field is fixed, scrolls into view when you tap Save, and is read aloud to screen reader users.

### Open-source release

- The code is licensed under GPL-3.0, with contributor guides, a code of conduct, a security policy and CI. The brand files are licensed under CC BY-SA 4.0.

## [0.1.0] - Never released

The first working build, kept for the record. Money out, money in and moves between accounts with fees and tax; budgets; a month forecast; insights and a calendar; regular payments; PDF, CSV and Excel reports; encrypted backups and restore; an app lock with a PIN; and reminders. It was tested on an emulator and a phone but not published.

[0.2.0]: https://github.com/AshabaJasper/akatabo/releases
[0.1.0]: https://github.com/AshabaJasper/akatabo/commits/main
