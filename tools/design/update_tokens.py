"""Correct and extend design/tokens.json from the drawn screens, then check contrast.

Run from the project root:  python -I tools/design/update_tokens.py

Why this exists (19 Nov 2026):
  * tokens.json gave six tokens the light value in the dark theme. The dark screens use
    other values consistently; those are applied here.
  * The screens use type sizes, spacing, radii and colours that tokens.json did not list.
    They are added as named tokens so no screen has to type a raw value.
  * Settings > Appearance offers five more "main colours". Their full light and dark
    palettes are derived here from the green palette, then checked for contrast.
Every change carries a "note" and is flagged in PROGRESS.md for a design check.
The script is idempotent: running it again gives the same file.
"""

from __future__ import annotations

import colorsys
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOKENS = ROOT / "design" / "tokens.json"
FLAG = "Added 19 Nov 2026 from the drawn screens; needs a design check."

# --------------------------------------------------------------------------- colour maths


def hex_to_rgb(h: str) -> tuple[float, float, float]:
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))  # type: ignore[return-value]


def rgb_to_hex(rgb: tuple[float, float, float]) -> str:
    return "#" + "".join(f"{round(max(0, min(1, c)) * 255):02X}" for c in rgb)


def luminance(h: str) -> float:
    def lin(c: float) -> float:
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = hex_to_rgb(h)
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def contrast(a: str, b: str) -> float:
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def mix(a: str, b: str, t: float) -> str:
    """t=0 gives a, t=1 gives b."""
    ra, rb = hex_to_rgb(a), hex_to_rgb(b)
    return rgb_to_hex(tuple(x + (y - x) * t for x, y in zip(ra, rb)))  # type: ignore[arg-type]


def to_hls(h: str) -> tuple[float, float, float]:
    return colorsys.rgb_to_hls(*hex_to_rgb(h))


def from_hls(h: float, l: float, s: float) -> str:
    return rgb_to_hex(colorsys.hls_to_rgb(h % 1.0, max(0, min(1, l)), max(0, min(1, s))))


# --------------------------------------------------------------------------- corrections

DARK_FIXES = {
    # token: (dark value, evidence)
    "brand-deep": ("#12261F", "MainDark header, BudgetsDark summary, DataExportDark banner"),
    "brand-bright": ("#3FB08A", "TransactionDark amount underline, chart lines, selected borders"),
    "brand-text": ("#8FD0B5", "every back link and text button in the dark screens"),
    "switch-on": ("#2F9E78", "Add disc in every dark tab bar, switch tracks"),
    "surface-raised": ("#3A4A42", "chosen segment of every dark segmented control"),
    "screen-deep": ("#0C1A15", "OnboardingDark, WelcomeDark, LockDark grounds"),
}

NEW_COLOURS = [
    # name, light, dark, usage
    ("outline-muted", "#7C8A82", "#8A9A92",
     "Dashed outlines: empty budget cards, forecast outlines, the previous-period line, drag handles, step circles."),
    ("on-deep", "#D5E3DC", "#D5E3DC", "Paragraph text on screen-deep (Onboarding, Welcome)."),
    ("deep-line", "#5E8777", "#5E8777", "Keypad key borders and inactive pager dots on screen-deep."),
    ("on-light-fill", "#14201B", "#14201B",
     "Text and icons on light fills in both themes: accent, cat-amber, cat-orange, cat-olive, acct-mtn, acct-cash."),
    ("range-band", "#A9CDBE", "#2E5E4C", "Usual-range band on the range strip (One transaction)."),
    ("heat-0", "#E7EBE3", "#243029", "Heat calendar, least spent (same as surface-sunk)."),
    ("heat-1", "#B9CFC5", "#2E4A3F", "Heat calendar step 2 (same as heat-low)."),
    ("heat-2", "#7FA596", "#2F7D62", "Heat calendar step 3. Dark swaps brand-soft and chart-green so it runs dim to bright."),
    ("heat-3", "#2F7D62", "#7FA596", "Heat calendar step 4."),
    ("heat-4", "#0F3D30", "#8FD0B5", "Heat calendar, most spent."),
    ("on-heat-4", "#FFFFFF", "#0E1512", "Text on heat-4."),
]

# Past-period tints for category bars. Five are drawn; the rest use the same mix.
DRAWN_TINTS = {
    "cat-green": ("#A9CDBE", "#2E5E4C"),
    "cat-purple": ("#D2C2E3", "#44325A"),
    "cat-slate": ("#C5CACD", "#3A4247"),
    "cat-blue": ("#B5CDEA", "#2A3F5C"),
    "cat-amber": ("#F1D9A6", "#5C4A1E"),
}
TINT_LIGHT_TOWARD, TINT_LIGHT_T = "#FFFFFF", 0.63
TINT_DARK_TOWARD, TINT_DARK_T = "#3F3F3F", 0.47

TYPE_ADDITIONS = {
    "Display": [
        {"name": "figure-lg", "fontSize": "34px", "lineHeight": "38px", "fontWeight": 700,
         "note": "Hero amount on Insights, Categories, Fees, Forecast, Regular payments, Budgets. " + FLAG},
        {"name": "title-lg", "fontSize": "24px", "lineHeight": "28px", "fontWeight": 700,
         "note": "Title of an 'Inside a category' screen; donut centre figure. " + FLAG},
        {"name": "display-sm", "fontSize": "22px", "lineHeight": "26px", "fontWeight": 700,
         "note": "Calendar period title, selected-day total, wordmark. " + FLAG},
        {"name": "headline-sm", "fontSize": "20px", "lineHeight": "24px", "fontWeight": 600,
         "note": "Insight sentence beside the donut on Categories. " + FLAG},
        {"name": "keypad", "fontSize": "28px", "lineHeight": "32px", "fontWeight": 600,
         "note": "PIN keypad digits. " + FLAG},
    ],
    "Text": [
        {"name": "body-lg", "fontSize": "16px", "lineHeight": "24px", "fontWeight": 400,
         "note": "Paragraphs on Onboarding and Welcome. " + FLAG},
        {"name": "button", "fontSize": "16px", "lineHeight": "20px", "fontWeight": 600,
         "note": "Full-width primary buttons. " + FLAG},
        {"name": "body-md", "fontSize": "15px", "lineHeight": "20px", "fontWeight": 500,
         "note": "Inputs, menu titles, secondary buttons. " + FLAG},
        {"name": "body-sm", "fontSize": "13px", "lineHeight": "18px", "fontWeight": 400,
         "note": "Sub-lines under hero figures, helper text, chips. " + FLAG},
        {"name": "caption-strong", "fontSize": "12px", "lineHeight": "16px", "fontWeight": 600,
         "note": "Status chips, active tab label. " + FLAG},
        {"name": "chart-label", "fontSize": "11px", "lineHeight": "14px", "fontWeight": 400,
         "note": "Axis and point labels inside charts only. " + FLAG},
    ],
}

SPACING_ADDITIONS = [
    {"name": "space-0h", "value": "2px", "usage": "Between a stacked label and figure; between stacked bar segments. " + FLAG},
    {"name": "space-1h", "value": "6px", "usage": "Between small chips; between a bar and its label. " + FLAG},
    {"name": "space-2h", "value": "10px", "usage": "Inside stat tiles; between list items in a group. " + FLAG},
    {"name": "space-3h", "value": "14px", "usage": "Gap between items on pushed screens. " + FLAG},
    {"name": "space-5", "value": "20px", "usage": "Between sections on Settings pages; bottom padding of pushed screens. " + FLAG},
]

RADIUS_ADDITIONS = [
    {"name": "radius-xs", "value": "4px", "usage": "Heat-calendar cells, legend swatches. " + FLAG},
]

SIZE_TOKENS = [
    ("size-target", 44, "Smallest tappable height and width."),
    ("size-row", 52, "A list or settings row."),
    ("size-input", 48, "A text input."),
    ("size-button", 54, "A full-width primary button."),
    ("size-nav", 64, "Bottom navigation bar."),
    ("size-add-disc", 48, "The Add disc in the bottom navigation."),
    ("size-tile", 36, "Icon tile in a list row."),
    ("size-tile-sm", 32, "Icon tile in a compact row (Home share rows, forecast card)."),
    ("size-tile-lg", 48, "Category identity tile."),
    ("size-icon", 20, "Icon inside a row tile."),
    ("size-icon-nav", 22, "Navigation icon."),
    ("size-switch-w", 48, "Switch track width."),
    ("size-switch-h", 28, "Switch track height."),
    ("size-bar", 6, "Share bar thickness."),
    ("size-bar-lg", 10, "Budget and progress bar thickness."),
    ("size-icon-sm", 18, "Icon in a compact tile, a segment, a chip or a link (Home, Add, Settings)."),
    ("size-icon-xs", 14, "Icon inside the suggestion pill on Add."),
    ("size-tile-md", 40, "Category tile in the Add grid."),
    ("size-cat-cell", 72, "A category cell in the Add grid."),
    ("size-dot", 10, "Account colour dot beside a name."),
    ("size-pill", 28, "Suggestion pill and small status chips."),
]

MAIN_COLOURS = [
    # id, label, light brand
    ("green", "Forest green", "#0F3D30"),
    ("blue", "Deep blue", "#173A6B"),
    ("plum", "Plum", "#4A2545"),
    ("charcoal", "Charcoal", "#22282B"),
    ("brown", "Brown", "#6B3A1E"),
    ("wine", "Wine red", "#7A1F2B"),
]
PALETTE_KEYS = [
    "brand", "brand-raised", "brand-soft", "on-brand-muted", "brand-deep", "brand-bright",
    "brand-text", "switch-on", "screen-deep", "heat-1", "heat-2", "heat-3", "heat-4",
]


def palette_for(base_light: str, green: dict[str, dict[str, str]]) -> dict[str, dict[str, str]]:
    """Move every green palette value onto the new hue, keeping green's lightness steps."""
    gh, gl, gs = to_hls(green["brand"]["light"])
    nh, nl, ns = to_hls(base_light)
    out: dict[str, dict[str, str]] = {}
    for key in PALETTE_KEYS:
        out[key] = {}
        for theme in ("light", "dark"):
            th, tl, ts = to_hls(green[key][theme])
            hue = nh + (th - gh)
            sat = ts * (ns / gs) if gs else ts
            # Shift lightness by the base difference, weighted so green's brand maps exactly onto
            # the drawn base colour and near-white values barely move.
            weight = (1 - tl) / (1 - gl) if gl < 1 else 0
            light = tl + (nl - gl) * weight
            out[key][theme] = from_hls(hue, light, sat)
    return out


# --------------------------------------------------------------------------- contrast rules

GROUND = {"light": "#F5F6F1", "dark": "#0E1512"}
SURFACE = {"light": "#FFFFFF", "dark": "#18221D"}
WHITE = "#FFFFFF"


def palette_checks(p: dict[str, dict[str, str]]) -> list[tuple[str, float, float]]:
    rows = []
    for t in ("light", "dark"):
        rows += [
            (f"{t}: on-brand on brand", contrast(WHITE, p["brand"][t]), 4.5),
            (f"{t}: on-brand on brand-deep", contrast(WHITE, p["brand-deep"][t]), 4.5),
            (f"{t}: on-brand-muted on brand-deep", contrast(p["on-brand-muted"][t], p["brand-deep"][t]), 4.5),
            (f"{t}: brand-text on ground", contrast(p["brand-text"][t], GROUND[t]), 4.5),
            (f"{t}: brand-text on surface", contrast(p["brand-text"][t], SURFACE[t]), 4.5),
            (f"{t}: brand-bright on surface (marks)", contrast(p["brand-bright"][t], SURFACE[t]), 3.0),
            (f"{t}: switch-on on surface (control)", contrast(p["switch-on"][t], SURFACE[t]), 3.0),
            (f"{t}: on-deep on screen-deep", contrast("#D5E3DC", p["screen-deep"][t]), 4.5),
        ]
    return rows


def repair(p: dict[str, dict[str, str]]) -> dict[str, dict[str, str]]:
    """Nudge lightness until every rule passes. Dark marks get lighter; fills get darker."""
    darken = ["brand", "brand-deep", "screen-deep"]
    for _ in range(60):
        failing = [r for r in palette_checks(p) if r[1] < r[2]]
        if not failing:
            return p
        for label, _, _ in failing:
            theme, rest = label.split(": ", 1)
            if rest.startswith("brand-text"):
                key, step = "brand-text", (0.02 if theme == "dark" else -0.02)
            elif rest.startswith("brand-bright"):
                key, step = "brand-bright", (0.02 if theme == "dark" else -0.02)
            elif rest.startswith("switch-on"):
                key, step = "switch-on", (0.02 if theme == "dark" else -0.02)
            else:
                key = next(k for k in darken if k in rest.split(" on ")[-1]) if " on " in rest else "brand"
                step = -0.02
            h, l, s = to_hls(p[key][theme])
            p[key][theme] = from_hls(h, l + step, s)
    raise SystemExit(f"Could not repair palette: {palette_checks(p)}")


# --------------------------------------------------------------------------- main


def main() -> int:
    data = json.loads(TOKENS.read_text(encoding="utf-8"))
    colours = {t["name"]: t for t in data["color"]["tokens"]}

    for name, (dark, evidence) in DARK_FIXES.items():
        colours[name]["value"]["dark"] = dark
        colours[name]["note"] = f"Dark value corrected 19 Nov 2026 from {evidence}; needs a design check."

    for name, light, dark, usage in NEW_COLOURS:
        colours[name] = {"name": name, "value": {"light": light, "dark": dark}, "usage": usage, "note": FLAG}

    cats = [n for n in colours if n.startswith("cat-") and not n.endswith("-past")]
    for cat in cats:
        base = colours[cat]["value"]["light"]
        if cat in DRAWN_TINTS:
            light, dark = DRAWN_TINTS[cat]
            note = "Drawn on the 'Inside a category' screens. " + FLAG
        else:
            light = mix(base, TINT_LIGHT_TOWARD, TINT_LIGHT_T)
            dark = mix(base, TINT_DARK_TOWARD, TINT_DARK_T)
            note = "Derived with the same mix as the five drawn tints. " + FLAG
        colours[f"{cat}-past"] = {
            "name": f"{cat}-past", "value": {"light": light, "dark": dark},
            "usage": f"Bars for earlier periods of a {cat} category.", "note": note,
        }

    data["color"]["tokens"] = list(colours.values())

    for group in data["type"]["groups"]:
        existing = {s["name"] for s in group["styles"]}
        for style in TYPE_ADDITIONS.get(group["name"], []):
            if style["name"] in existing:
                group["styles"] = [style if s["name"] == style["name"] else s for s in group["styles"]]
            else:
                group["styles"].append(style)

    for key, additions in (("spacing", SPACING_ADDITIONS), ("radius", RADIUS_ADDITIONS)):
        existing = {t["name"]: t for t in data[key]["tokens"]}
        for t in additions:
            existing[t["name"]] = t
        data[key]["tokens"] = sorted(existing.values(), key=lambda t: float(t["value"].rstrip("px")))

    data["size"] = {
        "tokens": [{"name": n, "value": f"{v}px", "usage": u} for n, v, u in SIZE_TOKENS],
        "note": "Component sizes from DESIGN_SYSTEM.md (Layout, Settings) and the screens. " + FLAG,
    }

    green = {k: dict(colours[k]["value"]) for k in PALETTE_KEYS}
    palettes = []
    failures = []
    for pid, label, base in MAIN_COLOURS:
        pal = green if pid == "green" else repair(palette_for(base, green))
        for row in palette_checks(pal):
            if row[1] < row[2]:
                failures.append((pid, *row))
        palettes.append({"id": pid, "label": label, "values": pal})
    data["palettes"] = {
        "note": "Settings > Appearance > Main colour. 'green' is the default and equals the colour tokens. "
                "The other five are derived from green's lightness steps and contrast-checked by "
                "tools/design/update_tokens.py. " + FLAG,
        "keys": PALETTE_KEYS,
        "items": palettes,
    }

    TOKENS.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")

    # Report
    print("Contrast, default green palette:")
    for label, ratio, need in palette_checks(green):
        print(f"  {'PASS' if ratio >= need else 'FAIL'} {ratio:5.2f} (need {need}) {label}")
    for pid, label, ratio, need in failures:
        print(f"  FAIL {pid}: {label} {ratio:.2f} < {need}")
    for p in palettes[1:]:
        worst = min(r[1] / r[2] for r in palette_checks(p["values"]))
        print(f"  {p['id']:<9} brand {p['values']['brand']['light']} / {p['values']['brand']['dark']}, "
              f"worst margin x{worst:.2f}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
