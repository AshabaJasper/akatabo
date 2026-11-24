"""Writes the Akatabo wordmark and lockups into design/brand/.

The wordmark is "Akatabo" in Bricolage Grotesque Bold (wght 700, opsz 96, wdth 100),
turned into outlines so the files need no font. The lockups place the mark written by
tool/render_brand_test.dart (run that first) beside or above the wordmark.

Run from app/:  python tool/brand_lockups.py
"""

import json
import re
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

APP = Path(__file__).resolve().parent.parent
BRAND = APP.parent / "design" / "brand"
FONT = APP / "assets" / "fonts" / "BricolageGrotesque-Variable.ttf"

# Written from the design tokens by tool/render_brand_test.dart, so the values never drift.
COLOURS = json.loads((BRAND / "colours.json").read_text(encoding="utf-8"))
INK = COLOURS["brandDeep"]
PAPER = COLOURS["ground"]
TEXT = "Akatabo"
# Pair kerning from Bricolage's GPOS at wght 700, opsz 96 (units per 1000 em).
KERN = {("A", "k"): -2, ("k", "a"): -6, ("a", "t"): -3, ("t", "a"): -4}


def wordmark_path():
    """Outline of TEXT on a y-down grid, baseline at y=0, plus its bounds and advance."""
    font = instantiateVariableFont(TTFont(FONT), {"wght": 700, "opsz": 96, "wdth": 100})
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    hmtx = font["hmtx"]
    pen = SVGPathPen(glyphs)
    bounds = BoundsPen(glyphs)
    x = 0
    for i, ch in enumerate(TEXT):
        name = cmap[ord(ch)]
        flip = (1, 0, 0, -1, x, 0)
        glyphs[name].draw(TransformPen(pen, flip))
        glyphs[name].draw(TransformPen(bounds, flip))
        nxt = TEXT[i + 1] if i + 1 < len(TEXT) else None
        x += hmtx[name][0] + KERN.get((ch, nxt), 0)
    return pen.getCommands(), bounds.bounds, x, font["OS/2"].sCapHeight


def mark_inner(name):
    """The <g> body and viewBox of a mark SVG written by render_brand_test.dart."""
    svg = (BRAND / name).read_text(encoding="utf-8")
    vb = [float(v) for v in re.search(r'viewBox="([^"]+)"', svg).group(1).split()]
    body = svg[svg.index("<g>") + 3 : svg.rindex("</g>")]
    return body, vb


def lockup(mark_file, ink, background, stacked, out):
    tid = out.removesuffix(".svg") + "-title"
    d, (x0, y0, x1, y1), _, cap = wordmark_path()
    body, (mx, my, mw, mh) = mark_inner(mark_file)
    word_h = y1 - y0
    word_w = x1 - x0
    # The mark is as tall as about 1.55 cap heights, and sits on the wordmark's optical centre.
    mark_h = cap * (2.1 if stacked else 1.55)
    s = mark_h / mh
    mark_w = mw * s
    gap = cap * (0.45 if stacked else 0.42)
    pad = cap * 0.35
    if stacked:
        width = max(mark_w, word_w) + 2 * pad
        height = mark_h + gap + word_h + 2 * pad
        mtx = (width - mark_w) / 2 - mx * s
        mty = pad - my * s
        wtx = (width - word_w) / 2 - x0
        wty = pad + mark_h + gap - y0
    else:
        width = mark_w + gap + word_w + 2 * pad
        height = max(mark_h, word_h) + 2 * pad
        mtx = pad - mx * s
        mty = (height - mark_h) / 2 - my * s
        wtx = pad + mark_w + gap - x0
        # Centre the cap height on the mark.
        wty = height / 2 + cap / 2
    bg = (
        f'<rect width="{width:.1f}" height="{height:.1f}" fill="{background}"/>\n  '
        if background
        else ""
    )
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width:.1f} {height:.1f}" role="img" aria-labelledby="{tid}">
  <title id="{tid}">Akatabo</title>
  {bg}<g transform="translate({mtx:.2f} {mty:.2f}) scale({s:.5f})">{body}</g>
  <path transform="translate({wtx:.2f} {wty:.2f})" fill="{ink}" d="{d}"/>
</svg>
"""
    (BRAND / out).write_text(svg, encoding="utf-8")


def wordmark(ink, out):
    tid = out.removesuffix(".svg") + "-title"
    d, (x0, y0, x1, y1), _, _ = wordmark_path()
    w, h = x1 - x0, y1 - y0
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x0:.1f} {y0:.1f} {w:.1f} {h:.1f}" role="img" aria-labelledby="{tid}">
  <title id="{tid}">Akatabo</title>
  <path fill="{ink}" d="{d}"/>
</svg>
"""
    (BRAND / out).write_text(svg, encoding="utf-8")


if __name__ == "__main__":
    wordmark(INK, "akatabo-wordmark.svg")
    wordmark(PAPER, "akatabo-wordmark-light.svg")
    lockup("akatabo-mark.svg", INK, None, False, "akatabo-lockup.svg")
    lockup("akatabo-mark.svg", INK, None, True, "akatabo-lockup-stacked.svg")
    lockup("akatabo-mark-reversed.svg", PAPER, INK, False, "akatabo-lockup-on-brand.svg")
    lockup("akatabo-mark-reversed.svg", PAPER, INK, True, "akatabo-lockup-stacked-on-brand.svg")
    print("wrote wordmark and lockups to", BRAND)
