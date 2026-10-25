# ZapWise design materials

Everything visual in the app was drawn in code on a palette-indexed pixel grid (no image generator), so you
can change or add sprites the same way.

| Path | What |
|---|---|
| `ZapWise_디자인차트_v0.1.pptx`, `deck_text.md` | Design chart (Korean): name and logo, 9 UI colors, 25-color pixel palette, fonts, pixel rules, mascot Zappy, assets, touch map of the kitchen, components, three mood screens, writing rules |
| `proto/index.html` | Clickable HTML prototype of the whole app (open in a desktop browser). The Flutter app follows it screen by screen. |
| `proto_v032/index.html` | The same prototype updated for v0.3.2: plain-English copy, labels on the kitchen objects, the new result layout, quests with a reason, and a proposed Quick estimate by net weight and portion |
| `web/` | Mood screens and component sheets (HTML/CSS), web fonts (all SIL Open Font License 1.1; license texts in `web/fonts/licenses/`), `shoot.js` (Playwright screenshot helper) |
| `out/` | Rendered assets: `brand/` (wordmark, first app icon), `mascot/` (first Zappy with glasses), `mascot_led/` (final LED-face Zappy and the final app icon), `mascot_v2/` (10 explored variants), `objects/`, `icons/`, `scene/`, `screens/`, `deck/`, `proto/` (the exact images the prototype and app use) |
| `pix.py` | Pixel engine: palette `PAL`, canvas, primitives, outline, PNG/SVG export |
| `objects.py`, `icons.py`, `logo.py`, `sprites.py`, `zappy_led.py`, `mascot_variants.py`, `scene.py`, `scene_v2.py` | Sprite code; each writes into `out/` |
| `app_sprites.py` | Copies the final sprites into `../app/assets/ui/` and draws the extra container sprites (steam bag, pouch, paper cup, popcorn bag, PP tray, paper tray, can, sleeve, and the melamine or bamboo-fibre bowl added in v0.3.1) |
| `build_design_deck.js` | How the design chart was built (pptxgenjs). It used a theme helper that is not included, so treat it as a reference. |
| `ASSET_PACK_README_v0.1.md` | Notes from the first asset pack |

Rules: scale pixel art by whole numbers only, nearest neighbor; use only the 25 colors in `pix.py`;
1 px Cocoa outline; light from the top left. In the app, sprites are stored at 1x in `app/assets/ui/`
and drawn with `FilterQuality.none`.

Regenerate (Python 3 + Pillow), from this folder:

```bash
python3 sprites.py && python3 objects.py && python3 icons.py && python3 logo.py && python3 zappy_led.py && python3 scene_v2.py
python3 app_sprites.py          # refresh ../app/assets/ui
```

Fonts in the app: Pixelify Sans (titles and numbers) and Nunito (text), both SIL Open Font License,
as static TTFs in `app/assets/fonts/` with their license files. Galmuri11 (Korean pixel font) is only
for Korean presentation material.
