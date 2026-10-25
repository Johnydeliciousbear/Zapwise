// Expected values come from tool/cues_check.mjs (same patterns in JavaScript).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapwise/core/recognition/container_cues.dart';
import 'package:zapwise/core/recognition/container_identifier.dart';

void main() {
  final cases = jsonDecode(File('test/fixtures/cues_vectors.json').readAsStringSync()) as Map<String, dynamic>;
  for (final e in cases.entries) {
    test('container markings "${e.key}"', () {
      final c = readContainerCues(e.value['text'] as String);
      final exp = e.value['cues'] as Map<String, dynamic>;
      expect(c.resinCode, exp['resin_code']);
      expect(c.polymers.toList()..sort(), [for (final p in exp['polymers'] as List) p as String]);
      expect(c.ovenClaim, exp['oven']);
      expect(c.microwaveClaim, exp['microwave']);
      expect(c.doNotMicrowave, exp['do_not']);
      expect(c.paper, exp['paper']);
      expect(c.foam, exp['foam']);
      expect(c.cup, exp['cup']);
      if (exp.containsKey('lid_off')) expect(c.lidOff, exp['lid_off']);
      if (exp.containsKey('glass')) expect(c.glass, exp['glass']);
      if (exp.containsKey('ceramic')) expect(c.ceramic, exp['ceramic']);
      if (exp.containsKey('melamine')) expect(c.melamine, exp['melamine']);
      final cand = candidatesFromCues(c);
      expect(cand, [for (final k in e.value['candidates'] as List) k as String]);
      expect(cand.length == 1 && cuesDecisive(c, cand.first), e.value['decisive']);
    });
  }

  test('decision: a decisive marking picks the container, a weak one asks', () {
    final pp = decideContainer(readContainerCues('5 PP MICROWAVE SAFE'), null);
    expect(pp.containerKey, 'pp_container');
    final weak = decideContainer(readContainerCues('Microwavable'), null);
    expect(weak.containerKey, isNull);
    expect(weak.askAmong.first, 'pp_container');
    final negated = decideContainer(readContainerCues('1 PETE Not oven safe'), null);
    expect(negated.containerKey, isNull);
    expect(negated.askAmong.take(2).toList(), ['pet_clamshell', 'cpet_tray']);
    final nothing = decideContainer(readContainerCues('Keep frozen'), null);
    expect(nothing.askAmong, kFamilyChoices['unknown']);
    final vision = decideContainer(readContainerCues(''), const ContainerGuess(containerKey: 'glass', confidence: 0.9, family: 'glass'));
    expect(vision.containerKey, 'glass');
  });

  test('store-photo labels: lid wording and stoneware', () {
    final lid = decideContainer(readContainerCues('WASH BEFORE USE | DO NOT MICROWAVE LID'), null);
    expect(lid.labelSaysDoNotMicrowave, isFalse);
    expect(lid.labelSaysLidOff, isTrue);
    final plate = decideContainer(readContainerCues('STONEWARE DINNER PLATE Dishwasher Safe Microwave Safe'), null);
    expect(plate.containerKey, 'ceramic');
    final glassCup = decideContainer(readContainerCues('Glass Measuring Cup. Microwave safe with lid removed. Oven safe up to 350°F'), null);
    expect(glassCup.containerKey, 'glass');
  });
}
