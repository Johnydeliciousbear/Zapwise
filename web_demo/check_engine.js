// node web/check_engine.js  -> compares the JS engine with the Python reference output
const fs = require('fs');
require('./engine.js');
const P = JSON.parse(fs.readFileSync(process.argv[2] + '/zapwise_params.json'));
const prods = {}; JSON.parse(fs.readFileSync(process.argv[2] + '/products.json')).products.forEach(p => prods[p.id] = p);
const ref = JSON.parse(fs.readFileSync(process.argv[3]));
const eng = new ZapEngine.Engine(P, prods);
let bad = 0, worst = 0;
const rel = (a, b) => (a === null || b === null || a === undefined || b === undefined) ? (a == b ? 0 : 1) : (Math.abs(a - b) / Math.max(1e-12, Math.abs(b)));
for (const r of ref) {
  const j = eng.evaluate({ product_id: r.pid, watt: r.watt, extra_cook_s: r.extra, body_weight_kg: 70 }, r.mc);
  let e = Math.max(rel(j.headline_pct, r.pct), r.vs === null ? 0 : rel(j.vs_label, r.vs));
  if (r.range) e = Math.max(e, rel(j.range.p05, r.range.p05), rel(j.range.p95, r.range.p95));
  const flagsOk = JSON.stringify(j.flags) === JSON.stringify(r.flags) && j.status === r.status && j.band === r.band;
  if (e > 1e-9 || !flagsOk) { bad++; if (bad < 6) console.log('DIFF', r.pid, r.watt, r.extra, j.status, r.status, j.headline_pct, r.pct, j.flags, r.flags); }
  worst = Math.max(worst, e);
}
console.log(ref.length, 'cases,', bad, 'differ, worst relative error', worst.toExponential(2));
