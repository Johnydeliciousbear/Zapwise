import 'package:flutter_test/flutter_test.dart';
import 'package:zapwise/ui/copy.dart';
import 'package:zapwise/ui/i18n.dart';

void main() {
  test('English passes through untouched', () {
    expect(trFor('en', 'Move it to a plate'), 'Move it to a plate');
    expect(trFor('es', ''), '');
  });

  test('exact Spanish strings', () {
    expect(trFor('es', 'Move it to a plate'), 'Pásalo a un plato');
    expect(trFor('es', 'Heat it all the way through'), 'Caliéntalo bien por dentro');
  });

  test('strings with numbers', () {
    expect(trFor('es', 'Box time at 1100 W'), 'Tiempo de la caja a 1100 W');
    expect(trFor('es', 'Likely 0.1% to 0.5%'), 'Probablemente entre 0.1% y 0.5%');
    expect(trFor('es', '2 more minutes: about 4.0× more'), '2 minutos más: unas 4.0 veces más');
    expect(trFor('es', 'of your daily limit\nfrom this tray'), 'de tu límite diario\nde esta bandeja');
    expect(trFor('es', 'Kid, 8 to 12, about 30 kg (66 lb)'), 'Niño, 8 a 12, unos 30 kg (66 lb)');
  });

  test('every age group and flag sentence has Spanish', () {
    for (final (_, label) in kAgeGroups) {
      expect(trFor('es', label), isNot(label), reason: label);
    }
    for (final t in kFlagText.values) {
      expect(trFor('es', t), isNot(t), reason: t);
    }
  });

  test('unknown text stays English instead of breaking', () {
    expect(trFor('es', 'Some sentence nobody translated'), 'Some sentence nobody translated');
  });

  test('0.5 sentences', () {
    expect(trFor('es', 'Heat it in the tray'), 'Calentar en la bandeja');
    expect(trFor('es', 'Heat it in the tray (7:09)'), 'Calentar en la bandeja (7:09)');
    expect(trFor('es', 'My glass dish'), 'Mi recipiente de vidrio');
    expect(trFor('es', 'In the oven'), 'En el horno');
    expect(trFor('es', 'In the oven\nTue 1:00 PM'), startsWith('En el horno\n'));
  });
}
