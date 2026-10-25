// Directions read from the student's store photos (2026-10-14), lightly paraphrased but with the
// label's own number formats and wattage phrasing kept. Each case lists what the parser should
// return, taken from research/products_field_2026-10.json.
//   node tool/real_labels.mjs            prints pass/fail per label
//   node tool/real_labels.mjs --write    adds the cases to test/fixtures/parser_vectors.json
import fs from 'fs';
import { parse } from './parser_check.mjs';

export const REAL = {
  // Trader Joe's: "MICROWAVE (1200 watt):" header, fractions written as "2 1/2"
  tj_birria: {
    text: `HEATING INSTRUCTIONS: HEAT FROM FROZEN
MICROWAVE (1200 watt): Microwave heat times may vary depending on oven wattage. Heat from frozen. Remove outer packaging and carefully puncture film. Heat on high for 2 1/2 minutes. Carefully remove film and stir. Heat for an additional 2 1/2 minutes or until product reaches 165°F.
STOVETOP: Thaw product in the refrigerator overnight. Pour contents of tray into a pot. Bring to a boil over medium heat.`,
    want: { ref_watt: 1200, steps: [['action'], ['cook', 150, null], ['action'], ['cook', 150, null]] },
  },
  tj_bulgogi: {
    text: `MICROWAVE (1200 watt) Microwave cook times may vary depending on oven wattage. Do not remove the seal film before cooking. Cook on high for 4 to 5 minutes or until an internal temperature of 165°F is reached with a food thermometer. The film may balloon slightly. Let stand for 1 to 2 minutes. Carefully remove the film, stir gently and enjoy.`,
    want: { ref_watt: 1200, steps: [['action'], ['cook', 240, 300], ['stand', 60, 120], ['action']] },
  },
  tj_just_chicken: {
    text: `HEATING INSTRUCTIONS: MICROWAVE (1200 WATT): Microwave heat times may vary depending on oven wattage. Puncture film and microwave on high for 1 1/2 to 2 minutes or until heated through.`,
    want: { ref_watt: 1200, steps: [['cook', 90, 120]] },
  },
  tj_rosemary: {
    text: `HEATING INSTRUCTIONS: CONVENTIONAL OVEN (Preferred method): Preheat oven to 350°F. Lift one corner of film. Place tray on a baking sheet on center rack of oven. Heat 20 to 25 minutes or to an internal temperature of 160°F.
MICROWAVE (1200 watt): Microwave cook times may vary depending on oven wattage. Place tray in microwave and heat 2 to 3 minutes on HIGH; let sit 1 minute before removing film.`,
    want: { ref_watt: 1200, steps: [['cook', 120, 180], ['stand', 60, null]] },
  },
  tj_nuggets_seconds: {
    text: `HEATING INSTRUCTIONS: CONVENTIONAL OVEN Preheat oven to 425°F. Heat for 10 to 12 minutes, flipping halfway through.
MICROWAVE (1200 watt): Place a single layer of nuggets on a microwave-safe plate. Microwave on high for 50 seconds. Let stand for 2 to 3 minutes before serving.
AIR FRYER: Heat for 6 to 8 minutes.`,
    want: { ref_watt: 1200, steps: [['cook', 50, null], ['stand', 120, 180]] },
  },
  // Target Good & Gather: numbered steps, no wattage, fractions as the "½" glyph
  gg_mashed: {
    text: `Heat & Serve
1. Puncture film and microwave on HIGH for 3 minutes.
2. Carefully remove film and stir.
3. Microwave uncovered 1 minute longer or until hot.
4. Let stand 1 minute before serving.
Microwave ovens may vary; adjust heating times accordingly.`,
    want: { ref_watt: 1100, ref_watt_assumed: true, steps: [['cook', 180, null], ['action'], ['cook', 60, null], ['stand', 60, null]] },
  },
  gg_cavatappi: {
    text: `Microwave
1. Remove film. Cover with paper towel.
2. Microwave on HIGH for 2 minutes; stir and replace paper towel.
3. Microwave 1½ to 2½ minutes longer or until hot.
Caution: Package and contents will be hot.`,
    want: { ref_watt: 1100, ref_watt_assumed: true, steps: [['action'], ['action'], ['cook', 120, null], ['action'], ['cook', 90, 150]] },
  },
  // Factor: "30 second intervals" must not become a cook step of its own
  factor_intervals: {
    text: `MICROWAVE COOKING INSTRUCTION: 1. Remove outer sleeve and pierce film with a fork. 2. Microwave on HIGH for 2 minutes. If needed, continue cooking in 30 second intervals until the internal temperature reaches 165°F. 3. Let stand for 2 minutes. Carefully remove film.`,
    want: { ref_watt: 1100, ref_watt_assumed: true, steps: [['action'], ['cook', 120, null], ['action'], ['stand', 120, null], ['action']] },
  },
  // Albertsons ReadyMeals: decimal ranges "3-3.5" and an en dash "3.5–4"
  readymeals_teriyaki: {
    text: `HEATING INSTRUCTIONS: MICROWAVE: Remove lid. Cover tray and place in the center of microwave. Heat on High for 3–3.5 minutes or to 165°F. Let rest for 1 minute before serving. Note: The power of microwave ovens varies. You may have to adjust cooking time.`,
    want: { ref_watt: 1100, ref_watt_assumed: true, steps: [['action'], ['action'], ['cook', 180, 210], ['stand', 60, null]] },
  },
  readymeals_ziti: {
    text: `MICROWAVE: Remove lid. Cover tray and place in the center of microwave. Heat on High for 3.5–4 minutes or to 165°F. Let rest for 1 minute before serving.`,
    want: { ref_watt: 1100, ref_watt_assumed: true, steps: [['action'], ['action'], ['cook', 210, 240], ['stand', 60, null]] },
  },
  // store-packed deli label: all caps, "30 SEC-1 MINUTES"
  deli_pork_bun: {
    text: `READY TO HEAT: MICROWAVE TIMES MAY VARY. REMOVE LID AND MICROWAVE ON HIGH 30 SEC-1 MINUTES OR UNTIL THE MEAL REACHES AN INTERNAL TEMP OF 165F.`,
    want: { ref_watt: 1100, ref_watt_assumed: true, steps: [['cook', 30, 60]] },
  },
  // Conagra: wattage given as "1100-watt microwave ovens" in a footnote, range "1 to 1 ½ minutes"
  pfchangs_egg_rolls: {
    text: `MICROWAVE OVEN
1 Place 4 egg rolls on a small microwave-safe plate; cover with damp paper towel.
2 Microwave on HIGH 1 to 1 ½ minutes. HANDLE CAREFULLY; THEY'RE HOT! Remove paper towel and let stand 1 minute; serve and enjoy!
SIGNATURE SAUCE PACKET: DO NOT MICROWAVE. Place sauce packet in warm water to thaw.
Microwave directions developed with 1100-watt microwave ovens. Appliances vary.`,
    want: { ref_watt: 1100, ref_watt_assumed: false, steps: [['action'], ['cook', 60, 90], ['stand', 60, null]], do_not: false },
  },
};

function check(name, c) {
  const r = parse(c.text);
  const errs = [];
  if (r.ref_watt !== c.want.ref_watt) errs.push(`ref_watt ${r.ref_watt} != ${c.want.ref_watt}`);
  if (c.want.ref_watt_assumed !== undefined && r.ref_watt_assumed !== c.want.ref_watt_assumed) errs.push(`assumed ${r.ref_watt_assumed}`);
  if (c.want.do_not !== undefined && r.do_not_microwave !== c.want.do_not) errs.push(`do_not ${r.do_not_microwave}`);
  const got = r.steps.map((s) => (s.kind === 'action' ? ['action'] : [s.kind, s.time_s, s.time_s_max ?? null]));
  if (JSON.stringify(got) !== JSON.stringify(c.want.steps)) errs.push(`steps ${JSON.stringify(got)} != ${JSON.stringify(c.want.steps)}`);
  return { r, errs };
}

const isMain = import.meta.url === `file://${process.argv[1]}`;
if (isMain) {
  let fail = 0;
  const vectors = JSON.parse(fs.readFileSync(new URL('../test/fixtures/parser_vectors.json', import.meta.url)));
  for (const [k, c] of Object.entries(REAL)) {
    const { r, errs } = check(k, c);
    console.log(errs.length ? 'FAIL' : 'ok  ', k, errs.join('; '));
    if (errs.length) fail++;
    vectors['real_' + k] = { text: c.text, expected: { ref_watt: r.ref_watt, ref_watt_assumed: r.ref_watt_assumed, steps: r.steps, watt_table: r.watt_table,
      completeness: r.completeness, do_not_microwave: r.do_not_microwave, min_watt: r.min_watt } };
  }
  console.log(`${Object.keys(REAL).length - fail}/${Object.keys(REAL).length} real labels parsed as expected`);
  if (process.argv[2] === '--write' && !fail) fs.writeFileSync(new URL('../test/fixtures/parser_vectors.json', import.meta.url), JSON.stringify(vectors, null, 1));
}
