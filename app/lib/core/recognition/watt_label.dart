// Reads the rated output power from the label inside a microwave door (OCR text).
//
// Labels usually print both the electrical input ("Input 1500 W", "120V~ 60Hz 1500W") and
// the cooking output ("Output 1100 W", "Microwave output: 1.1 kW"). Package directions are
// written for the output power, so:
//   1. a value right after the word "output" wins;
//   2. values right after "input" or next to volts and hertz are dropped;
//   3. otherwise the smallest remaining value between 500 and 1800 W is used, because the
//      output is always lower than the input.

final _wattRe = RegExp(r'(\d{3,4}(?:[.,]\d+)?)\s*-?\s*(?:watts?|w)(?![a-z])', caseSensitive: false);
final _kwRe = RegExp(r'(\d(?:[.,]\d{1,2})?)\s*-?\s*kw(?![a-z])', caseSensitive: false);
final _outputRe = RegExp(r'output|cooking power|microwave power|rated (?:microwave )?power', caseSensitive: false);
final _inputRe = RegExp(r'input|consumption|\d{3}\s*v|\bhz\b|\d\s*a\b|amps?', caseSensitive: false);

class _WattHit {
  final double watt;
  final int start;
  const _WattHit(this.watt, this.start);
}

double? wattFromApplianceLabel(String text) {
  final hits = <_WattHit>[];
  for (final m in _wattRe.allMatches(text)) {
    final v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    if (v != null) hits.add(_WattHit(v, m.start));
  }
  for (final m in _kwRe.allMatches(text)) {
    final v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    if (v != null) hits.add(_WattHit(v * 1000, m.start));
  }
  if (hits.isEmpty) return null;
  hits.sort((a, b) => a.start.compareTo(b.start));

  String before(_WattHit h) => text.substring(h.start - 28 < 0 ? 0 : h.start - 28, h.start);
  String lineOf(_WattHit h) {
    final s = text.lastIndexOf('\n', h.start);
    final e = text.indexOf('\n', h.start);
    return text.substring(s < 0 ? 0 : s + 1, e < 0 ? text.length : e);
  }

  final plausible = hits.where((h) => h.watt >= 300 && h.watt <= 2000).toList();
  for (final h in plausible) {
    if (_outputRe.hasMatch(before(h))) return h.watt;
  }
  final rest = plausible.where((h) => !_inputRe.hasMatch(before(h)) && !_inputRe.hasMatch(lineOf(h))).toList();
  final pool = (rest.isNotEmpty ? rest : plausible).where((h) => h.watt >= 500 && h.watt <= 1800).toList();
  if (pool.isEmpty) return null;
  pool.sort((a, b) => a.watt.compareTo(b.watt));
  return pool.first.watt;
}
