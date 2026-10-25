// JavaScript mirror of lib/core/recognition/instruction_parser.dart.
// Dart and JavaScript share the ECMAScript regex dialect, so this checks the patterns and the
// step logic on sample label texts without a Dart SDK:  node tool/parser_check.mjs
// The same samples are asserted in test/instruction_parser_test.dart.

const NUM = String.raw`(?:\d+(?:\.\d+)?(?:\s+[13]/[24])?|[13]/[24])`;
const timeRe = () => new RegExp(String.raw`(?<a>${NUM})\s*(?:(?:to|-|or)\s*(?<b>${NUM})\s*)?(?<u>minutes?|mins?|min|seconds?|secs?|sec)(?![a-z])` +
  String.raw`(?:\.?\s*(?:and\s*)?(?<c>\d+)\s*(?:seconds?|secs?|sec)(?![a-z]))?`, 'gi');
const clockRe = () => /(?<![\d.:])(\d{1,2}):([0-5]\d)(?![\d:])/g;
// "30 SEC-1 MINUTES" (store deli label): a range whose ends carry different units
const mixedRe = () => new RegExp(String.raw`(?<a>${NUM})\s*(?:seconds?|secs?|sec)\s*(?:to|-)\s*(?<b>${NUM})\s*(?:minutes?|mins?|min)(?![a-z])`, 'gi');
const wattRe = () => /(\d{3,4})\s*-?\s*(?:watts?|w)(?![a-z])/gi;
const minWattRe = /(?:below|under|less than)\s*(\d{3,4})\s*-?\s*(?:watts?|w)(?![a-z])/i;
const doNotRe = /do\s*not\s*(?:cook\s*in\s*(?:the\s*|a\s*)?)?microwave|not\s*(?:recommended\s*)?for\s*microwave|oven\s*(?:bake\s*)?only/i;
// "SAUCE PACKET: DO NOT MICROWAVE" is about a part, not the meal (P.F. Chang's egg rolls, store photo)
const componentRe = /packet|sachet|sauce cup|\blid\b/i;
// "continue cooking in 30 second intervals" is a top-up rule, not a cook step (Factor, store photo)
const intervalRe = /^\s*(?:-\s*)?(?:intervals?|increments?)/i;
const otherStart = /^(?:conventional oven|oven|toaster oven|stove ?top|air fryer|skillet|saucepan)\b/;
const ovenTemp = /\b(?:[34]\d\d)\s*°?\s*f\b/;
const standRe = /\bstand|let (?:it )?sit|\brest\b/;
const actionRe = /stir|vent|remove|peel|puncture|pierce|\bcut\b|slit|rotate|re-?cover|\bcover\b|replace|turn over|fill|add water|tear/;

const numValue = (s) => s.trim().split(/\s+/).reduce((v, p) => v + (p.includes('/') ? Number(p.split('/')[0]) / Number(p.split('/')[1]) : Number(p)), 0);
const normalize = (t) => t.replaceAll('½', ' 1/2').replaceAll('¼', ' 1/4').replaceAll('¾', ' 3/4').replace(/[‐-―]/g, '-').replace(/[ \t]+/g, ' ');

function findTimes(s) {
  const out = [];
  for (const m of s.matchAll(mixedRe())) out.push({ lo: numValue(m.groups.a), hi: numValue(m.groups.b) * 60, start: m.index, end: m.index + m[0].length });
  for (const m of s.matchAll(timeRe())) {
    if (out.some((t) => m.index < t.end && m.index + m[0].length > t.start)) continue;
    const f = m.groups.u.toLowerCase().startsWith('s') ? 1 : 60;
    let lo = numValue(m.groups.a) * f;
    let hi = m.groups.b === undefined ? null : numValue(m.groups.b) * f;
    if (m.groups.c !== undefined && f === 60) { lo += Number(m.groups.c); if (hi !== null) hi += Number(m.groups.c); }
    out.push({ lo, hi, start: m.index, end: m.index + m[0].length });
  }
  for (const m of s.matchAll(clockRe())) {
    const end = m.index + m[0].length;
    if (out.some((t) => m.index < t.end && end > t.start)) continue;
    out.push({ lo: Number(m[1]) * 60 + Number(m[2]), hi: null, start: m.index, end });
  }
  return out.sort((a, b) => a.start - b.start);
}

function splitSentences(text) {
  const parts = [];
  for (const line of normalize(text).split(/[\n|•;]/)) {
    const cleaned = line.replace(/(^|\s)\d{1,2}[.)](?=\s)/g, '\u0000');
    for (const p of cleaned.split(/\u0000|(?<!\d)\.(?!\d)|\.(?=\s|$)/)) {
      const q = (p ?? '').trim();
      if (q) parts.push(q);
    }
  }
  return parts;
}

function sentence(text) {
  const watts = [...text.matchAll(wattRe())].map((m) => ({ watt: Number(m[1]), start: m.index, end: m.index + m[0].length }));
  const times = findTimes(text);
  const isMinWatt = minWattRe.test(text);
  const pairs = [];
  if (!isMinWatt) {
    for (let i = 0; i < watts.length; i++) {
      const w = watts[i];
      const nextW = i + 1 < watts.length ? watts[i + 1].start : text.length;
      const t = times.filter((t) => t.start >= w.end && t.start < nextW);
      if (!t.length) continue;
      if (t[0].start - w.end > 25) continue;
      pairs.push({ watt: w.watt, lo: t[0].lo, hi: t[0].hi });
    }
  }
  return { text, lower: text.toLowerCase(), watts, times, isMinWatt, pairs };
}

export function parse(ocr, defaultWatt = 1100) {
  const notes = [];
  const S = splitSentences(ocr).map(sentence);
  const full = normalize(ocr);
  const mw = full.match(minWattRe);
  const minWatt = mw ? Number(mw[1]) : null;
  const doNot = S.some((s) => doNotRe.test(s.text) && !componentRe.test(s.text));
  if (doNot) notes.push('label says not to microwave');
  let section = 'unknown';
  const sec = [];
  for (const s of S) {
    if (otherStart.test(s.lower) || s.lower.includes('preheat') || ovenTemp.test(s.lower)) section = 'other';
    else if (s.lower.includes('microwave') && !s.isMinWatt && !doNotRe.test(s.text)) section = 'microwave';
    sec.push(section);
  }
  const table = [];
  const rowIdx = new Set();
  S.forEach((s, i) => {
    if (sec[i] === 'other') return;
    if (s.pairs.length && s.times.length === s.pairs.length) { table.push(...s.pairs); rowIdx.add(i); }
  });
  const hasTable = table.length >= 2;
  // reference wattage stated outside the table rows (e.g. "Microwave (1000 watts)")
  let refCandidate = null;
  S.forEach((s, i) => { if (refCandidate === null && sec[i] !== 'other' && !rowIdx.has(i) && !s.isMinWatt && s.watts.length) refCandidate = s.watts[0].watt; });
  const altRow = !hasTable && table.length === 1 && refCandidate !== null && table[0].watt !== refCandidate;
  const steps = [];
  let oven = '';
  let refWatt = null;
  let tableStepAdded = false;
  S.forEach((s, i) => {
    if (doNotRe.test(s.text) || s.isMinWatt) return;
    if (sec[i] === 'other') { oven += s.text + '. '; return; }
    if (hasTable && rowIdx.has(i)) { if (!tableStepAdded) { steps.push({ kind: 'cook_table', text: s.text }); tableStepAdded = true; } return; }
    if (altRow && rowIdx.has(i)) return;
    if (s.watts.length && refWatt === null) refWatt = s.watts[0].watt;
    const times = s.times.filter((t) => !intervalRe.test(s.text.substring(t.end)));
    if (!times.length) { if (actionRe.test(s.lower) || times.length < s.times.length) steps.push({ kind: 'action', text: s.text }); return; }
    for (const t of times) {
      const ctx = s.lower.substring(Math.max(0, t.start - 40), t.end);
      steps.push({ kind: standRe.test(ctx) ? 'stand' : 'cook', text: s.text, time_s: t.lo, time_s_max: t.hi });
    }
  });
  let wattTable = hasTable ? table : [];
  let finalSteps = steps;
  if (altRow && refWatt !== null) {
    const cook = steps.filter((x) => x.kind === 'cook' && x.time_s != null);
    if (cook.length === 1) {
      wattTable = [{ watt: refWatt, lo: cook[0].time_s, hi: cook[0].time_s_max }, table[0]];
      finalSteps = steps.map((x) => (x === cook[0] ? { kind: 'cook_table', text: x.text } : x));
    }
  }
  const usesTable = wattTable.length >= 2;
  const hasCook = finalSteps.some((s) => (s.kind === 'cook' && s.time_s != null) || s.kind === 'cook_table');
  if (refWatt === null && !usesTable && hasCook) notes.push(`no wattage found; using ${defaultWatt} W`);
  return {
    ref_watt: usesTable ? Math.max(...wattTable.map((e) => e.watt)) : (refWatt ?? defaultWatt),
    ref_watt_assumed: refWatt === null && !usesTable,
    steps: finalSteps.map(({ kind, time_s, time_s_max }) => ({ kind, time_s, time_s_max })),
    watt_table: usesTable ? wattTable : [],
    completeness: !hasCook ? 'none' : (refWatt !== null || usesTable ? 'complete' : 'partial'),
    do_not_microwave: doNot, min_watt: minWatt, oven_text: oven.trim(), notes,
  };
}

// ------------------------------------------------------------------ samples (written for testing, not copied labels)
export const SAMPLES = {
  single: `MICROWAVE DIRECTIONS
Cooking times based on a 1100 watt microwave oven. Ovens vary; adjust time as needed.
1. Cut film to vent.
2. Cook on HIGH 3 1/2 minutes.
3. Stir sauce and re-cover.
4. Cook on HIGH 1 1/2 to 2 1/2 minutes.
5. Let stand 1 minute. Product will be hot!
CONVENTIONAL OVEN 375°F
Remove film. Bake 40-45 minutes.`,
  table_lines: `Microwave: Place bag flat in microwave, this side up. Cook on HIGH:
1200 watts 5 1/2 min.
1000 watts 6 min.
800 watts 7 min.
Below 800 watts, use stovetop directions.
Let stand 1 to 2 minutes. Carefully hold corners and tear open.`,
  table_inline: `Microwave on HIGH: 1200W 5-5 1/2 MIN | 1000W 7-7 1/2 MIN | 700W 8 1/2-9 MIN. Let stand 1 minute in microwave.`,
  alt_line: `Microwave (1000 watts): Stand bag upright. Cook on HIGH 5 1/2 to 6 minutes. 700 W: 7 min. Let stand 1 minute.`,
  clock: `Fill to line with water. Microwave on HIGH for 2:15. Stir and let sit 1 minute.`,
  seconds: `Squeeze pouch to separate rice. Tear 2 inch vent. Heat on HIGH 90 seconds.`,
  min_sec: `Microwave 1 minute 30 seconds. Stir well.`,
  do_not: `DO NOT MICROWAVE. Oven bake only, raw chicken. Preheat oven to 375°F. Bake 30-35 minutes to 165°F.`,
  do_not_alt_row: `Not for microwave ovens above 1200 watts. Cook 5 minutes. 700 W: 7 min.`,
  internal_temp: `Cook on HIGH 4 minutes. Stir. Cook on HIGH 2 to 3 minutes or until hot (165°F). Let stand 2 minutes.`,
  ocr_noise: `MICROWAVE: 1100W
COOK 4 MIN. STIR
COOK 1 1/2 MIN.
STAND 1 MIN`,
};

const isMain = import.meta.url === `file://${process.argv[1]}`;
if (isMain) {
  for (const [k, v] of Object.entries(SAMPLES)) console.log(k, JSON.stringify(parse(v)));
}
