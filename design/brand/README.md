# Akatabo brand

The mark is a spiral notebook ("akatabo" is "a small book" in Luganda) with a rising line on its cover. The owner chose it on 24 November 2026 from ChatGPT concept 2 (`concepts/chatgpt-sheet-1.png`). It was then redrawn as plain geometry, not traced, so it stays crisp at every size and works as a one-colour themed icon.

## Files

| File | Use |
|---|---|
| `akatabo-mark.svg` | The mark in colour, on light grounds |
| `akatabo-mark-reversed.svg` | The mark on brand green or dark grounds |
| `akatabo-mark-mono.svg` | One colour (`currentColor`), with the line and the gap round the cover cut out |
| `akatabo-mark-mono-dark.svg`, `akatabo-mark-mono-light.svg` | The same in brand green or in paper white |
| `akatabo-icon.svg`, `akatabo-icon-on-brand.svg` | Square app-icon tiles |
| `akatabo-wordmark.svg`, `akatabo-wordmark-light.svg` | "Akatabo" in Bricolage Grotesque Bold, as outlines |
| `akatabo-lockup*.svg` | Mark with wordmark, side by side or stacked, on light or on brand |
| `preview.png`, `preview-lockups.png` | Every variant at a glance, including 24 to 96 px |
| `banner-light.png`, `banner-dark.png` | README banners |
| `store/icon-512.png`, `store/feature-graphic.png` | Google Play and fastlane graphics |

`akatabo-mark-mono.svg` takes the text colour only when it is placed inline in HTML. Through `<img>` or a CSS background it draws black.

Colours come from `design/tokens.json`. The tool writes the values it used to `colours.json`.

## Making them again

The geometry lives in `app/lib/core/brand/akatabo_mark.dart`. The app's logo widget paints from the same numbers. From `app/`:

```
flutter test tool/render_brand_test.dart   # marks, icon tiles, previews
python tool/brand_lockups.py               # wordmark and lockups
flutter test tool/render_brand_test.dart   # again, to refresh preview-lockups.png
```

Never edit the SVGs by hand. Change the geometry and run the tools again.

## Licence

The brand files in this folder are licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). The app's code is GPL-3.0.

The name "Akatabo" and the mark identify this project. Forks are welcome under the licences, but should use a different name and icon so people can tell them apart.

The wordmark is drawn from Bricolage Grotesque, used under the SIL Open Font License (`app/assets/fonts/OFL-BricolageGrotesque.txt`).
