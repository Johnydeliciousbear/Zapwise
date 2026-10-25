// Expected results come from tool/parser_check.mjs (same patterns in JavaScript),
// stored in test/fixtures/parser_vectors.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapwise/core/data/models.dart';
import 'package:zapwise/core/recognition/instruction_parser.dart';

String kindName(StepKind k) => switch (k) {
      StepKind.cook => 'cook',
      StepKind.cookTable => 'cook_table',
      StepKind.stand => 'stand',
      StepKind.oven => 'oven',
      StepKind.action => 'action',
    };

void main() {
  final cases = jsonDecode(File('test/fixtures/parser_vectors.json').readAsStringSync()) as Map<String, dynamic>;

  for (final e in cases.entries) {
    test('parses sample "${e.key}"', () {
      final text = e.value['text'] as String;
      final exp = e.value['expected'] as Map<String, dynamic>;
      final got = parseInstructions(text).recipe;
      expect(got.refWatt, (exp['ref_watt'] as num).toDouble());
      expect(got.refWattAssumed, exp['ref_watt_assumed']);
      expect(got.completeness, exp['completeness']);
      expect(got.doNotMicrowave == 'yes', exp['do_not_microwave']);
      expect(got.minWatt, (exp['min_watt'] as num?)?.toDouble());
      final steps = exp['steps'] as List;
      expect(got.steps.map((s) => kindName(s.kind)).toList(), [for (final s in steps) s['kind']]);
      for (var i = 0; i < steps.length; i++) {
        expect(got.steps[i].timeS, (steps[i]['time_s'] as num?)?.toDouble(), reason: 'step $i');
        expect(got.steps[i].timeSMax, (steps[i]['time_s_max'] as num?)?.toDouble(), reason: 'step $i');
      }
      final table = exp['watt_table'] as List;
      expect(got.wattTable.length, table.length);
      for (var i = 0; i < table.length; i++) {
        expect(got.wattTable[i].watt, (table[i]['watt'] as num).toDouble());
        expect(got.wattTable[i].timeS, (table[i]['lo'] as num).toDouble());
        expect(got.wattTable[i].timeSMax, (table[i]['hi'] as num?)?.toDouble());
      }
    });
  }

  test('time expressions', () {
    double first(String s) => findTimes(s).first.lo;
    expect(first('cook 3 1/2 minutes'), 210);
    expect(first('heat 2:15 on high'), 135);
    expect(first('Microwave 1 minute 30 seconds'), 90);
    expect(first('90 SEC'), 90);
    expect(findTimes('2 to 3 minutes').first.hi, 180);
    expect(findTimes('1100 watts').isEmpty, isTrue);
  });
}
