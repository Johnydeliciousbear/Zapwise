# ZapWise web version (real engine)

`zapwise_web.html` is the whole app in one file: open it in any browser, no install, works offline.
It uses the same product database (`app/assets/data/products.json`, 107 products) and the same
container and limit data (`zapwise_params.json`) as the Flutter app, and every number comes from
`engine.js`, a line-by-line JavaScript port of `engine_py/zapwise_engine.py`.

Checked: `node web_demo/check_engine.js app/assets/data <python output>` compared 428 cases
(107 products, 700 W and 1100 W, box time and +2 min, Monte Carlo ranges) with the Python
reference: 0 differences, largest relative error 1.8e-15.

What differs from the Flutter app: the camera is replaced by sample boxes and "Find it by name";
there is no photo recognition, barcode reading or product registration. Everything else
(heating guide, estimate, range, ways to lower it, log, quests, Spanish) works.

Files: `index.html` (screens), `engine.js` (engine), `data.js` (generated), `img/` (pixel art),
`build.py` (makes the single file), `check_engine.js` (engine check).
