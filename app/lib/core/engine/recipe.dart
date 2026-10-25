// Label recipe -> steps for the user's microwave.
//
// Cook times scale with reference_watt / user_watt (energy equivalence). This is a first-order
// rule: real ovens differ by about +/-15 % from their rating [S26], which the Monte Carlo covers.
// When the label prints a wattage table, the time is interpolated linearly in 1/W.
import '../data/models.dart';

enum PlanKind { cook, stand }

/// A step the engine simulates (actions such as 'stir' take no time).
class PlanStep {
  final PlanKind kind;
  final double timeS;
  const PlanStep(this.kind, this.timeS);

  PlanStep copyWith({double? timeS}) => PlanStep(kind, timeS ?? this.timeS);

  @override
  bool operator ==(Object other) => other is PlanStep && other.kind == kind && other.timeS == timeS;

  @override
  int get hashCode => Object.hash(kind, timeS);

  Map<String, dynamic> toJson() => {'kind': kind.name, 'time_s': timeS};
}

/// One label step converted to the user's oven, for display and for the plan.
class ResolvedStep {
  final String kind; // cook, stand, action, oven
  final double timeS; // middle of the label range
  final double timeLo;
  final double timeHi;
  final String text;
  const ResolvedStep({required this.kind, required this.timeS, required this.timeLo, required this.timeHi, required this.text});
}

class ResolvedRecipe {
  final List<ResolvedStep> steps;
  final List<String> flags;
  const ResolvedRecipe(this.steps, this.flags);

  List<PlanStep> get plan => [
        for (final s in steps)
          if (s.kind == 'cook')
            PlanStep(PlanKind.cook, s.timeS)
          else if (s.kind == 'stand')
            PlanStep(PlanKind.stand, s.timeS),
      ];

  double get cookSeconds => steps.where((s) => s.kind == 'cook').fold(0.0, (a, s) => a + s.timeS);
  bool get hasCook => steps.any((s) => s.kind == 'cook');
}

double _mid(double a, double? b) => b == null ? a : 0.5 * (a + b);

/// Cook time at [watt] from a label wattage table (linear in 1/W between entries,
/// energy equivalence from the nearest entry outside the table).
double tableTime(List<WattEntry> table, double watt) {
  final pts = [for (final e in table) (e.watt, e.mid)]..sort((a, b) => a.$1.compareTo(b.$1));
  if (watt <= pts.first.$1) return pts.first.$2 * pts.first.$1 / watt;
  if (watt >= pts.last.$1) return pts.last.$2 * pts.last.$1 / watt;
  for (var i = 0; i < pts.length - 1; i++) {
    final (wa, ta) = pts[i];
    final (wb, tb) = pts[i + 1];
    if (wa <= watt && watt <= wb) {
      final xa = 1.0 / wa, xb = 1.0 / wb, x = 1.0 / watt;
      return ta + (tb - ta) * (x - xa) / (xb - xa);
    }
  }
  throw StateError('unreachable');
}

ResolvedRecipe resolveRecipe(Recipe r, double watt) {
  final flags = <String>[];
  final out = <ResolvedStep>[];
  final ref = r.refWatt;
  for (final s in r.steps) {
    switch (s.kind) {
      case StepKind.cook:
        final lo = s.timeS!;
        final hi = s.timeSMax ?? s.timeS!;
        final f = ref / watt;
        out.add(ResolvedStep(kind: 'cook', timeS: _mid(lo, s.timeSMax) * f, timeLo: lo * f, timeHi: hi * f, text: s.text));
      case StepKind.cookTable:
        final t = tableTime(r.wattTable, watt);
        out.add(ResolvedStep(kind: 'cook', timeS: t, timeLo: t, timeHi: t, text: s.text));
      case StepKind.stand:
        final lo = s.timeS!;
        final hi = s.timeSMax ?? s.timeS!;
        out.add(ResolvedStep(kind: 'stand', timeS: _mid(lo, s.timeSMax), timeLo: lo, timeHi: hi, text: s.text));
      case StepKind.oven:
        out.add(ResolvedStep(kind: 'oven', timeS: 0, timeLo: 0, timeHi: 0, text: s.text));
        if (!flags.contains('oven_step_not_modeled')) flags.add('oven_step_not_modeled');
      case StepKind.action:
        out.add(ResolvedStep(kind: 'action', timeS: 0, timeLo: 0, timeHi: 0, text: s.text));
    }
  }
  if (r.refWattAssumed) flags.add('ref_watt_assumed');
  if (r.minWatt != null && watt < r.minWatt!) flags.add('below_label_min_watt');
  if (!out.any((s) => s.kind == 'cook')) flags.add('no_recipe');
  if (r.wattTable.isNotEmpty) {
    final ws = r.wattTable.map((e) => e.watt);
    final lo = ws.reduce((a, b) => a < b ? a : b);
    final hi = ws.reduce((a, b) => a > b ? a : b);
    if (watt < lo || watt > hi) flags.add('outside_label_table');
  }
  return ResolvedRecipe(out, flags);
}
