# Akatabo

Akatabo is a free money tracker for Uganda. People add what they spend and receive across cash, MTN MoMo, Airtel Money and bank, and it shows money in, money out, fees, budgets and model predictions. It asks for no phone permissions, needs no account and keeps everything on the device. This file is the reference for anyone, human or AI, who designs or builds an Akatabo screen. Read it before writing UI. Values live in `tokens.json`; the rules for using them live here.

## Principles

1. Figures first. A screen leads with a number, then explains it in one plain sentence.
2. Dense, not crowded. Many small facts per screen, laid out on a strict rhythm: 24px screen padding, 12px between cards, 16px inside cards.
3. Show the evidence. Every model output sits next to what it was computed from: the entry, the count of transactions, the range of a forecast.
4. Plain words. Write for someone who uses mobile money daily and has never used a finance app.
5. Free and private. Say that the app is free, needs no account and keeps its data on the phone. Never ask for a phone permission.
6. Adding is the main action. A transaction must be savable with an amount and a few words; everything else is suggested or optional.

## Writing

- Sentence case everywhere. No exclamation marks.
- Currency is always `UGX` before the number with comma separators: `UGX 1,284,000`. In tight spaces drop `UGX` only when the column or card is already labelled with it. Short form `1.83M` and `298k` only on chart labels and stat tiles.
- Money out carries a minus sign and money in a plus sign: `- 45,000`, `+ 250,000`. Red and green (or orange and blue) add to the sign; colour never carries the direction alone.
- Name the network in full: `MTN MoMo`, `Airtel Money`.
- Model outputs state confidence or range in plain terms: `87% sure`, `range 1.72M to 1.93M`. Never present a prediction as a fact.
- Categories: Food and shopping, School fees, Transport, Bills, Family, Other.

## Colour

Two themes, light and dark. Use tokens by name. The rules below describe the light theme; the Dark theme section says what changes.

- `ground` is the screen. `surface` is a card on it, with a 1px `line` border and no shadow.
- `brand` is the header block at the top of Home and the fill of anything primary: active navigation, filled bars, the selected chip. Text on it is `on-brand`; labels are `on-brand-muted`. Large figures on it (the Home total, the Savings goals total, a goal's saved figure, the Welcome and onboarding heroes) use `on-brand-figure`, a softer white, so big numbers do not glare.
- `accent` appears once per screen at most: the main button on a `brand` ground, or the one figure to notice on `brand`. Text on `accent` is `ink`.
- `money-out` and `money-in` are reserved for direction of money. `money-out` also marks fees, over-budget states and model alerts. By default (Settings > Appearance > Money colours > Red and green) they are red and green (`money-out-red`, `money-in-green`), tuned to differ by 20 or more L* in lightness as well as hue. Orange and blue (`money-out`, `money-in` as drawn) stays one tap away for colour-blind users. In either pair they always travel with a sign, an arrow, an icon or a word, so colour is never the only cue.
- `brand-soft` is for secondary chart marks only. It fails contrast for text.
- Text on `ground` and `surface` is `ink` or `ink-muted`. Nothing lighter.
- Every account has a colour: MTN MoMo is yellow (`acct-mtn`), Airtel Money is red (`acct-airtel`), cash is olive (`acct-cash`) and a bank is blue (`acct-bank`) unless the user picks another. It appears as a dot beside the account's name, as the fill of the chosen "Paid from" chip, and as the bar in any chart split by account. These are plain colours only: never draw a network's logo or copy its lettering.
- Every category has its own colour from the twelve `cat-` tokens, chosen by the user. It fills the category's icon tile, its pie slice and its bars, everywhere the category appears. Category colours never carry meaning on their own; the name or icon is always beside them.

### Dark theme

Every colour token has a light and a dark value. Build both themes from tokens only; never invert colours in code.

- The ground is near-black green (`ground`), cards are one step lighter (`surface`), tracks and icon tiles one step lighter again (`surface-sunk`). There are no shadows in either theme.
- Text is `ink` and `ink-muted`; both pass contrast on `ground` and `surface`. Dark `ink` is a soft grey-white (`#DCE3DE`), not near-white: the brightest text read as shouting (owner, 25 November 2026). It stays at 7:1 or more on every dark surface.
- In the light theme `brand` does every job. In the dark theme those jobs split, because one dark green cannot be both a background and a readable mark: `brand` fills buttons and selected chips, `brand-deep` is the Home header and summary cards, `brand-bright` is for bars, lines and selected borders, `brand-text` is for links, and `switch-on` is the switch track and the Add disc. Use these five tokens by job in both themes; in light they all resolve to the same green.
- `money-out` and `money-in` become lighter so they read as text on dark. As bar fills they keep their light-theme values.
- Category colours are the same in both themes. Tiles in `cat-amber` keep an `ink`-dark icon in both.
- The chosen segment of a segmented control is `surface-raised`, lighter than its track in dark and white in light.
- Onboarding, Welcome and PIN entry sit on `screen-deep`.
- The heat calendar runs from dim to bright in dark (more spent is brighter), and from light to dark in light.

## Type

Two sans families, each with one job. Both are bundled with the app, so nothing loads from the network.

- Bricolage Grotesque (`display`): the wordmark, screen titles, section headings, the hero amount and the one-sentence headline of an insight. Weight 600 for every style (since 25 November 2026, one step lighter than drawn, at the owner's request; needs a design check). It is narrow and characterful, so it is for short lines only, never for paragraphs or anything under 18px.
- Geist (`sans`): all running text, labels, buttons, inputs and every amount in a row or table. Weights 400, 500, 600. Amounts use `font-variant-numeric: tabular-nums` and right-align in a column.

Bricolage Grotesque carries the voice and the big numbers; Geist carries the data. Do not add a third family.

Styles: `display-xl` for the one headline on Welcome; `figure-xl` (40px) for the hero amount and the amount input; `display-lg` (28px) for screen titles; `headline` for an insight sentence; `title` for section headings; `body` and `body-strong` for text; `figure` for amounts in rows; `caption` for secondary lines and chart labels. Section eyebrows and field labels are `caption` in uppercase with 0.06em tracking, in `ink-muted`.

## Layout

- Phone frame 390 by 844. Top padding 52 to 60px so the real status bar has room. Never draw a status bar.
- Screen side padding `space-6`. Cards use `radius-lg` and `space-4` padding, `space-3` apart.
- Every tappable thing is at least 44px tall.
- Bottom navigation: Home, Insights, the Add button, Goals, Settings. Goals opens on a Savings | Budgets switch. 64px tall, `surface` with a `line` top border. Active item is `brand` at weight 600; the rest are `ink-muted`. Add is a 48px `brand` disc with the `plus` icon in `on-brand`, in the centre, on every screen.
- Inputs are 48px tall with a `line-strong` border and `radius-lg`, each with a visible label above it. The amount input is the exception: `figure-xl` on a 2px `brand` underline.
- A list row is 56px (raised from 52 on 24 Nov 2026): a 36px icon tile, a two-line text block, and a right-aligned `figure`.
- An analysis screen opens with a `brand` block that states the finding as a `headline` sentence, with the one key figure in `accent`, and the chart that proves it directly underneath.

## Iconography

Line icons on a 24 by 24 grid, 2px stroke, round caps and joins, no fill, coloured with `currentColor`. Draw them as inline SVG so they take the text colour. Never use emoji, and never use a filled or two-tone icon.

In a list row an icon sits at 20px inside a 36px tile with `radius-md`: `surface-sunk` tile with a `brand` icon by default, `money-in-soft` with `money-in` for money received, `money-out-soft` with `money-out` for an alert. In navigation icons are 22px with no tile.

The set. Each entry is the content of `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">`.

| name | used for | paths |
| --- | --- | --- |
| home | navigation | `<path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/>` |
| chart | Insights | `<path d="M5 20V10"/><path d="M12 20V4"/><path d="M19 20v-7"/>` |
| target | Budgets (the Budgets side of Goals) | `<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4"/>` |
| chip | Models, anything computed by a model | `<rect x="7" y="7" width="10" height="10" rx="2"/><path d="M10 3v4M14 3v4M10 17v4M14 17v4M3 10h4M3 14h4M17 10h4M17 14h4"/>` |
| sent | money sent | `<path d="M7 17L17 7"/><path d="M9 7h8v8"/>` |
| received | money received | `<path d="M17 7L7 17"/><path d="M15 17H7V9"/>` |
| cash | cash withdrawal | `<rect x="3" y="7" width="18" height="10" rx="2"/><circle cx="12" cy="12" r="2.5"/>` |
| bolt | Bills | `<path d="M13 3L5 13h6l-1 8 8-10h-6l1-8z"/>` |
| basket | Food and shopping | `<path d="M4 9h16l-1.5 10h-13L4 9z"/><path d="M9 9l3-5 3 5"/>` |
| bus | Transport | `<rect x="5" y="4" width="14" height="13" rx="3"/><path d="M5 11h14M8 17v3M16 17v3"/>` |
| book | School fees | `<path d="M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3V4z"/><path d="M5 17a3 3 0 0 1 3-3h11"/>` |
| people | Family | `<circle cx="9" cy="8" r="3"/><path d="M3 20a6 6 0 0 1 12 0"/><path d="M16 5a3 3 0 0 1 0 6M17 14a6 6 0 0 1 4 6"/>` |
| dots | Other | `<circle cx="6" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="18" cy="12" r="1"/>` |
| trend | forecast | `<path d="M3 17l6-6 4 4 8-8"/><path d="M15 7h6v6"/>` |
| alert | unusual payment | `<path d="M12 4l9 16H3L12 4z"/><path d="M12 10v4M12 17v.5"/>` |
| repeat | recurring payment | `<path d="M4 12a8 8 0 0 1 14-5"/><path d="M20 12a8 8 0 0 1-14 5"/><path d="M18 3v4h-4"/><path d="M6 21v-4h4"/>` |
| tag | category | `<path d="M4 4h8l8 8-8 8-8-8V4z"/><circle cx="8.5" cy="8.5" r="1"/>` |
| lock | privacy | `<rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>` |
| plus | add a transaction | `<path d="M12 5v14M5 12h14"/>` |
| close | close a form | `<path d="M6 6l12 12M18 6L6 18"/>` |
| sliders | Settings | `<path d="M4 6h9M17 6h3M4 12h3M11 12h9M4 18h11M19 18h1"/><circle cx="15" cy="6" r="2"/><circle cx="9" cy="12" r="2"/><circle cx="17" cy="18" r="2"/>` |
| check | saved, done | `<path d="M5 12l5 5 9-10"/>` |
| arrow | next | `<path d="M5 12h14M13 6l6 6-6 6"/>` |
| heart | Health | `<path d="M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.500-7 10-7 10z"/>` |
| house | Rent | `<path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/>` |
| signal | Airtime and data | `<path d="M5 12a10 10 0 0 1 14 0M8 15.500a6 6 0 0 1 8 0"/><circle cx="12" cy="19" r="1"/>` |
| wallet | Savings | `<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18M16 14.500h2"/>` |
| gift | Gifts and giving | `<rect x="4" y="10" width="16" height="10" rx="1"/><path d="M12 10v10M4 14h16"/><path d="M12 10c-2-5-7-3-4 0M12 10c2-5 7-3 4 0"/>` |
| fuel | Fuel | `<path d="M6 20V6a2 2 0 0 1 2-2h5a2 2 0 0 1 2 2v14M5 20h11M8 9h5"/><path d="M15 11l3 2v5a1.500 1.500 0 0 0 3 0V9l-3-3"/>` |
| back | back link | `<path d="M15 5l-7 7 7 7"/>` |
| chevron | opens a page, next period | `<path d="M9 5l7 7-7 7"/>` |
| calendar | Calendar, dates | `<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M8 3v4M16 3v4"/>` |
| list | list view | `<path d="M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01"/>` |
| search | search | `<circle cx="11" cy="11" r="6"/><path d="M20 20l-4.5-4.5"/>` |
| filter | filters | `<path d="M4 6h16M7 12h10M10 18h4"/>` |
| grip | drag to reorder | `<circle cx="9" cy="6" r=".5"/><circle cx="15" cy="6" r=".5"/><circle cx="9" cy="12" r=".5"/><circle cx="15" cy="12" r=".5"/><circle cx="9" cy="18" r=".5"/><circle cx="15" cy="18" r=".5"/>` |
| download | export | `<path d="M12 4v11M7 11l5 5 5-5M5 20h14"/>` |
| upload | restore | `<path d="M12 16V5M7 9l5-5 5 5M5 20h14"/>` |
| file | backup file | `<path d="M6 3h8l4 4v14H6V3z"/><path d="M14 3v4h4"/>` |
| phone | this phone | `<rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/>` |
| sun | Appearance | `<circle cx="12" cy="12" r="4"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M5.6 18.4L7 17M17 7l1.4-1.4"/>` |
| bell | Reminders | `<path d="M6 16v-5a6 6 0 0 1 12 0v5l2 2H4l2-2z"/><path d="M10 20a2 2 0 0 0 4 0"/>` |
| bulb | tip | `<path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-4 10.5c.7.7 1 1.5 1 2.5h6c0-1 .3-1.8 1-2.5A6 6 0 0 0 12 3z"/>` |
| up | rise on a period | `<path d="M12 19V5M6 11l6-6 6 6"/>` |
| fingerprint | unlock with fingerprint | `<path d="M6 10a6 6 0 0 1 12 0v3"/><path d="M9 10a3 3 0 0 1 6 0v4c0 2-.5 4-1.5 6"/><path d="M12 10v4c0 2-.5 4-1.5 5.5"/><path d="M6 13c0 2-.3 3.5-1 5"/><path d="M18 16c0 1-.2 2-.5 3"/>` |
| backspace | delete the last digit | `<path d="M9 5h11v14H9l-6-7 6-7z"/><path d="M12 9.5l5 5M17 9.5l-5 5"/>` |
| medical | Health (cross) | `<path d="M9 4h6v5h5v6h-5v5H9v-5H4V9h5V4z"/>` |
| water | Water | `<path d="M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z"/>` |
| work | Salary, Work | `<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2"/>` |
| giving | Giving | `<path d="M12 3v6M9.5 5.5h5"/><path d="M6 21v-9l6-3 6 3v9M10 21v-4h4v4"/>` |
| eating | Eating out | `<path d="M5 8h12v5a6 6 0 0 1-12 0V8z"/><path d="M17 9h2a2 2 0 0 1 0 4h-2M8 21h6"/>` |
| clothes | Clothes | `<path d="M8 4l4 2 4-2 5 4-3 3-2-1.5V20H8V9.5L6 11 3 8l5-4z"/>` |
| salon | Salon | `<circle cx="6" cy="7" r="2.5"/><circle cx="6" cy="17" r="2.5"/><path d="M8 8.5L20 18M8 15.5L20 6"/>` |
| star | Fun | `<path d="M12 3l2.7 5.6 6.3.9-4.5 4.3 1.1 6.2L12 17l-5.6 3 1.1-6.2L3 9.5l6.3-.9L12 3z"/>` |
| farm | Farm | `<path d="M12 21v-9"/><path d="M12 12c0-4 3-6 7-6 0 4-3 6-7 6z"/><path d="M12 15c0-3-2-5-6-5 0 3 2 5 6 5z"/>` |
| bank | Bank | `<path d="M4 10l8-5 8 5M5 10v8M10 10v8M14 10v8M19 10v8M3 20h18"/>` |
| pencil | edit something | `<path d="M4 20h4L19 9l-4-4L4 16v4z"/><path d="M13.5 6.5l4 4"/>` |

The rows from `chevron` down were added on 19 November 2026 from icons the screens already draw (found by `tools/design/find_icons.py`) and need a design check. `grip` is drawn filled in the screens; here it is six stroked dots, like `dots`, because icons are never filled.

A new icon follows the same grid and stroke and is added to this table before it is used.

## Data display

- Share bars and progress bars are 6 to 10px tall with `radius-sm`, a `brand` fill on a `line` track. Over budget: `money-out` fill on `money-out-soft`.
- A bar always has its number beside it. A chart always has a text summary and a one-sentence reading under it.
- Charts use `brand` for actuals, a dashed `brand` line plus a `brand-soft` band for a forecast, and a dashed `money-in` line for income. At most three series.
- Percentages are whole numbers unless under 10, then one decimal.

### Chart types

- Pie (donut): share of money out by category, six slices at most, the total in the centre. Each slice takes its category's own colour, one of the twelve `cat-` tokens. The category's icon tile in the list beside it uses the same colour, so no separate legend is needed.
- Comparison line: this period as a solid 3px `brand` line with a light fill, the previous period as a dashed `switch-off` line, the forecast as a dotted `money-out` line, on three labelled gridlines with a legend above. Never put a small line inside a list row; say the change in words, such as "Up 31% on October".
- Cash flow: two horizontal bars, money in (`money-in`) over money out (`money-out`), with the net figure in the heading.
- Budget bar: the category's colour on a `line` track, with a 2px `ink` tick showing where spending should be today. Over budget is `money-out` on `money-out-soft`. Every budget has a status chip in words: Over by, Nearly used, A little ahead, On track.
- Heat calendar: one cell per day of the month, seven columns. Steps from light to dark are `surface-sunk`, `heat-low`, `brand-soft`, `chart-green`, `brand`. Days that have not happened are an empty outline in `line-strong`.
- Line with forecast, weekday bars, share bars and progress bars: as above.

Pick the chart by the question: share of a whole is a pie, change over time is a line, a pattern across days is the heat calendar, progress against a limit is a bar.

## Foreign money

- UGX is the home currency: every total, budget and forecast is in whole shillings. A payment in another currency keeps its own amount and rate beside it, and its shillings are what the totals use.
- A foreign amount is kept in hundredths of its unit (100.50 dollars is 10050). A rate is shillings per one unit (3,720 is 3720000000 micros). Both are whole numbers in storage.
- **Rounding is half up to the whole shilling, and is done once, on the converted amount.** Half a shilling rounds up (2.5 becomes 3); a reversal rounds away from zero, so it matches its original. The arithmetic is exact integer arithmetic, so no rounding error comes from floating point.
- The detail line reads "USD 100 at 3,720"; the Add line reads "= UGX 372,000". Spreadsheet cells are plain numbers, never grouped.
- Rates are typed by the person and kept on the phone. Nothing is fetched. An entry keeps the rate it was saved with when a rate changes later.

## Motion

Motion is for onboarding and for a chart's first appearance. Nothing loops except one pulse on the "today" point of a forecast.

- Enter: fade up 18px over 0.55s with `cubic-bezier(.2,.7,.2,1)`; stagger siblings by 0.2s.
- Pop: scale from 0.82 with a slight overshoot, for the one key figure.
- Draw: a line draws left to right over 1.2s; pie slices fade in clockwise.
- Always honour `prefers-reduced-motion` by showing the final state with no animation.

## Settings

Settings is the fifth tab. It opens on a menu of nine entries in three cards: General, Accounts, Categories; Appearance, Home screen, Smart help, Reminders; Privacy and security, Data and backup. Each entry has an icon tile, a title, a one-line summary of what is inside and a chevron, and opens its own page with a back link to Settings. On a page, rows sit in `surface` cards under uppercase `caption` headings. A row is 56px with the label on the left and one control on the right. Anything a person might want to change should be changeable: prefer adding a setting over fixing a choice.

A category is edited on its own screen: name, one of twelve `cat-` colours as 44px discs, one of the icons in a six-column grid of 44px tiles, and an optional monthly budget. The preview tile at the top updates as they choose.

- A yes or no choice is a switch: 48 by 28px track, `brand` when on, `switch-off` when off, 24px white knob, inside a 44px tall target.
- A choice of two or three is a segmented control: a `surface-sunk` track with 4px padding, the chosen segment in `surface`.
- A choice with many values opens its own screen; the row shows the current value in `ink-muted`.
- Destructive rows are last in their card, in `money-out`, and always ask for confirmation.

## Model surfaces

Akatabo has four on-device models: a category classifier, a month-end forecast, an unusual-payment detector and a recurring-payment detector. Users never see the word "model" and there is no Models screen: the app calls this Smart help, and its results appear where they are useful (the Add screen, Home, Insights, Goals). Wherever one speaks:

- Mark it with the `chip` icon or the model's own icon so users learn what is computed and what is recorded.
- Give the evidence in the same card: how many transactions, what range, which signals.
- Offer the correction: a wrong category can be changed, an alert can be dismissed as "This was me".
- Sample figures in designs are placeholders. Never quote a model accuracy in marketing or a portfolio unless it was measured.

## Screens

Thirty-four screens, each drawn in the light and the dark theme. Besides the groups below there are: Calendar, PIN entry, Filters, Choose dates, New account, Money-in categories, and one "Inside a category" screen for each of School fees, Transport, Bills and Other. Build them in this order; each later group depends on the one before.

1. Core loop: Onboarding, Welcome, Home on the first day (empty), Home, Add a transaction, All transactions, One transaction.
2. Understanding: Insights, Categories, Inside a category, Fees and tax, Forecast, Regular payments.
3. Planning: Goals (Savings goals, a goal, New and Edit goal; Budgets, Set a budget).
4. Customising: Settings, General and accounts, Categories (manage), Edit a category, Appearance and Home screen, Smart help and reminders, Privacy and data.
5. Keeping data safe: Export and back up, Restore.

The five tabs are Home, Insights, Add, Goals, Settings. Every other screen is reached from one of them and has a back link to where it came from.

## Storage

The app is free and has no server. All data is stored in a local database on the phone, and the models run on the phone. Nothing is uploaded.

- Export writes a CSV, Excel or PDF file that the user saves or shares themselves.
- A backup is one file holding every transaction, category, budget and setting, optionally protected by a password.
- Restore always shows what is in the file, and how it overlaps with what is on the phone, before it changes anything. "Add what is missing" is the default; "Replace everything" is the destructive choice and names what would be lost.
- Say plainly, once, on the export screen, that losing the phone without a backup loses the data.

### Adding a transaction

This is the screen people use most, so it comes first in every trade-off. Top to bottom: money out or in, the amount, a few words, the category, the account, then the optional fee and time.

- All of the user's categories are visible as a four-column grid of tiles (icon in the category colour, name beneath), with "New" last. Nobody should have to open a list to pick one.
- The suggestion is shown two ways at once: an `accent` pill naming the suggested category and how sure it is, and that tile already chosen in the grid. One tap on another tile overrides it, and that correction is what the classifier learns from.
- A transaction can be saved with only an amount and a category.

### Calendar

Reached from the month button on Home and from All transactions. One screen with five periods on a segmented control: Day, Week, Month, Quarter, Year.

- Month: a grid of days, each showing its day number and money out in thousands, shaded in four steps by amount. Tapping a day shows its total and links to that day's transactions. Days that have not happened are outlined and empty.
- Week: one bar per day. Day: bars by hour, then that day's transactions. Quarter: one bar per week under month labels. Year: one bar per month with highest, lowest and usual month.
- In every period the current day, week or month is the darkest mark, and periods that have not happened are dashed outlines, never zeros.
- Under every period, cards say how it went (added 25 November 2026, not drawn; needs a design check): Spent and received (money out and in, what that leaves, and the change against the same days of the period before), Top categories (up to three, each opening its page), and Savings (goal money set aside in the period, shown once any goal exists; it opens Goals on Savings). With nothing in or out, the money cards are left out because the view already says so. A zero figure reads "None", never `0`. The page scrolls; the selected-day card sits under the grid.

### More charts

- Stacked bars: a total split into two or three parts over months (fees by type). The legend sits above; the newest month is labelled in `ink`.
- History bars with a limit line: six months of one category against a dashed `ink` budget line; months over the line are `money-out`.
- Range strip: earlier amounts as dots on one line with their usual range shaded and the current amount as a larger dark dot. Used to show whether an amount is normal.
- Timeline: upcoming payments as circles on a line of days, sized by amount, in their category colour.
- Forecast accuracy: forecast (dashed outline) beside actual (solid) for past months, with the average error in words. Only show figures that were measured.

## Handoff to development

This section is for whoever builds the app, human or AI. The Design canvas "Akatabo - mobile money tracker" holds the screens; this file holds the rules. Where the two disagree, this file wins.

### Data model

All amounts are whole shillings stored as integers. Never store money as a decimal or a formatted string.

- Transaction: id, direction (out or in), amount, description, categoryId, accountId, fee, tax, note, occurredAt, createdAt, updatedAt, suggestedCategoryId, suggestionConfidence, categoryWasCorrected, flaggedUnusual, flagDismissed.
- Category: id, name, iconKey (a name from the icon table), colourToken (a `cat-` token), kind (spending or income), sortOrder, hidden, monthlyBudget (nullable), budgetCarriesOver, budgetWarnAt.
- Account: id, name, enabled, isDefault, sortOrder.
- RegularPayment: id, label, categoryId, typicalAmount, amountLow, amountHigh, intervalDays, nextDueOn, timesSeen, source (detected or manual), remind.
- Setting: key and value, one row per choice on the Settings pages.

### Rules for the numbers

- Money out for a period is the sum of out amounts plus their fees and tax. Fees and tax are also shown as their own category, built from the fee and tax fields, never entered as separate transactions.
- "Total cost to you" on a transaction is amount plus fee plus tax.
- A share is a category's total divided by money out, to the nearest whole percent, one decimal under 10.
- Budget pace is the day of the month divided by the days in the month. A budget is "Over" above 100%, "Nearly used" from the warn level, "A little ahead" when above pace, otherwise "On track".
- The forecast is spent so far, plus the everyday daily rate times the days left, plus regular payments still due. The daily rate comes from the last 90 days with one-off payments removed. Show it only once there are at least 7 days of entries in the month.
- A change "on October" compares the same number of days in the previous period, not the whole previous month.

### States that are not drawn and must be built

- Empty: only Home has an empty screen drawn. Every list, chart and total needs one: a short sentence saying what will appear and one action. Never draw a chart of zeros.
- Validation on Add: amount above zero, a category chosen or accepted; fee and note optional.
- Confirmation before every destructive action: delete a transaction, delete a category (ask where its transactions go), remove a budget, forget what was learned, replace on restore, delete everything.
- Errors on restore: wrong password, damaged file, a file from a newer version of the app.
- After saving a transaction, return to where the person came from and show the new row.

### Not designed yet

Every screen in the build list is now drawn in both themes. What remains undrawn is small: the "Forgot your PIN" flow, the time and day pickers behind value rows in Settings, and confirmation dialogs. Build these from the rules in this file and flag them for a design check.

### Before calling it done

- Every figure on the canvas is sample data. No screen may ship a hard-coded number.
- Model figures shown to users (how sure a suggestion is, how close past forecasts were) must be computed from the user's own data on the device.
- For a portfolio write-up, report measured results only: category suggestion accuracy on held-out entries, forecast error by day of month, and how many flagged payments users dismissed.
- Confirm that "Akatabo" means what is intended and that the name is free in the app stores.

## Building it in code

Flutter: put the colour tokens in a `ThemeExtension`, the three families in `google_fonts`, and the icons in one `AkataboIcons` widget that draws the paths above with `flutter_svg`. Web: expose tokens as CSS variables named after the token, for example `--brand`, `--money-out`, `--space-4`. Do not hard-code a hex value in a screen.
