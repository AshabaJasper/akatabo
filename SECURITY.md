# Security policy

Akatabo stores a person's money records on their phone only. It has no network code, no accounts and no server. The main security concerns are on the device: the app lock (PIN and biometrics), the encrypted backup files, data that leaks through notifications, exports or the app switcher, and the permissions the APK asks for.

## Supported versions

Security fixes go into the latest release only. Please update to the latest version before you report a problem.

## Reporting a vulnerability

**Do not open a public issue for a security problem.**

Report it privately with GitHub's private vulnerability reporting:

1. Go to the repository's **Security** tab.
2. Select **Report a vulnerability**.
3. Describe the problem, the version and device you used, and the steps to reproduce it.

Only the maintainers can see the report. Do not include real financial records. Use sample entries to show the problem.

## What happens next

- We aim to acknowledge a report within 7 days.
- We will tell you whether we can reproduce it, and keep you informed as we fix it.
- When a fix is released, we publish an advisory. We credit you by name unless you ask us not to.

Please give us reasonable time to release a fix before you disclose the problem publicly.

## In scope

- Getting past the app lock, or reading entries without unlocking.
- Reading or changing a backup file without its password, or weaknesses in how backups are encrypted.
- Private data shown in notifications, exports, logs, the screenshot preview or the app switcher.
- Any network access, or any permission beyond notifications and biometrics.

## Out of scope

- Attacks that need a rooted phone, or an attacker who already knows the PIN or the backup password.
- Problems in Android itself or in a third-party package. Please report those to their own maintainers, and tell us if Akatabo needs a change.
