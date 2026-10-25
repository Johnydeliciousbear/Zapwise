# ZapWise assets v0.1

Pixel art drawn on a palette-indexed grid in Python (no image generation).

- brand/    wordmark (1x, 8x, SVG), app icon (32 px grid, 1024 px)
- mascot/   Zappy, 6 expressions (1x, 8x, SVG)
- objects/  kitchen appliances, containers, props (1x, 6x, 8x, SVG)
- icons/    16x16 UI icons (1x, 2x, 4x, 8x, SVG)
- scene/    kitchen home scene 196x216 (1x, 2x, 4x, 6x, with and without tap hints)
- screens/  component captures and three mood screens (HTML rendered at 2x)
- source/   pixel engine and sprite code, mood screen HTML/CSS, fonts with OFL licenses

Rules: scale pixel art by whole numbers only, nearest neighbor. Use only the 25 colors in source/pix.py (PAL).

Regenerate (Python 3 + Pillow):
    cd source
    python3 sprites.py && python3 objects.py && python3 icons.py && python3 logo.py && python3 scene.py

Render a mood screen (Node + Playwright):
    cd source/web && node shoot.js home.html home.png
