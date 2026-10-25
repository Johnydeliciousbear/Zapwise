// Log tab: today's total and the last 7 days, per reference group and person.
// Percentages add up only within one group for one person (same limit and body weight).
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/core.dart';
import '../../sheets/quest_sheet.dart';
import '../../ui/charts.dart';
import '../../ui/copy.dart';
import '../../ui/sheets.dart';
import '../../ui/soft.dart';
import '../../ui/sprites.dart';
import '../../ui/theme.dart';
import '../flows.dart';
import '../shell.dart';
import 'package:zapwise/ui/i18n.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  bool _week = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final prof = s.activeProfile;
    final mine = s.mealsFor(prof);
    final sum = summarize(
      mine,
      now: DateTime.now(),
      days: 7,
      dailyAlertPct: s.params['daily_alert_pct'],
      highMealPct: s.params['band_high_pct'],
    );
    final children = <Widget>[
      Segmented<bool>(options: const [(false, 'Today'), (true, 'Last 7 days')], value: _week, onChanged: (v) => setState(() => _week = v)),
    ];
    if (s.profiles.length > 1) {
      children.add(ChoiceRow<String>(
        options: [for (final p in s.profiles) (p.id, p.isDefault ? 'You' : p.name)],
        selected: prof.id,
        onSelected: (id) => s.setActive(id),
      ));
    }
    if (mine.isEmpty) {
      children.add(Raised(
        child: Column(children: [
          const Zappy(Mood.sleepy, scale: 3),
          const SizedBox(height: 10),
          const TText('No meals yet', style: ZT.h2),
          const SizedBox(height: 6),
          TText('Scan a meal, heat it, and tap Save. It shows up here.', style: ZT.small, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          PixelButton(label: 'Scan a meal', icon: 'camera', onPressed: () => startScan(context)),
          ZLink('Show a sample week', onTap: () => s.addSampleWeek()),
        ]),
      ));
    } else if (!_week) {
      final today = sum.days.last;
      final todays = mine.where((m) => m.day == today.day).toList();
      if (todays.isEmpty) {
        children.add(Raised(
          child: Column(children: [
            const Zappy(Mood.sleepy, scale: 3),
            const SizedBox(height: 10),
            const TText('Nothing yet today', style: ZT.h2, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            PixelButton(label: 'Scan a meal', icon: 'camera', onPressed: () => startScan(context)),
            const SizedBox(height: 6),
            ZLink('See the last 7 days', onTap: () => setState(() => _week = true)),
          ]),
        ));
      } else {
      children.add(_Block(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TText('Today for ${prof.isDefault ? 'you' : prof.name}', style: ZT.h3),
              TText('${todays.length} heated meal${todays.length == 1 ? '' : 's'}${today.mealsWithoutNumber > 0 ? ', ${today.mealsWithoutNumber} without a number' : ''}',
                  style: ZT.smallMuted),
            ]),
          ),
          Text(pctText(today.headline), style: ZT.bigNumber.copyWith(fontSize: 32)),
        ]),
      ));
      children.addAll(_alerts(sum, s, onlyDay: today.day));
      for (final m in todays) {
        children.add(_Entry(meal: m, sample: s.sampleMealIds.contains(m.id)));
      }
      }
    } else {
      children.add(_week7(sum, s, prof));
      children.addAll(_alerts(sum, s));
      for (final m in mine.take(14)) {
        children.add(_Entry(meal: m, sample: s.sampleMealIds.contains(m.id)));
      }
    }
    if (s.sampleMealIds.isNotEmpty) {
      children.add(Center(
        child: ZLink('Remove the sample week', onTap: () async {
          await s.removeSampleMeals();
          if (context.mounted) toast(context, 'Sample meals removed');
        }),
      ));
    }
    return ListView(
      padding: EdgeInsets.only(bottom: tabBottomPadding(context)),
      children: [
        TabHeader(title: 'Log', trailing: StarPill(stars: s.stars, onPressed: () => showQuestSheet(context))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: gapped(children))),
      ],
    );
  }

  Widget _week7(ExposureSummary sum, AppState s, Profile prof) {
    final labels = <String>[];
    for (var i = 0; i < sum.days.length; i++) {
      final d = DateTime.parse(sum.days[i].day);
      labels.add(i == sum.days.length - 1 ? 'Today' : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1]);
    }
    final values = [for (final d in sum.days) d.headline];
    final total = values.fold<double>(0, (a, b) => a + b);
    // which container added the most over the week
    final byContainer = <String, double>{};
    for (final m in s.mealsFor(prof)) {
      if (!sum.days.any((d) => d.day == m.day)) continue;
      final v = m.groupsPct.values.fold<double>(0, (a, b) => a > b ? a : b);
      byContainer[m.containerKey] = (byContainer[m.containerKey] ?? 0) + v;
    }
    String? top;
    var topV = 0.0;
    byContainer.forEach((k, v) {
      if (v > topV) {
        topV = v;
        top = k;
      }
    });
    final topKey = top;
    return _Block(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TText('Last 7 days, % of ${prof.isDefault ? 'your' : '${prof.name}\'s'} daily safe limit', style: ZT.h3),
        const SizedBox(height: 8),
        WeekBars(values: values, labels: labels, lowCut: s.params['band_low_pct'], highCut: s.params['band_high_pct']),
        if (topKey != null && total > 0) ...[
          const SizedBox(height: 8),
          TText(
            '${(topV / total * 100).round()}% came from the ${(s.params.containers[topKey]?.labelEn ?? topKey).toLowerCase()}. '
            '${s.params.containers[topKey]?.status == ContainerStatus.inert ? '' : 'Switching those meals to a plate would help most.'}',
            style: ZT.small,
          ),
        ],
        const SizedBox(height: 6),
        TText('Each bar is one day.', style: ZT.foot),
      ]),
    );
  }

  List<Widget> _alerts(ExposureSummary sum, AppState s, {String? onlyDay}) {
    final out = <Widget>[];
    final seen = <AlertKind>{};
    for (final a in sum.alerts) {
      if (onlyDay != null && a.day != null && a.day != onlyDay) continue;
      if (onlyDay != null && a.kind == AlertKind.weekOverAllocation) continue;
      if (!seen.add(a.kind)) continue;
      final g = a.group == null ? null : s.params.groups[a.group]?.labelEn;
      final text = switch (a.kind) {
        AlertKind.dayOverAllocation => 'One day hit ${pctText(a.value)} of the limit for ${g ?? 'one group'}. That\'s more than the 20% share EU rules set for packaging.',
        AlertKind.weekOverAllocation => 'This week, packaging averaged ${pctText(a.value)} of the limit for ${g ?? 'one group'}.',
        AlertKind.highMeal => 'One meal hit ${pctText(a.value)} of the limit. A plate or glass dish gets that close to zero.',
        AlertKind.blockedContainerUsed => 'One meal was heated in a container that isn\'t made for heat.',
        AlertKind.manyUnknown => 'Many meals have no number yet. Add their containers to fix that.',
      };
      out.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const ZIcon('alert', size: 20), const SizedBox(width: 8), Expanded(child: TText(text, style: ZT.small))]));
    }
    return out;
  }
}

/// A block that ends with a line, so the meal rows under it join on without a second line.
class _Block extends StatelessWidget with LineRow {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Block({required this.child, required this.padding});

  @override
  bool get topLine => false;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ZC.line))),
        child: child,
      );
}

/// One meal: a flat row with a line under it.
class _Entry extends StatelessWidget with LineRow {
  final MealRecord meal;
  final bool sample;
  const _Entry({required this.meal, required this.sample});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.assets.byId[meal.productId];
    final v = meal.groupsPct.isEmpty ? null : meal.groupsPct.values.reduce((a, b) => a > b ? a : b);
    final band = meal.containerStatus == 'inert' ? BandKind.lower : bandOfPct(v, s.params);
    final now = DateTime.now();
    final t = meal.at.toLocal();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    final oven = meal.status == 'oven_only' || meal.status == 'label_no_microwave';
    final when = '${sameDay ? 'Today' : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][t.weekday - 1]} '
        '${t.hour % 12 == 0 ? 12 : t.hour % 12}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
    return GestureDetector(
      onLongPress: meal.id == null
          ? null
          : () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: ZC.milk,
                  title: const TText('Remove this meal?', style: ZT.h3),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const TText('Keep')),
                    TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const TText('Remove')),
                  ],
                ),
              );
              if (ok == true) await s.deleteMeal(meal.id!);
            },
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ZC.line))),
        child: Row(children: [
          ZThumb(p == null ? 'objects/meal_box' : productSprite(p), size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TText(p?.name ?? (meal.productId.startsWith('quick-') ? 'Quick estimate' : meal.productId), style: ZT.button.copyWith(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
              TText('${methodLabel(containerKey: meal.containerKey, params: s.params, oven: oven)}\n$when${sample ? ', sample' : ''}', style: ZT.smallMuted.copyWith(fontSize: 12.5)),
            ]),
          ),
          const SizedBox(width: 8),
          if (oven)
            const BandChip(BandKind.none, text: 'Oven', outline: false)
          else if (v == null && meal.containerStatus != 'inert')
            const BandChip(BandKind.none, text: 'No number', outline: false)
          else
            BandChip(band, text: pctText(v ?? 0), outline: false),
        ]),
      ),
    );
  }
}
