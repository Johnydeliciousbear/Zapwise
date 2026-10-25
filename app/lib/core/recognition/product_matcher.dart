// Finds which product a package photo shows by combining three signals:
//   barcode   exact UPC/EAN match (only if a barcode happens to be visible; never required)
//   text      words read by OCR compared with the product's brand and name words
//   image     cosine similarity between the photo embedding and photos of each product
//
// Image thresholds were first set from ml/retrieval_eval.py on TrashNet photos (0.64 / 0.84). The
// student's 68 real product photos (ml/field_photo_eval.py, 2026-10-14) showed that a different
// product can look as close as cosine 0.81 (95th percentile of wrong nearest matches, max 0.84),
// while the same product photographed from the same side scored 0.81-0.93. Image evidence now
// starts at 0.81 and is full at 0.93, so the baseline model can no longer push a wrong product to
// "confirm" on its own. Re-run both scripts after retraining the model and update [MatcherConfig].
import 'dart:math' as m;
import 'dart:typed_data';

import '../data/asset_repository.dart';
import '../data/models.dart';

class MatcherConfig {
  final double imageLow; // cosine treated as "no evidence"
  final double imageHigh; // cosine treated as "strong evidence"
  final double confirmScore; // show a single "Is this your product?" card
  final double confirmMargin;
  final double chooseScore; // show the top 3 to pick from; below this ask to register the product
  const MatcherConfig({this.imageLow = 0.81, this.imageHigh = 0.93, this.confirmScore = 0.75, this.confirmMargin = 0.15, this.chooseScore = 0.45});
}

enum MatchDecision { confirm, choose, register }

class Candidate {
  final Product product;
  final double score;
  final double text;
  final double image;
  final bool barcode;
  const Candidate(this.product, this.score, this.text, this.image, this.barcode);
}

class MatchResult {
  final List<Candidate> ranked;
  final MatchDecision decision;
  const MatchResult(this.ranked, this.decision);
  Candidate? get best => ranked.isEmpty ? null : ranked.first;
}

String normalizeCode(String code) => code.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');

/// Key used to compare two barcodes. Store-packed random-weight items (UPC-A with number system 2,
/// or an EAN-13 starting with 2) carry the price in their last digits, so a pork bun at $9.99 and
/// one at $10.49 have different codes. Only the item part is compared for those (deli labels in
/// the student's Safeway photos, 2026-10).
String barcodeKey(String code) {
  final n = normalizeCode(code);
  if (n.length == 12 && n.startsWith('2')) return 'rw:${n.substring(0, 6)}';
  if (n.length == 13 && n.startsWith('2')) return 'rw:${n.substring(0, 7)}';
  return n;
}

Set<String> ocrTokens(String text) {
  final t = text.toLowerCase().replaceAll("'", '').replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  return {for (final w in t.split(' ')) if (w.length > 1) w};
}

/// Levenshtein distance with early exit above [limit].
int editDistance(String a, String b, {int limit = 2}) {
  if ((a.length - b.length).abs() > limit) return limit + 1;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    var rowMin = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = m.min(m.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      rowMin = m.min(rowMin, cur[j]);
    }
    if (rowMin > limit) return limit + 1;
    prev = cur;
  }
  return prev[b.length];
}

double cosine(Float32List a, Float32List b) {
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na == 0 || nb == 0) return 0.0;
  return dot / (m.sqrt(na) * m.sqrt(nb));
}

class ProductMatcher {
  final List<Product> products;
  final Map<String, List<Float32List>> vectors;
  final MatcherConfig config;
  late final Map<String, double> _idf;

  ProductMatcher(this.products, {Map<String, List<Float32List>>? vectors, this.config = const MatcherConfig()}) : vectors = vectors ?? const {} {
    final df = <String, int>{};
    for (final p in products) {
      for (final t in p.searchTokens.toSet()) {
        df[t] = (df[t] ?? 0) + 1;
      }
    }
    final n = products.length;
    _idf = {for (final e in df.entries) e.key: m.log(1.0 + n / e.value)};
  }

  factory ProductMatcher.fromAssets(ZapAssets a, {Map<String, List<Float32List>> userVectors = const {}, MatcherConfig config = const MatcherConfig()}) {
    final v = <String, List<Float32List>>{};
    a.catalog.vectors.forEach((k, list) => v[k] = [...list]);
    userVectors.forEach((k, list) => v[k] = [...(v[k] ?? const []), ...list]);
    return ProductMatcher(a.products, vectors: v, config: config);
  }

  bool _tokenFound(String p, Set<String> ocr) {
    if (ocr.contains(p)) return true;
    if (p.length < 5) return false;
    for (final t in ocr) {
      if ((t.length - p.length).abs() <= 1 && editDistance(p, t, limit: 1) <= 1) return true;
    }
    return false;
  }

  double textScore(Product p, Set<String> ocr) {
    if (ocr.isEmpty || p.searchTokens.isEmpty) return 0.0;
    var total = 0.0, hit = 0.0;
    for (final t in p.searchTokens) {
      final w = _idf[t] ?? 1.0;
      total += w;
      if (_tokenFound(t, ocr)) hit += w;
    }
    final brandTokens = ocrTokens(p.brand).where((t) => p.searchTokens.contains(t)).toList();
    final brandHit = brandTokens.isNotEmpty && brandTokens.every((t) => _tokenFound(t, ocr));
    return m.min(1.0, 0.85 * hit / total + (brandHit ? 0.15 : 0.0));
  }

  double imageScore(Product p, Float32List? emb) {
    if (emb == null) return 0.0;
    final vs = vectors[p.id];
    if (vs == null || vs.isEmpty) return 0.0;
    var best = -1.0;
    for (final v in vs) {
      best = m.max(best, cosine(emb, v));
    }
    return ((best - config.imageLow) / (config.imageHigh - config.imageLow)).clamp(0.0, 1.0).toDouble();
  }

  MatchResult match({List<String> barcodes = const [], String ocrText = '', Float32List? embedding}) {
    final codes = {for (final b in barcodes) barcodeKey(b)}..remove('');
    final ocr = ocrTokens(ocrText);
    final out = <Candidate>[];
    for (final p in products) {
      final bc = p.upc != null && codes.contains(barcodeKey(p.upc!));
      final t = textScore(p, ocr);
      final i = imageScore(p, embedding);
      final score = bc ? 1.0 : 1.0 - (1.0 - t) * (1.0 - i);
      out.add(Candidate(p, score, t, i, bc));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    final top = out.isEmpty ? 0.0 : out.first.score;
    final second = out.length > 1 ? out[1].score : 0.0;
    final decision = (out.isNotEmpty && out.first.barcode) || (top >= config.confirmScore && top - second >= config.confirmMargin)
        ? MatchDecision.confirm
        : (top >= config.chooseScore ? MatchDecision.choose : MatchDecision.register);
    return MatchResult(out.take(decision == MatchDecision.choose ? 3 : 5).toList(), decision);
  }
}
