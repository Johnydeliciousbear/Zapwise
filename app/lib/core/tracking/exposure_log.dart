// Daily, weekly and monthly totals of the logged meals, and the alerts built on them.
//
// Percentages of the TDI can be added within one reference group for one person, because
// they share the same TDI and body weight. Groups are never added to each other.
// The alert level is the 20 % of the TDI that EU rules set aside for food contact
// materials (Regulation 2023/1442, recital 12) [S08].
import 'dart:math' as m;

import '../data/records.dart';

class DayTotal {
  final String day;
  final Map<String, double> groups; // % TDI per reference group
  final int meals;
  final int mealsWithoutNumber; // no_data, block or not modelled
  const DayTotal(this.day, this.groups, this.meals, this.mealsWithoutNumber);

  double get headline => groups.isEmpty ? 0.0 : groups.values.reduce(m.max);
}

enum AlertKind { dayOverAllocation, weekOverAllocation, highMeal, blockedContainerUsed, manyUnknown }

class ExposureAlert {
  final AlertKind kind;
  final String? day;
  final String? group;
  final double? value;
  const ExposureAlert(this.kind, {this.day, this.group, this.value});
}

class ExposureSummary {
  final List<DayTotal> days; // oldest first, one entry per calendar day (empty days included)
  final Map<String, double> meanPerDay; // per group, mean over the window
  final List<ExposureAlert> alerts;
  final Map<String, int> containerCounts;
  const ExposureSummary(this.days, this.meanPerDay, this.alerts, this.containerCounts);
}

List<String> _dayRange(DateTime endLocal, int n) {
  final end = DateTime(endLocal.year, endLocal.month, endLocal.day);
  return [for (var i = n - 1; i >= 0; i--) dayKey(DateTime(end.year, end.month, end.day - i))];
}

/// Totals for the [days] calendar days ending today (local time).
ExposureSummary summarize(
  List<MealRecord> meals, {
  required DateTime now,
  int days = 7,
  double dailyAlertPct = 20.0,
  double highMealPct = 10.0,
}) {
  final keys = _dayRange(now.toLocal(), days);
  final inWindow = meals.where((x) => keys.contains(x.day)).toList();
  final totals = <String, Map<String, double>>{for (final k in keys) k: {}};
  final counts = <String, int>{for (final k in keys) k: 0};
  final unknown = <String, int>{for (final k in keys) k: 0};
  final containerCounts = <String, int>{};
  final alerts = <ExposureAlert>[];

  for (final x in inWindow) {
    counts[x.day] = counts[x.day]! + 1;
    containerCounts[x.containerKey] = (containerCounts[x.containerKey] ?? 0) + 1;
    if (x.groupsPct.isEmpty) unknown[x.day] = unknown[x.day]! + 1;
    x.groupsPct.forEach((g, v) {
      totals[x.day]![g] = (totals[x.day]![g] ?? 0.0) + v;
      if (v >= highMealPct) alerts.add(ExposureAlert(AlertKind.highMeal, day: x.day, group: g, value: v));
    });
    if (x.containerStatus == 'block') alerts.add(ExposureAlert(AlertKind.blockedContainerUsed, day: x.day));
  }
  final dayTotals = [for (final k in keys) DayTotal(k, totals[k]!, counts[k]!, unknown[k]!)];
  for (final d in dayTotals) {
    d.groups.forEach((g, v) {
      if (v >= dailyAlertPct) alerts.add(ExposureAlert(AlertKind.dayOverAllocation, day: d.day, group: g, value: v));
    });
  }
  final mean = <String, double>{};
  for (final d in dayTotals) {
    d.groups.forEach((g, v) => mean[g] = (mean[g] ?? 0.0) + v / days);
  }
  mean.forEach((g, v) {
    if (v >= dailyAlertPct) alerts.add(ExposureAlert(AlertKind.weekOverAllocation, group: g, value: v));
  });
  final totalMeals = inWindow.length;
  final totalUnknown = unknown.values.fold(0, (a, b) => a + b);
  if (totalMeals >= 4 && totalUnknown * 2 >= totalMeals) {
    alerts.add(ExposureAlert(AlertKind.manyUnknown, value: totalUnknown.toDouble()));
  }
  return ExposureSummary(dayTotals, mean, alerts, containerCounts);
}
