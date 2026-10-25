// JavaScript mirror of lib/core/recognition/container_cues.dart (same regex dialect).
//   node tool/cues_check.mjs            prints the samples
// test/fixtures/cues_vectors.json is written from SAMPLES and checked by test/container_cues_test.dart.
import fs from 'fs';

const ABBR = '(PETE|PET|HDPE|PE-HD|LDPE|PE-LD|PVC|PP|PS|OTHER)';
const codeAfter = new RegExp(String.raw`(?<![\d.])([1-7])\s*` + ABBR + String.raw`\b`, 'i');
const codeBefore = new RegExp(String.raw`\b` + ABBR + String.raw`\s*([1-7])(?![\d.])`, 'i');
const codeHash = /(?:#|no\.?\s*)([1-7])(?![\d.])/i;
const codeSymbol = /[♳-♹]/;
const cpet = /\bc-?pet\b/i, pet = /\b(?:pete|pet)\b/i, pp = /\b(?:pp|polypropylene)\b/i, ps = /\b(?:ps|polystyrene)\b/i;
const pe = /\b(?:hdpe|ldpe|pe-hd|pe-ld|polyethylene)\b/i, pvc = /\bpvc\b/i;
const oven = /dual[\s-]?ovenable|\bovenable|oven[\s-]?safe|conventional oven|oven (?:and|&|or) microwave|microwave (?:and|&|or) (?:conventional )?oven|(?:up to|to|max\.?)\s*(?:4[0-4]\d)\s*°?\s*f\b|(?:up to|to|max\.?)\s*(?:2[0-3]\d)\s*°?\s*c\b/i;
// "SAFE FOR MICROWAVE", "MICROWAVE REHEATABLE", "MICROWAVE & FREEZER SAFE", "MICROWAVE OVEN SAFE" (store photos 2026-10)
const microwave = /microwave[\s-]?(?:oven[\s-]?)?safe|microwavable|microwaveable|safe for (?:the )?microwave|microwave[\s-]?reheat|microwave\s*(?:,|and|&)\s*(?:[a-z]+\s*(?:,|and|&)?\s*){1,3}safe/i;
const microwaveOven = /microwave ovens?/gi;
const noOven = /not (?:conventional )?oven[\s-]?safe|not ovenable|not for (?:use in )?(?:the |a )?(?:conventional |toaster )?oven|do not (?:use|cook|heat|place|put)(?: it| tray| this)? in (?:the |a )?(?:conventional |toaster )?oven|microwave only/i;
const noOvenG = new RegExp(noOven.source, 'gi');
const doNot = /do not microwave(?!\s*(?:the\s*)?lids?\b)|not microwave[\s-]?safe|not for (?:use in )?(?:the )?microwave/i;
// heat without the lid: "WITHOUT LID", "DO NOT MICROWAVE LID", "REMOVE LID BEFORE ...", "WITH LID REMOVED"
const lidOff = /without (?:the )?lid|remove (?:the )?lid|lid (?:is )?removed|do not microwave (?:the )?lids?\b/i;
const glass = /\bglass\b|borosilicate/i;
const ceramic = /stoneware|ceramic|porcelain|earthenware/i;
const melamine = /bamboo|melamine/i; // 'bamboo ware' is melamine resin with bamboo fibre [S82]
const paper = /\bpaper(?:board)?\b|\bfib(?:er|re)\b|\bcardboard\b|pressed paper|compostable|bagasse|sugarcane/i;
const foam = /\bfoam\b|styrofoam|\beps\b/i;
const cupWord = /\bcups?\b|\bbowls?\b/i;
const RESIN = { 1: 'PET', 2: 'PE', 3: 'PVC', 4: 'PE', 5: 'PP', 6: 'PS', 7: 'OTHER' };

export function read(text) {
  let code = null;
  const m1 = text.match(codeAfter), m2 = text.match(codeBefore), m3 = text.match(codeHash), m4 = text.match(codeSymbol);
  if (m1) code = Number(m1[1]); else if (m2) code = Number(m2[2]); else if (m4) code = m4[0].charCodeAt(0) - 0x2672; else if (m3) code = Number(m3[1]);
  const polymers = new Set();
  if (cpet.test(text)) polymers.add('CPET');
  if (pet.test(text)) polymers.add('PET');
  if (pp.test(text)) polymers.add('PP');
  if (ps.test(text)) polymers.add('PS');
  if (pe.test(text)) polymers.add('PE');
  if (pvc.test(text)) polymers.add('PVC');
  if (code !== null) polymers.add(RESIN[code]);
  const dn = doNot.test(text);
  const no = noOven.test(text);
  return { resin_code: code, polymers: [...polymers].sort(), oven: !no && oven.test(text.replace(noOvenG, ' ').replace(microwaveOven, 'microwave')), microwave: !dn && microwave.test(text), do_not: dn,
           paper: paper.test(text) && !melamine.test(text), foam: foam.test(text), cup: cupWord.test(text),
           lid_off: lidOff.test(text), glass: glass.test(text), ceramic: ceramic.test(text), melamine: melamine.test(text) };
}

export function candidates(c) {
  const out = [];
  const add = (k) => { if (!out.includes(k)) out.push(k); };
  const p = new Set(c.polymers);
  const inert = c.glass || c.ceramic;
  if (c.melamine) add('melamine');
  if (c.glass) add('glass');
  if (c.ceramic) add('ceramic');
  if (p.has('CPET')) add('cpet_tray');
  if (c.foam) add('eps_foam');
  if (p.has('PS') && !c.foam) add('ps_rigid');
  if (c.paper) { if (c.oven) add('pet_board_tray'); if (c.cup) add('paper_cup'); add('paperboard_tray'); }
  if (p.has('PET')) { if (c.oven) add('cpet_tray'); else { add('pet_clamshell'); add('cpet_tray'); } }
  if (p.has('PP')) add('pp_container');
  if (c.oven && !c.paper && !inert && !c.melamine) add('cpet_tray');
  if (c.microwave && !p.has('PET') && !p.has('CPET') && !c.paper && !inert && !c.melamine) add('pp_container');
  return out;
}

export function decisive(c, key) {
  const p = new Set(c.polymers);
  switch (key) {
    case 'cpet_tray': return p.has('CPET') || (p.has('PET') && c.oven);
    case 'pp_container': return c.resin_code === 5 || p.has('PP');
    case 'eps_foam': return c.foam;
    case 'ps_rigid': return c.resin_code === 6 || p.has('PS');
    case 'pet_board_tray': return c.paper && c.oven;
    case 'paper_cup': return c.paper && c.cup;
    case 'glass': return c.glass && !c.ceramic && p.size === 0;
    case 'ceramic': return c.ceramic && !c.glass && p.size === 0;
    case 'melamine': return c.melamine;
    default: return false;
  }
}

export const SAMPLES = {
  cpet_tray: 'DUAL OVENABLE\n-40°F TO 400°F\nPETE 1',
  cpet_word: 'CPET tray. Microwave and conventional oven safe',
  pp_cup: '5 PP\nMICROWAVE SAFE\nBPA FREE',
  pp_symbol: '♷ microwave safe',
  clamshell: '#1 PET  Recyclable',
  ps_not_safe: 'Not microwave safe 6 PS',
  foam_cup: 'Foam cup. Do not microwave',
  ovenable_board: 'OVENABLE PAPERBOARD TRAY. Do not use under broiler',
  paper_cup: 'Paper cup. Microwavable. Fill to line',
  nothing: 'Keep frozen. Cook thoroughly.',
  microwavable_only: 'Microwavable',
  oven_limit_c: 'Safe to 220 C, -40 C to 220 C',
  pet_not_oven: '1 PETE Not oven safe',
  pp_no_oven: 'Do not use in conventional oven. Microwave safe 5 PP',
  other_code: '7 OTHER microwave safe',
  microwave_only: 'Microwave only. Dual ovenable tray not included',
  // markings read from the student's store photos (2026-10-14), OCR text cleaned up
  real_signature_7cup: 'SHARE LIDS SAFE FOR MICROWAVE (WITHOUT LID) REFRIGERATOR & DISHWASHER 7 CUPS SQUARE FOOD STORAGE',
  real_signature_lid: 'WASH BEFORE USE | DO NOT MICROWAVE LID | PRODUCT OF USA',
  real_rubbermaid_easystore: 'WASH BEFORE USE | MICROWAVE REHEATABLE | MADE IN USA',
  real_goodcook_meal_prep: 'DISHWASHER SAFE - TOP RACK ONLY. MICROWAVE & FREEZER SAFE. FOR MICROWAVE REHEATING AND DEFROSTING, REMOVE LID BEFORE PLACING IN MICROWAVE.',
  real_signature_snack: 'CAUTION: DO NOT USE IN CONVENTIONAL OVENS, UNDER BROWNING ELEMENTS/BROILERS, FOR BOILING OR ON STOVETOPS. BEFORE MICROWAVING, REMOVE LID AND PLACE LOOSELY ON TOP TO VENT.',
  real_threshold_stoneware: 'STONEWARE DINNER PLATE Dishwasher Safe Microwave Safe May Get Hot in Microwave',
  real_figmint_glass: 'Glass Measuring Cup with Lid. Microwave safe with lid removed. Oven safe up to 350°F (176.7°C)',
  real_brilliance_glass: 'BRILLIANCE GLASS OVEN-SAFE (450°F)* 100% LEAKPROOF MICROWAVE-SAFE VENTS *only glass bases are oven-safe',
  real_open_nature_plates: 'open nature free from BPA COMPOSTABLE 20 PLATES CUT RESISTANT MICROWAVE OVEN SAFE',
  real_paper_plates: 'Heavy Duty Paper Plates. Microwavable. Commercially compostable only',
  real_readymeals_lid: 'REMOVE LID BEFORE MICROWAVING',
  real_anchor_base: '5 PP MICROWAVE SAFE PATENT PENDING ANCHORPAC.COM',
  real_tj_tray: '1 PET',
  real_bamboo_bowl: 'HARVEST BAMBOO FIBER SERVING BOWL MADE IN CHINA',
};

if (import.meta.url === `file://${process.argv[1]}`) {
  const out = {};
  for (const [k, v] of Object.entries(SAMPLES)) { const c = read(v); const cand = candidates(c); out[k] = { text: v, cues: c, candidates: cand, decisive: cand.length === 1 && decisive(c, cand[0]) }; console.log(k, JSON.stringify(c), candidates(c)); }
  if (process.argv[2] === '--write') fs.writeFileSync(new URL('../test/fixtures/cues_vectors.json', import.meta.url), JSON.stringify(out, null, 1));
}
