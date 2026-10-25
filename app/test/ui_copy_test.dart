import 'package:flutter_test/flutter_test.dart';
import 'package:zapwise/screens/register/register_screen.dart' show netGramsFromText;
import 'package:zapwise/ui/copy.dart';
import 'package:zapwise/ui/soft.dart' show BandKind;

void main() {
  test('percent and time formats', () {
    expect(pctText(null), '–');
    expect(pctText(0), '~0%');
    expect(pctText(0.05), '<0.1%');
    expect(pctText(0.13), '0.1%');
    expect(pctText(3.44), '3.4%');
    expect(pctText(12.4), '12%');
    expect(mmss(210), '3:30');
    expect(timeWords(45), '45 s');
    expect(timeWords(120), '2 min');
    expect(timeWords(150), '2 min 30 s');
  });

  test('assumed-wattage note only shows when it changes the time', () {
    const flags = ['ref_watt_assumed', 'fat_unknown', 'below_recipe_energy'];
    expect(flagNotes(flags, watt: 1100, refWatt: 1100), [kFlagText['below_recipe_energy']]);
    expect(flagNotes(flags, watt: 700, refWatt: 1100), [kFlagText['ref_watt_assumed'], kFlagText['below_recipe_energy']]);
    expect(flagNotes(flags, watt: 700, refWatt: 1100, practical: false), [kFlagText['fat_unknown']]);
  });

  test('result headline says what to do', () {
    expect(verdictText(BandKind.lower, inert: false, containerKey: 'pp_container'), 'Low. A plate makes it almost zero.');
    expect(verdictText(BandKind.lower, inert: false, containerKey: 'paper_cup'), 'Low. A bowl makes it almost zero.');
    expect(verdictText(BandKind.lower, inert: true, containerKey: 'glass'), startsWith('No plastic'));
    expect(limitCaption('lead', 'your'), contains('reference point'));
    expect(limitCaption('phthalate_dehp_eq', 'your'), 'of your daily\nsafe limit');
  });

  test('net weight from label text', () {
    expect(netGramsFromText('NET WT 10 OZ (283g)'), 283);
    expect(netGramsFromText('Net wt 9.5 oz'), 269);
    expect(netGramsFromText('no weight here'), isNull);
  });
}
