import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapwise/core/data/asset_repository.dart';
import 'package:zapwise/core/recognition/container_identifier.dart';
import 'package:zapwise/core/recognition/product_matcher.dart';

void main() {
  late ZapAssets assets;
  late ProductMatcher matcher;

  setUpAll(() {
    assets = ZapAssets.fromStrings(File('assets/data/zapwise_params.json').readAsStringSync(), File('assets/data/products.json').readAsStringSync());
    matcher = ProductMatcher.fromAssets(assets);
  });

  test('barcode in EAN-13 form finds the UPC-A product', () {
    final r = matcher.match(barcodes: ['0021131501143']);
    expect(r.decision, MatchDecision.confirm);
    expect(r.best!.product.id, 'zw-013');
  });

  test('barcodes read from the store photos (EAN-8, EAN-13, random weight)', () {
    expect(matcher.match(barcodes: ['00752831']).best!.product.id, 'zw-401'); // Trader Joe's EAN-8
    expect(matcher.match(barcodes: ['0031000700041']).best!.product.id, 'zw-426');
    expect(matcher.match(barcodes: ['0218190010994']).best!.product.id, 'zw-422'); // as photographed, $10.99
    final otherPrice = matcher.match(barcodes: ['0218190012495']); // same item, another weight and price
    expect(otherPrice.decision, MatchDecision.confirm);
    expect(otherPrice.best!.product.id, 'zw-422');
    expect(barcodeKey('0210703509995'), 'rw:210703');
    expect(barcodeKey('0031000700041'), '31000700041');
  });

  test('package text finds the product', () {
    expect(matcher.match(ocrText: "MARIE CALLENDER'S\nTurkey\nPOT PIE\nMade with tender white meat turkey").best!.product.id, 'zw-013');
    expect(matcher.match(ocrText: 'LEAN CUISINE PROTEIN KICK Spaghetti with Meat Sauce 25g protein').best!.product.id, 'zw-007');
    expect(matcher.match(ocrText: 'Birds Eye Steamfresh Asian Medley seasoned').best!.product.id, 'zw-023');
  });

  test('one wrong letter from OCR still matches', () {
    final r = matcher.match(ocrText: "Marie Callendr's Turkey Pot Pi");
    expect(r.decision, MatchDecision.confirm);
    expect(r.best!.product.id, 'zw-013');
  });

  test('brand-only text asks the user to choose', () {
    final r = matcher.match(ocrText: 'Healthy Choice Power Bowls');
    expect(r.decision, MatchDecision.choose);
    expect(r.ranked.length, 3);
  });

  test('text with no product words leads to registration', () {
    expect(matcher.match(ocrText: 'NET WT 10 OZ KEEP FROZEN').decision, MatchDecision.register);
  });

  test('image similarity alone can confirm a photographed product', () {
    final v = Float32List(1280);
    for (var i = 0; i < v.length; i++) {
      v[i] = (i % 7 == 0) ? 1.0 : 0.0;
    }
    final m2 = ProductMatcher(assets.products, vectors: {'zw-004': [v]});
    final r = m2.match(embedding: v);
    expect(r.best!.product.id, 'zw-004');
    expect(r.best!.image, 1.0);
    expect(r.decision, MatchDecision.confirm);
  });

  test('helpers', () {
    expect(normalizeCode('0 21131 50114 3'), '21131501143');
    expect(editDistance('callenders', 'callendrs'), 1);
    expect(editDistance('abc', 'xyz', limit: 1), 2);
  });

  test('baseline material output becomes a picture question', () {
    const keys = ['paper_family', 'glass', 'metal', 'paper_family', 'plastic_family', 'unknown'];
    final known = assets.params.containers.keys.toSet();
    final plastic = identifyContainer([0.02, 0.03, 0.01, 0.02, 0.9, 0.02], keys, known);
    expect(plastic.needsQuestion, isTrue);
    expect(plastic.askAmong.first, 'cpet_tray');
    // the baseline never decides alone (it called PP boxes "metal" in the store photos); it orders the choices
    final metal = identifyContainer([0.0, 0.02, 0.95, 0.01, 0.01, 0.01], keys, known);
    expect(metal.containerKey, isNull);
    expect(metal.askAmong.first, 'metal');
    expect(metal.askAmong, contains('pp_container'));
    for (final list in kFamilyChoices.values) {
      for (final k in list) {
        expect(known.contains(k), isTrue, reason: k);
      }
    }
  });
}
