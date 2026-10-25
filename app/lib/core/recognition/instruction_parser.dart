// Turns the OCR text of a package's cooking directions into recipe steps.
//
// Rule based on purpose: every decision can be traced to a pattern below, which matters when a
// student has to explain how the app works. Handles a single reference wattage
// ("1100 watts ... cook 3 1/2 min"), wattage tables, one row per line or several in a line
// ("1200 W 5 1/2 min / 1000 W 6 min"), ranges ("2 to 3 minutes", "1-2 min"), clock style
// times ("2:15"), mixed-unit ranges ("30 sec-1 min"), stand times and "do not microwave"
// statements (a "do not microwave" about a sauce packet or lid does not count for the meal).
//
// tool/parser_check.mjs runs the same rules in JavaScript (same regex dialect) on sample
// label texts; keep the two in step when changing a pattern.
import '../data/models.dart';

class ParsedInstructions {
  final Recipe recipe;
  final double? refWatt;
  final List<String> notes;
  const ParsedInstructions(this.recipe, this.refWatt, this.notes);

  bool get hasCookTime => recipe.steps.any((s) => (s.kind == StepKind.cook && s.timeS != null) || s.kind == StepKind.cookTable);
}

class TimeSpan {
  final double lo;
  final double? hi;
  final int start;
  final int end;
  const TimeSpan(this.lo, this.hi, this.start, this.end);
}

const _num = r'(?:\d+(?:\.\d+)?(?:\s+[13]/[24])?|[13]/[24])';
final _timeRe = RegExp(
  '(?<a>$_num)\\s*(?:(?:to|-|or)\\s*(?<b>$_num)\\s*)?(?<u>minutes?|mins?|min|seconds?|secs?|sec)(?![a-z])'
  '(?:\\.?\\s*(?:and\\s*)?(?<c>\\d+)\\s*(?:seconds?|secs?|sec)(?![a-z]))?',
  caseSensitive: false,
);
final _clockRe = RegExp(r'(?<![\d.:])(\d{1,2}):([0-5]\d)(?![\d:])');
// "30 SEC-1 MINUTES" (store deli label): a range whose two ends carry different units
final _mixedRe = RegExp('(?<a>$_num)\\s*(?:seconds?|secs?|sec)\\s*(?:to|-)\\s*(?<b>$_num)\\s*(?:minutes?|mins?|min)(?![a-z])', caseSensitive: false);
final _wattRe = RegExp(r'(\d{3,4})\s*-?\s*(?:watts?|w)(?![a-z])', caseSensitive: false);
final _minWattRe = RegExp(r'(?:below|under|less than)\s*(\d{3,4})\s*-?\s*(?:watts?|w)(?![a-z])', caseSensitive: false);
final _doNotRe = RegExp(r'do\s*not\s*(?:cook\s*in\s*(?:the\s*|a\s*)?)?microwave|not\s*(?:recommended\s*)?for\s*microwave|oven\s*(?:bake\s*)?only', caseSensitive: false);
// "SAUCE PACKET: DO NOT MICROWAVE" is about a part of the pack, not the meal (P.F. Chang's egg rolls, store photo)
final _componentRe = RegExp(r'packet|sachet|sauce cup|\blid\b', caseSensitive: false);
// "continue cooking in 30 second intervals" is a top-up rule, not a cook step (Factor, store photo)
final _intervalRe = RegExp(r'^\s*(?:-\s*)?(?:intervals?|increments?)', caseSensitive: false);
final _otherStart = RegExp(r'^(?:conventional oven|oven|toaster oven|stove ?top|air fryer|skillet|saucepan)\b');
final _ovenTemp = RegExp(r'\b(?:[34]\d\d)\s*°?\s*f\b');
final _standRe = RegExp(r'\bstand|let (?:it )?sit|\brest\b');
final _actionRe = RegExp(r'stir|vent|remove|peel|puncture|pierce|\bcut\b|slit|rotate|re-?cover|\bcover\b|replace|turn over|fill|add water|tear');

double _numValue(String s) {
  var v = 0.0;
  for (final p in s.trim().split(RegExp(r'\s+'))) {
    if (p.contains('/')) {
      final ab = p.split('/');
      v += double.parse(ab[0]) / double.parse(ab[1]);
    } else {
      v += double.parse(p);
    }
  }
  return v;
}

String normalizeLabelText(String text) => text
    .replaceAll('½', ' 1/2')
    .replaceAll('¼', ' 1/4')
    .replaceAll('¾', ' 3/4')
    .replaceAll(RegExp(r'[‐-―]'), '-')
    .replaceAll(RegExp(r'[ \t]+'), ' ');

/// All time expressions in [s], in order, in seconds.
List<TimeSpan> findTimes(String s) {
  final out = <TimeSpan>[];
  for (final mm in _mixedRe.allMatches(s)) {
    out.add(TimeSpan(_numValue(mm.namedGroup('a')!), _numValue(mm.namedGroup('b')!) * 60, mm.start, mm.end));
  }
  for (final mm in _timeRe.allMatches(s)) {
    if (out.any((t) => mm.start < t.end && mm.end > t.start)) continue;
    final unit = mm.namedGroup('u')!.toLowerCase();
    final f = unit.startsWith('s') ? 1.0 : 60.0;
    var lo = _numValue(mm.namedGroup('a')!) * f;
    final bS = mm.namedGroup('b');
    double? hi = bS == null ? null : _numValue(bS) * f;
    final c = mm.namedGroup('c');
    if (c != null && f == 60.0) {
      lo += double.parse(c);
      if (hi != null) hi += double.parse(c);
    }
    out.add(TimeSpan(lo, hi, mm.start, mm.end));
  }
  for (final mm in _clockRe.allMatches(s)) {
    if (out.any((t) => mm.start < t.end && mm.end > t.start)) continue;
    out.add(TimeSpan(double.parse(mm.group(1)!) * 60 + double.parse(mm.group(2)!), null, mm.start, mm.end));
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// Lines, then sentences. Numbered list markers ("2. ", "3) ") and full stops end a sentence;
/// decimals such as "3.5" are kept.
List<String> splitSentences(String text) {
  final parts = <String>[];
  for (final line in normalizeLabelText(text).split(RegExp(r'[\n|•;]'))) {
    final cleaned = line.replaceAll(RegExp(r'(^|\s)\d{1,2}[.)](?=\s)'), '\u0000');
    for (final p in cleaned.split(RegExp(r'\u0000|(?<!\d)\.(?!\d)|\.(?=\s|$)'))) {
      final q = p.trim();
      if (q.isNotEmpty) parts.add(q);
    }
  }
  return parts;
}

class _Sentence {
  final String text;
  final String lower;
  final List<RegExpMatch> watts;
  final List<TimeSpan> times;
  _Sentence(this.text)
      : lower = text.toLowerCase(),
        watts = _wattRe.allMatches(text).toList(),
        times = findTimes(text);

  bool get isMinWatt => _minWattRe.hasMatch(text);

  /// (watt, time) pairs where a wattage is followed by a time with no other wattage in between.
  List<WattEntry> get pairs {
    final out = <WattEntry>[];
    if (isMinWatt) return out;
    for (var i = 0; i < watts.length; i++) {
      final w = watts[i];
      final nextW = i + 1 < watts.length ? watts[i + 1].start : text.length;
      final t = times.where((t) => t.start >= w.end && t.start < nextW).toList();
      if (t.isEmpty) continue;
      if (t.first.start - w.end > 25) continue; // too far apart to be a table row
      out.add(WattEntry(double.parse(w.group(1)!), t.first.lo, t.first.hi));
    }
    return out;
  }
}

enum _Section { unknown, microwave, other }

ParsedInstructions parseInstructions(String ocrText, {double defaultWatt = 1100}) {
  final notes = <String>[];
  final sentences = [for (final s in splitSentences(ocrText)) _Sentence(s)];
  final full = normalizeLabelText(ocrText);

  double? minWatt;
  final mw = _minWattRe.firstMatch(full);
  if (mw != null) minWatt = double.parse(mw.group(1)!);
  final doNot = sentences.any((s) => _doNotRe.hasMatch(s.text) && !_componentRe.hasMatch(s.text));
  if (doNot) notes.add('label says not to microwave');

  // pass 1: sections
  var section = _Section.unknown;
  final sec = <_Section>[];
  for (final s in sentences) {
    if (_otherStart.hasMatch(s.lower) || s.lower.contains('preheat') || _ovenTemp.hasMatch(s.lower)) {
      section = _Section.other;
    } else if (s.lower.contains('microwave') && !s.isMinWatt && !_doNotRe.hasMatch(s.text)) {
      section = _Section.microwave;
    }
    sec.add(section);
  }

  // pass 2: wattage table rows anywhere in the microwave text
  final table = <WattEntry>[];
  final rowIdx = <int>{};
  for (var i = 0; i < sentences.length; i++) {
    if (sec[i] == _Section.other) continue;
    final pr = sentences[i].pairs;
    if (pr.isNotEmpty && sentences[i].times.length == pr.length) {
      table.addAll(pr);
      rowIdx.add(i);
    }
  }
  final hasTable = table.length >= 2;
  // reference wattage stated outside the table rows (e.g. "Microwave (1000 watts)")
  double? refCandidate;
  for (var i = 0; i < sentences.length && refCandidate == null; i++) {
    final s = sentences[i];
    if (sec[i] != _Section.other && !rowIdx.contains(i) && !s.isMinWatt && s.watts.isNotEmpty) refCandidate = double.parse(s.watts.first.group(1)!);
  }
  final altRow = !hasTable && table.length == 1 && refCandidate != null && table.first.watt != refCandidate;

  // pass 3: steps
  final steps = <LabelStep>[];
  final ovenText = StringBuffer();
  double? refWatt;
  var tableStepAdded = false;
  for (var i = 0; i < sentences.length; i++) {
    final s = sentences[i];
    if (_doNotRe.hasMatch(s.text) || s.isMinWatt) continue;
    if (sec[i] == _Section.other) {
      ovenText.write('${s.text}. ');
      continue;
    }
    if (hasTable && rowIdx.contains(i)) {
      if (!tableStepAdded) {
        steps.add(LabelStep(kind: StepKind.cookTable, text: s.text));
        tableStepAdded = true;
      }
      continue;
    }
    if (altRow && rowIdx.contains(i)) continue;
    if (s.watts.isNotEmpty && refWatt == null) refWatt = double.parse(s.watts.first.group(1)!);
    final times = [for (final t in s.times) if (!_intervalRe.hasMatch(s.text.substring(t.end))) t];
    if (times.isEmpty) {
      if (_actionRe.hasMatch(s.lower) || times.length < s.times.length) steps.add(LabelStep(kind: StepKind.action, text: s.text));
      continue;
    }
    for (final t in times) {
      final from = t.start - 40 < 0 ? 0 : t.start - 40;
      final ctx = s.lower.substring(from, t.end);
      steps.add(LabelStep(kind: _standRe.hasMatch(ctx) ? StepKind.stand : StepKind.cook, text: s.text, timeS: t.lo, timeSMax: t.hi));
    }
  }

  // a single alternative row ("700 W: 7 min") next to a stated reference wattage forms a two-row table
  var wattTable = hasTable ? table : <WattEntry>[];
  var finalSteps = steps;
  if (altRow && refWatt != null) {
    final cook = steps.where((x) => x.kind == StepKind.cook && x.timeS != null).toList();
    if (cook.length == 1) {
      wattTable = [WattEntry(refWatt, cook.first.timeS!, cook.first.timeSMax), table.first];
      finalSteps = [for (final x in steps) identical(x, cook.first) ? LabelStep(kind: StepKind.cookTable, text: x.text) : x];
    }
  }
  final usesTable = wattTable.length >= 2;
  final hasCook = finalSteps.any((s) => (s.kind == StepKind.cook && s.timeS != null) || s.kind == StepKind.cookTable);
  if (refWatt == null && !usesTable && hasCook) notes.add('no wattage found; using ${defaultWatt.round()} W');
  final recipe = Recipe(
    refWatt: usesTable ? wattTable.map((e) => e.watt).reduce((a, b) => a > b ? a : b) : (refWatt ?? defaultWatt),
    refWattAssumed: refWatt == null && !usesTable,
    steps: finalSteps,
    wattTable: usesTable ? wattTable : const [],
    completeness: !hasCook ? 'none' : ((refWatt != null || usesTable) ? 'complete' : 'partial'),
    doNotMicrowave: doNot ? 'yes' : 'no',
    ovenOnly: doNot,
    minWatt: minWatt,
    ovenText: ovenText.toString().trim(),
  );
  return ParsedInstructions(recipe, refWatt, notes);
}
