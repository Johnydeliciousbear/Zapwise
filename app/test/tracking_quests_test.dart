import 'package:flutter_test/flutter_test.dart';
import 'package:zapwise/core/data/records.dart';
import 'package:zapwise/core/quests/quest_engine.dart';
import 'package:zapwise/core/tracking/exposure_log.dart';

MealRecord meal(DateTime at, {Map<String, double> g = const {}, String cs = 'ok', String status = 'ok', bool label = true, String c = 'cpet_tray'}) => MealRecord(
    profileId: 'me', productId: 'zw-001', containerKey: c, status: status, containerStatus: cs, watt: 1100, followedLabel: label, groupsPct: g, at: at);

void main() {
  final now = DateTime(2026, 10, 14, 19, 0); // a Wednesday

  test('daily totals add meals of the same group and day', () {
    final s = summarize([
      meal(DateTime(2026, 10, 14, 8), g: {'antimony': 1.5}),
      meal(DateTime(2026, 10, 14, 12), g: {'antimony': 2.0, 'phthalate_dehp_eq': 0.5}),
      meal(DateTime(2026, 10, 13, 12), g: {'antimony': 0.25}),
    ], now: now);
    expect(s.days.length, 7);
    expect(s.days.last.day, '2026-10-14');
    expect(s.days.last.groups['antimony'], closeTo(3.5, 1e-12));
    expect(s.days.last.headline, closeTo(3.5, 1e-12));
    expect(s.days[5].groups['antimony'], closeTo(0.25, 1e-12));
    expect(s.meanPerDay['antimony'], closeTo(3.75 / 7, 1e-12));
    expect(s.alerts, isEmpty);
  });

  test('alerts at the 20 % allocation and for blocked containers', () {
    final s = summarize([
      meal(DateTime(2026, 10, 14, 8), g: {'antimony': 12.0}),
      meal(DateTime(2026, 10, 14, 13), g: {'antimony': 9.0}),
      meal(DateTime(2026, 10, 12, 13), cs: 'block', status: 'block', c: 'eps_foam'),
    ], now: now);
    final kinds = s.alerts.map((a) => a.kind).toList();
    expect(kinds, contains(AlertKind.dayOverAllocation));
    expect(kinds, contains(AlertKind.highMeal));
    expect(kinds, contains(AlertKind.blockedContainerUsed));
    expect(kinds, isNot(contains(AlertKind.weekOverAllocation)));
  });

  test('meals outside the window are ignored', () {
    final s = summarize([meal(DateTime(2026, 10, 1), g: {'antimony': 50})], now: now);
    expect(s.days.every((d) => d.meals == 0), isTrue);
  });

  test('quests: starter, locks and weekly progress', () {
    const micro = Appliance(id: 'a', kind: ApplianceKind.microwave, name: 'Kitchen', ratedWatt: 1100);
    final shelf = [ShelfItem(id: 's', containerKey: 'ceramic', name: 'Plate', createdAt: DateTime(2026, 10, 1))];
    final meals = [
      meal(DateTime(2026, 10, 13, 12), cs: 'inert', c: 'ceramic', status: 'inert'),
      meal(DateTime(2026, 10, 14, 12), cs: 'inert', c: 'ceramic', status: 'inert'),
      meal(DateTime(2026, 10, 11, 12), cs: 'inert', c: 'ceramic', status: 'inert'), // Sunday of the previous week
    ];
    var st = questStates(QuestContext(appliances: [micro], shelf: shelf, meals: meals, claimed: {}, now: now));
    final starter = st.firstWhere((q) => q.def.id == 'starter_kitchen');
    expect(starter.done, isTrue);
    expect(starter.claimable, isTrue);
    expect(st.firstWhere((q) => q.def.id == 'plate_it').locked, isTrue);

    st = questStates(QuestContext(appliances: [micro], shelf: shelf, meals: meals, claimed: {'starter_kitchen'}, now: now));
    final plate = st.firstWhere((q) => q.def.id == 'plate_it');
    expect(plate.locked, isFalse);
    expect(plate.progress, 2);
    expect(plate.instanceId, 'plate_it@2026-10-12');
    expect(totalStars({'starter_kitchen', 'plate_it@2026-10-05'}), 8);
  });

  test('boil test maps to wattage classes', () {
    expect(wattFromBoilTest(100), 1000);
    expect(wattFromBoilTest(150), 800);
    expect(wattFromBoilTest(175), 700);
    expect(wattFromBoilTest(230), 500);
    expect(waterTestWatt(waterG: 300, startC: 10, endC: 40, seconds: 60), closeTo(628.05, 1e-9));
  });

  test('meal record survives a database row round trip', () {
    final m = meal(DateTime(2026, 10, 14, 8), g: {'antimony': 1.25, 'phthalate_dehp_eq': 0.5});
    final back = MealRecord.fromRow(m.toRow());
    expect(back.groupsPct, m.groupsPct);
    expect(back.day, '2026-10-14');
  });
}
