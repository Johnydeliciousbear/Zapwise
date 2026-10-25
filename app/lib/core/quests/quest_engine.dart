// Quests. Progress is computed from what is already stored (appliances, shelf, meals), so it
// cannot drift out of sync with the data. Only "claimed" is stored.
import '../data/records.dart';

enum QuestPeriod { once, weekly }

class QuestDef {
  final String id;
  final QuestPeriod period;
  final String titleEn;
  final String titleKo;
  final int target;
  final int stars;
  final String? decor; // kitchen item unlocked when claimed
  final int Function(QuestContext c) progress;
  final List<String> requires; // quest ids that must be claimed first

  const QuestDef({
    required this.id,
    required this.period,
    required this.titleEn,
    required this.titleKo,
    required this.target,
    required this.stars,
    this.decor,
    required this.progress,
    this.requires = const [],
  });
}

class QuestContext {
  final List<Appliance> appliances;
  final List<ShelfItem> shelf;
  final List<MealRecord> meals;
  final Set<String> claimed;
  final DateTime now;
  const QuestContext({required this.appliances, required this.shelf, required this.meals, required this.claimed, required this.now});

  /// Monday 00:00 local of the current week.
  DateTime get weekStart {
    final l = now.toLocal();
    final d = DateTime(l.year, l.month, l.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  String get weekKey => dayKey(weekStart);
  Iterable<MealRecord> get mealsThisWeek => meals.where((x) => !x.at.toLocal().isBefore(weekStart));
}

class QuestState {
  final QuestDef def;
  final String instanceId; // weekly quests get the week in their id
  final int progress;
  final bool claimed;
  final bool locked;
  const QuestState(this.def, this.instanceId, this.progress, this.claimed, this.locked);

  bool get done => progress >= def.target;
  bool get claimable => done && !claimed && !locked;
}

final List<QuestDef> kQuests = [
  QuestDef(
    id: 'starter_kitchen',
    period: QuestPeriod.once,
    titleEn: 'Set up your kitchen',
    titleKo: '주방 꾸리기',
    target: 3,
    stars: 3,
    progress: (c) =>
        (c.appliances.any((a) => a.kind == ApplianceKind.microwave && a.watt != null) ? 1 : 0) + (c.shelf.isNotEmpty ? 1 : 0) + (c.meals.isNotEmpty ? 1 : 0),
  ),
  QuestDef(
    id: 'boil_test',
    period: QuestPeriod.once,
    titleEn: 'Check your microwave\'s real power',
    titleKo: '우리 집 전자레인지 출력 알아내기',
    target: 1,
    stars: 2,
    decor: 'wall_clock',
    requires: ['starter_kitchen'],
    progress: (c) => c.appliances.any((a) => a.measuredWatt != null) ? 1 : 0,
  ),
  QuestDef(
    id: 'plate_it',
    period: QuestPeriod.weekly,
    titleEn: 'Plate it 3 times this week',
    titleKo: '이번 주 접시에 옮겨 데우기 3번',
    target: 3,
    stars: 5,
    decor: 'rug',
    requires: ['starter_kitchen'],
    progress: (c) => c.mealsThisWeek.where((x) => x.containerStatus == 'inert').length,
  ),
  QuestDef(
    id: 'by_the_label',
    period: QuestPeriod.weekly,
    titleEn: 'Stick to the box time 3 times',
    titleKo: '포장지 조리 시간 그대로 3번',
    target: 3,
    stars: 3,
    decor: 'fridge_plant',
    requires: ['starter_kitchen'],
    progress: (c) => c.mealsThisWeek.where((x) => x.followedLabel && (x.status == 'ok' || x.status == 'measured')).length,
  ),
];

List<QuestState> questStates(QuestContext c, {List<QuestDef>? defs}) {
  final out = <QuestState>[];
  for (final d in defs ?? kQuests) {
    final inst = d.period == QuestPeriod.weekly ? '${d.id}@${c.weekKey}' : d.id;
    final locked = d.requires.any((r) => !c.claimed.contains(r));
    final p = d.progress(c);
    out.add(QuestState(d, inst, p > d.target ? d.target : p, c.claimed.contains(inst), locked));
  }
  return out;
}

int totalStars(Set<String> claimed, {List<QuestDef>? defs}) {
  var s = 0;
  for (final id in claimed) {
    final base = id.split('@').first;
    for (final d in defs ?? kQuests) {
      if (d.id == base) s += d.stars;
    }
  }
  return s;
}
