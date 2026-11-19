"""List every 24x24 icon drawn in design/screens that is missing from the icon table.

Run from the project root:  python -I tools/design/find_icons.py
Prints each missing icon's inner SVG, the files it appears in and nearby text, so it can be
named and added to the table in DESIGN_SYSTEM.md before the app uses it.
"""

from __future__ import annotations

import html
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCREENS = ROOT / "design" / "screens"
SYSTEM = ROOT / "design" / "DESIGN_SYSTEM.md"

SVG_RE = re.compile(r"<svg\b([^>]*)>(.*?)</svg>", re.S | re.I)
ROW_RE = re.compile(r"^\| (\w[\w-]*) \| [^|]* \| `(.+)` \|$", re.M)


NUM_RE = re.compile(r"-?(?:\d+(?:\.\d+)?|\.\d+)")


def _num(m: re.Match[str]) -> str:
    return f"{float(m.group(0)):g}"


def norm(inner: str) -> str:
    """Canonical form so the table's `<path .../>` and `5.500` match the screens' `<path ...></path>` and `5.5`."""
    s = re.sub(r"\s+", " ", inner).strip()
    s = re.sub(r">\s+<", "><", s)
    s = re.sub(r'\s*(stroke|fill|stroke-width|stroke-linecap|stroke-linejoin|class|style)="[^"]*"', "", s)
    s = re.sub(r"<(\w+)([^<>]*?)\s*/>", r"<\1\2></\1>", s)
    s = NUM_RE.sub(_num, s)
    return s


def table() -> dict[str, str]:
    return {norm(paths): name for name, paths in ROW_RE.findall(SYSTEM.read_text(encoding="utf-8"))}


def context(text: str, end: int) -> str:
    after = re.sub(r"<[^>]+>", " ", text[end : end + 300])
    after = html.unescape(re.sub(r"\s+", " ", after)).strip()
    return after[:60]


def main() -> None:
    known = table()
    missing: dict[str, dict] = defaultdict(lambda: {"files": set(), "labels": set(), "ctx": set()})
    for f in sorted(SCREENS.glob("*.html")):
        if f.stem.endswith("Dark"):
            continue
        text = f.read_text(encoding="utf-8")
        for m in SVG_RE.finditer(text):
            attrs, inner = m.group(1), m.group(2)
            if 'viewBox="0 0 24 24"' not in attrs:
                continue
            key = norm(inner)
            if key in known:
                continue
            entry = missing[key]
            entry["files"].add(f.stem)
            label = re.search(r'aria-label="([^"]+)"', text[max(0, m.start() - 400) : m.start()])
            if label:
                entry["labels"].add(label.group(1)[:40])
            entry["ctx"].add(context(text, m.end()))
            entry["filled"] = 'fill="#' in inner or ("fill=" in attrs and 'fill="none"' not in attrs)
    print(f"{len(known)} icons in the table; {len(missing)} drawn icons missing from it.\n")
    for i, (key, e) in enumerate(sorted(missing.items(), key=lambda kv: -len(kv[1]["files"])), 1):
        print(f"[{i}] {key}")
        print(f"    files: {', '.join(sorted(e['files']))}")
        if e["labels"]:
            print(f"    labels: {' | '.join(sorted(e['labels']))[:120]}")
        print(f"    next text: {' | '.join(sorted(e['ctx']))[:160]}")
        if e.get("filled"):
            print("    NOTE: drawn filled")


if __name__ == "__main__":
    main()
