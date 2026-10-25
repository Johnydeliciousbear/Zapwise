// JavaScript mirror of lib/core/recognition/watt_label.dart (same regexes) for checking without a Dart SDK.
const wattRe = /(\d{3,4}(?:[.,]\d+)?)\s*-?\s*(?:watts?|w)(?![a-z])/gi;
const kwRe = /(\d(?:[.,]\d{1,2})?)\s*-?\s*kw(?![a-z])/gi;
const outputRe = /output|cooking power|microwave power|rated (?:microwave )?power/i;
const inputRe = /input|consumption|\d{3}\s*v|\bhz\b|\d\s*a\b|amps?/i;
export function wattFromApplianceLabel(text) {
  const hits = [];
  for (const m of text.matchAll(wattRe)) { const v = parseFloat(m[1].replace(',', '.')); if (!isNaN(v)) hits.push({ watt: v, start: m.index }); }
  for (const m of text.matchAll(kwRe)) { const v = parseFloat(m[1].replace(',', '.')); if (!isNaN(v)) hits.push({ watt: v * 1000, start: m.index }); }
  if (!hits.length) return null;
  hits.sort((a, b) => a.start - b.start);
  const before = h => text.substring(Math.max(0, h.start - 28), h.start);
  const lineOf = h => { const s = text.lastIndexOf('\n', h.start); let e = text.indexOf('\n', h.start); return text.substring(s < 0 ? 0 : s + 1, e < 0 ? text.length : e); };
  const plausible = hits.filter(h => h.watt >= 300 && h.watt <= 2000);
  for (const h of plausible) if (outputRe.test(before(h))) return h.watt;
  const rest = plausible.filter(h => !inputRe.test(before(h)) && !inputRe.test(lineOf(h)));
  const pool = (rest.length ? rest : plausible).filter(h => h.watt >= 500 && h.watt <= 1800).sort((a, b) => a.watt - b.watt);
  return pool.length ? pool[0].watt : null;
}
const cases = {
  'MODEL NN-SN65KB\n120V~ 60Hz\nINPUT 1500W\nOUTPUT 1200W': 1200,
  'Microwave output: 1.1 kW\nRated input 1.5 kW': 1100,
  'Rated Power Output: 1000 W\nInput Power: 1450W': 1000,
  '120 V 60 Hz 13.0 A 1500 W\nMicrowave 1100 watts': 1100,
  'COOKING POWER 900W': 900,
  'Serial 12345 made in China': null,
  '1150 W': 1150,
};
let bad = 0;
for (const [t, want] of Object.entries(cases)) { const got = wattFromApplianceLabel(t); if (got !== want) { bad++; console.log('MISMATCH', JSON.stringify(t), got, want); } }
console.log(bad ? `${bad} mismatches` : 'all watt label cases pass');
