# Akatabo: product context

Written on 19 November 2026 from `README.md` and `design/DESIGN_SYSTEM.md` only. No interview was held: the owner's brief limits questions to money, accounts, publishing, signing keys and changes to their decisions. Lines marked **(assumed)** are my reading of those two files and need the owner's check.

## What it is

A free money tracker for Uganda. People add what they spend and receive across cash, MTN MoMo, Airtel Money and bank, and the app shows where the money went, what it cost in fees, how budgets are doing and where the month is heading.

## Who it is for

Someone who uses mobile money every day and has never used a finance app (DESIGN_SYSTEM.md, Principles 4). Amounts are in UGX.

**(assumed)** They use an Android phone first, often a mid-range one, and may be offline for long stretches. Nothing in the design depends on a connection.

## What it promises

- Free. No account, no adverts, no phone permissions beyond notifications and fingerprint unlock, each asked only when the person switches it on.
- All data stays on the phone. Nothing is uploaded. Losing the phone without a backup loses the data, and the app says so once.
- Adding a transaction is the main action: an amount and a few words are enough.
- Every prediction is shown with its evidence and can be corrected. The app calls this "Smart help" and never says "model".

## Surface and mode

- Platform: native mobile (Flutter), Android first, iOS second.
- Impeccable mode: **Operate**. The person completes a task (add, check, plan). Scanability, consistency and native expectations outrank expression.
- Visual world: set by the owner's design system and 34 drawn screens in light and dark. The job is faithful implementation, not a new direction.

## Voice

Plain words, sentence case, no exclamation marks. Figures first, then one plain sentence that explains them. Model output states how sure it is or its range, never a fact.

## Not decided yet (questions for the owner)

- Whether "Akatabo" means "little book" in Luganda and is free in the app stores.
- Languages beyond English.
- Privacy policy facts and a contact for "Send feedback".
