// ZapWise migration and exposure engine (Dart port of engine_py/zapwise_engine.py).
//
// For one meal: label recipe -> food temperature -> container contact temperature ->
// integral of D(T) dt (between the Huang 2017 QPPR and the Piringer upper bound) ->
// partition coefficient (Huang and Jolliet 2019 regression) -> Crank migration ->
// micrograms eaten -> % of the tolerable daily intake.
// A Monte Carlo run over the uncertain inputs gives the 5th-95th percentile range.
import 'dart:math' as m;

import '../data/models.dart';
import 'math.dart';
import 'recipe.dart';
import 'thermal.dart';

enum HeatMethod { microwave, stove }

enum Band { lower, middle, higher }

class Scenario {
  final Product product;
  final String? containerKey; // null -> the product's own container
  final double watt; // rated power of the user's microwave
  final List<PlanStep>? plan; // null -> the label recipe at this wattage
  final double extraCookS; // added to the last cook step
  final bool eatInContainer;
  final double bodyWeightKg;
  final double? portion; // share of the package eaten; null -> 1 / servings
  final HeatMethod method;

  const Scenario({
    required this.product,
    this.containerKey,
    this.watt = 1100,
    this.plan,
    this.extraCookS = 0,
    this.eatInContainer = true,
    this.bodyWeightKg = 70,
    this.portion,
    this.method = HeatMethod.microwave,
  });

  Scenario copyWith({String? containerKey, double? watt, List<PlanStep>? plan, double? extraCookS, bool? eatInContainer, double? bodyWeightKg, double? portion, HeatMethod? method}) =>
      Scenario(
        product: product,
        containerKey: containerKey ?? this.containerKey,
        watt: watt ?? this.watt,
        plan: plan ?? this.plan,
        extraCookS: extraCookS ?? this.extraCookS,
        eatInContainer: eatInContainer ?? this.eatInContainer,
        bodyWeightKg: bodyWeightKg ?? this.bodyWeightKg,
        portion: portion ?? this.portion,
        method: method ?? this.method,
      );
}

/// One set of uncertain inputs.
class Draw {
  final double pFactor; // real / rated oven power
  final double edge; // extra temperature of food at the wall (C)
  final double cap; // highest contact temperature for this food class (C)
  final double areaF; // contact area multiplier
  final double? thickness; // cm
  final double etoh; // food ethanol equivalent (% v/v) for the partition regression
  final double kZ; // standard normal error of the partition regression
  final double dW; // 0 = Huang 2017 QPPR, 1 = Piringer upper bound (log scale)
  final Map<String, double> cP0; // mg/kg in plastic
  const Draw({
    required this.pFactor,
    required this.edge,
    required this.cap,
    required this.areaF,
    required this.thickness,
    required this.etoh,
    this.kZ = 0.0,
    this.dW = 0.5,
    required this.cP0,
  });
}

class SubstanceResult {
  final double ug; // in the whole package of food
  final double fraction; // of the equilibrium amount
  final double fo;
  final double alpha;
  final double k;
  final double logK;
  final double theta;
  final double tEff; // diffusion-weighted contact temperature (C) used for K
  final bool kowCapped;
  const SubstanceResult({
    required this.ug,
    required this.fraction,
    required this.fo,
    required this.alpha,
    required this.k,
    required this.logK,
    required this.theta,
    required this.tEff,
    this.kowCapped = false,
  });
}

class TemperatureInfo {
  final double tEndAvg;
  final double tContactMax;
  final double? energyRatio; // user plan energy / label energy
  const TemperatureInfo(this.tEndAvg, this.tContactMax, this.energyRatio);
}

class PctRange {
  final double p05, p50, p95;
  const PctRange(this.p05, this.p50, this.p95);
}

/// status: ok, measured, info, inert, no_data, block, oven_only, label_no_microwave
class EvalResult {
  final String productId;
  final String containerKey;
  final String status;
  final List<String> flags;
  final ResolvedRecipe recipe;
  final Map<String, double> groups; // reference group -> % TDI
  final double? headlinePct;
  final String? headlineGroup;
  final Band? band;
  final PctRange? range;
  final Map<String, SubstanceResult> substances;
  final TemperatureInfo? temperature;
  final double? vsLabel; // headline / headline if the label were followed

  const EvalResult({
    required this.productId,
    required this.containerKey,
    required this.status,
    required this.flags,
    required this.recipe,
    this.groups = const {},
    this.headlinePct,
    this.headlineGroup,
    this.band,
    this.range,
    this.substances = const {},
    this.temperature,
    this.vsLabel,
  });

  bool get hasNumber => headlinePct != null;
}

class ZapEngine {
  // ignore: non_constant_identifier_names
  final ZapParams P; // same name as self.P in the Python reference
  ZapEngine(this.P);

  // ---------------------------------------------------------------- helpers
  FoodThermal thermal(Product product) {
    final t0 = switch (product.storage) {
      Storage.frozen => P['T0_frozen_C'],
      Storage.chilled => P['T0_chilled_C'],
      Storage.shelf => P['T0_shelf_C'],
    };
    return FoodThermal(
        t0: t0, water: P['water_fraction'], cWater: P['c_water'], cSolids: P['c_solids'], cFrozen: P['c_frozen'], latent: P['latent_heat_water'], tBoil: P['T_boil_C']);
  }

  List<String> substancesFor(ContainerType c) {
    final ck = c.contentKey;
    if (ck == null || !P.contents.containsKey(ck)) return const [];
    return P.contents[ck]!.keys.toList()..sort();
  }

  Draw centralDraw(ContainerType c, FoodClass fc, List<String> subs) => Draw(
        pFactor: 0.5 * (P['power_factor_low'] + P['power_factor_high']),
        edge: P['edge_excess_C'],
        cap: 0.5 * (fc.capLow + fc.capHigh),
        areaF: 0.5 * (P['area_factor_low'] + P['area_factor_high']),
        thickness: c.thicknessCm,
        etoh: 0.5 * (fc.etohLow + fc.etohHigh),
        kZ: 0.0,
        dW: P['d_weight_central'],
        cP0: {for (final s in subs) s: P.contents[c.contentKey]![s]!.mid},
      );

  /// Draw order is fixed and must match the Python reference:
  /// power, edge, cap, area, thickness, EtOH-eq, partition error (two draws), diffusion weight,
  /// contents in sorted key order.
  Draw randomDraw(Rng rng, ContainerType c, FoodClass fc, List<String> subs) {
    final pFactor = rng.uniform(P['power_factor_low'], P['power_factor_high']);
    final edge = rng.uniform(P['edge_excess_low_C'], P['edge_excess_high_C']);
    final cap = rng.uniform(fc.capLow, fc.capHigh);
    final areaF = rng.uniform(P['area_factor_low'], P['area_factor_high']);
    final u = rng.uniform(0.0, 1.0);
    final thickness = c.thicknessLow != null ? c.thicknessLow! + (c.thicknessHigh! - c.thicknessLow!) * u : c.thicknessCm;
    final etoh = rng.uniform(fc.etohLow, fc.etohHigh);
    final kZ = rng.normal();
    final dW = rng.uniform(P['d_weight_low'], P['d_weight_high']);
    final cP0 = <String, double>{};
    for (final s in subs) {
      final r = P.contents[c.contentKey]![s]!;
      cP0[s] = rng.uniform(r.low, r.high);
    }
    return Draw(pFactor: pFactor, edge: edge, cap: cap, areaF: areaF, thickness: thickness, etoh: etoh, kZ: kZ, dW: dW, cP0: cP0);
  }

  // ---------------------------------------------------------------- temperature history
  /// [steam] (steam bags): after steam_onset_fraction of the label energy the film sits in steam at the boiling point.
  (List<double>, TemperatureInfo) contactHistory(Product product, List<PlanStep> plan, ResolvedRecipe recipe, double watt, Draw draw, bool eatInContainer,
      [bool steam = false]) {
    final th = thermal(product);
    final onset = P['steam_onset_fraction'];
    final dt = P['dt_s'];
    final hTarget = th.h(P['T_target_avg_C']);
    var eRecipe = watt * recipe.cookSeconds;
    if (eRecipe <= 0) {
      // no label recipe: treat the user's plan as the recipe
      eRecipe = watt * plan.where((s) => s.kind == PlanKind.cook).fold(0.0, (a, s) => a + s.timeS);
    }
    final k = eRecipe > 0 ? hTarget / eRecipe : 0.0;
    var h = 0.0;
    final temps = <double>[];
    var tAvg = th.t0;
    for (final s in plan) {
      final n = (s.timeS / dt + 0.5).floor();
      if (s.kind == PlanKind.cook) {
        for (var i = 0; i < n; i++) {
          h += k * watt * draw.pFactor * dt;
          tAvg = th.temp(h);
          final edge = draw.edge * m.min(1.0, h / hTarget);
          var tc = m.min(draw.cap, tAvg + edge);
          if (steam && h / hTarget >= onset) tc = m.max(tc, th.tBoil);
          temps.add(tc);
        }
      } else {
        for (var i = 0; i < n; i++) {
          temps.add(tAvg);
        }
      }
    }
    final tEnd = tAvg;
    if (eatInContainer) {
      final n = (P['eat_minutes'] * 60.0 / dt + 0.5).floor();
      final tStop = m.min(tEnd, P['eat_end_C']);
      for (var i = 1; i <= n; i++) {
        temps.add(tEnd + (tStop - tEnd) * i / n);
      }
    }
    final ePlan = watt * plan.where((s) => s.kind == PlanKind.cook).fold(0.0, (a, s) => a + s.timeS);
    final tMax = temps.isEmpty ? th.t0 : temps.reduce(m.max);
    return (temps, TemperatureInfo(tEnd, tMax, eRecipe != 0 ? ePlan / eRecipe : null));
  }

  /// ln D(T) = a + b / T (T in K, D in cm2/s) for the Piringer upper bound and the Huang 2017 QPPR.
  ((double, double), (double, double)) lnDCoefficients(Polymer pol, double mw) {
    final aPir = m.log(1e4) + pol.apPrime - 0.1351 * m.pow(mw, 2.0 / 3.0) + 0.003 * mw;
    final bPir = -(pol.tau + 10454.0);
    final h = P.huang2017;
    final aH = m.ln10 * (4.0 + h.intercept + h.bLogMw * log10(mw) + pol.huangB);
    final bH = m.ln10 * (pol.huangTau + h.betaInvT);
    return ((aPir, bPir), (aH, bH));
  }

  /// Diffusion coefficient (cm2/s). Organic migrants: log-scale mix of the Huang 2017 QPPR (dW = 0)
  /// and the Piringer upper bound (dW = 1). Antimony: Arrhenius fit.
  double dOf(String sub, ContainerType c, double tC, [double? dW]) {
    final s = P.substances[sub]!;
    if (s.model == DiffusionModel.arrhenius) return dArrhenius(s.d0!, s.eaKj!, tC, P['R_gas']);
    final w = dW ?? P['d_weight_central'];
    final ((ap, bp), (ah, bh)) = lnDCoefficients(P.polymers[c.polymer]!, s.mw);
    final tk = tC + 273.15;
    return m.exp((1.0 - w) * (ah + bh / tk) + w * (ap + bp / tk));
  }

  /// log10 Kpf (polymer / food) from the Huang and Jolliet 2019 regression [S76], and the log Kow used.
  /// Migrants without log Kow (antimony) use K = 1.
  (double, double?) logKpf(String sub, ContainerType c, double etoh, double tEffC, double kZ) {
    final sp = P.substances[sub]!;
    if (sp.logKow == null) return (0.0, null);
    final k = P.kpf;
    final x = m.min(sp.logKow!, k.kowCap(etoh));
    final mat = P.polymers[c.polymer]!.kpfMaterial;
    final invT = 1.0 / (tEffC + 273.15) - 1.0 / P['kpf_t_ref_K'];
    final lk = k.b0 + k.bKow * x + k.bEtoh * etoh + k.bKowEtoh * x * etoh + k.bInvT * invT + k.materialOffsets[mat]! + kZ * P['kpf_resid_sd'];
    return (lk, x);
  }

  // ---------------------------------------------------------------- one pass
  Map<String, SubstanceResult> migrate(ContainerType c, List<double> temps, Draw draw, List<String> subs, double massG) {
    final dt = P['dt_s'];
    final area = c.areaRefCm2! * m.pow(massG / P['area_ref_mass_g'], 2.0 / 3.0) * draw.areaF;
    final d = draw.thickness!;
    final vP = area * d;
    final mP = c.density! * vP;
    final vF = massG / P['food_density'];
    final out = <String, SubstanceResult>{};
    for (final s in subs) {
      final sp = P.substances[s]!;
      var theta = 0.0;
      var dtSum = 0.0;
      if (sp.model == DiffusionModel.arrhenius) {
        for (final t in temps) {
          final dd = dArrhenius(sp.d0!, sp.eaKj!, t, P['R_gas']) * dt;
          theta += dd;
          dtSum += dd * t;
        }
      } else {
        final ((ap, bp), (ah, bh)) = lnDCoefficients(P.polymers[c.polymer]!, sp.mw);
        final w = draw.dW;
        final aMix = (1.0 - w) * ah + w * ap;
        final bMix = (1.0 - w) * bh + w * bp;
        for (final t in temps) {
          final dd = m.exp(aMix + bMix / (t + 273.15)) * dt;
          theta += dd;
          dtSum += dd * t;
        }
      }
      // partition coefficient at the diffusion-weighted contact temperature
      final tEff = theta > 0 ? dtSum / theta : (temps.isNotEmpty ? temps.last : 25.0);
      final (lk, kowUsed) = logKpf(s, c, draw.etoh, tEff, draw.kZ);
      final k = m.pow(10.0, lk).toDouble();
      final alpha = vF / (k * vP);
      final cEff = draw.cP0[s]! * sp.diffusible;
      final mEq = cEff * mP * alpha / (1.0 + alpha);
      final fo = theta / (d * d);
      final f = crankFraction(fo, alpha, P['short_time_Fo']);
      out[s] = SubstanceResult(
        ug: mEq * f,
        fraction: f,
        fo: fo,
        alpha: alpha,
        k: k,
        logK: lk,
        theta: theta,
        tEff: tEff,
        kowCapped: kowUsed != null && kowUsed < sp.logKow!,
      );
    }
    return out;
  }

  Map<String, double> exposure(Map<String, SubstanceResult> migrated, double portion, double bw) {
    final sums = <String, double>{};
    migrated.forEach((s, r) {
      final sp = P.substances[s]!;
      sums[sp.group] = (sums[sp.group] ?? 0.0) + r.ug * portion * sp.rpf;
    });
    return {for (final e in sums.entries) e.key: e.value / (bw * P.groups[e.key]!.tdi) * 100.0};
  }

  Band? band(double? pct) {
    if (pct == null) return null;
    if (pct < P['band_low_pct']) return Band.lower;
    if (pct < P['band_high_pct']) return Band.middle;
    return Band.higher;
  }

  List<PlanStep> planFor(Scenario sc, ResolvedRecipe recipe) {
    final plan = [...(sc.plan ?? recipe.plan)];
    if (sc.extraCookS != 0) {
      final idx = plan.lastIndexWhere((s) => s.kind == PlanKind.cook);
      if (idx >= 0) plan[idx] = plan[idx].copyWith(timeS: plan[idx].timeS + sc.extraCookS);
    }
    return plan;
  }

  static bool _samePlan(List<PlanStep> a, List<PlanStep> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  double _headline(Map<String, double> g) => g.isEmpty ? 0.0 : g.values.reduce(m.max);

  // ---------------------------------------------------------------- public
  EvalResult evaluate(Scenario sc, {bool mc = true}) {
    final product = sc.product;
    var ckey = sc.containerKey ?? product.containerKey;
    if (sc.method == HeatMethod.stove) ckey = 'stove_pot';
    final c = P.containers[ckey]!;
    final recipe = resolveRecipe(product.recipe, sc.watt);
    final flags = [...recipe.flags];

    if (product.recipe.ovenOnly && sc.method == HeatMethod.microwave) {
      return EvalResult(
          productId: product.id, containerKey: ckey, status: product.recipe.doNotMicrowave == 'yes' ? 'label_no_microwave' : 'oven_only', flags: flags, recipe: recipe);
    }
    if (c.status == ContainerStatus.measured) return _measured(product, ckey, sc, recipe, flags);
    if (c.status != ContainerStatus.ok) {
      final inert = c.status == ContainerStatus.inert;
      return EvalResult(
          productId: product.id, containerKey: ckey, status: statusName(c.status), flags: flags, recipe: recipe, headlinePct: inert ? 0.0 : null, band: inert ? Band.lower : null);
    }

    final plan = planFor(sc, recipe);
    final fc = P.foodClass(product.fatClass);
    final subs = substancesFor(c);
    final mass = product.foodMassG;
    final portion = sc.portion ?? 1.0 / (product.servings ?? 1.0);

    final draw = centralDraw(c, fc, subs);
    final steam = c.contactMode == 'steam';
    final (temps, tinfo) = contactHistory(product, plan, recipe, sc.watt, draw, sc.eatInContainer, steam);
    final mig = migrate(c, temps, draw, subs, mass);
    final groups = exposure(mig, portion, sc.bodyWeightKg);
    final headline = _headline(groups);
    String? headlineGroup;
    if (groups.isNotEmpty) {
      headlineGroup = groups.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    }

    double? vsLabel = 1.0;
    final labelPlan = recipe.plan;
    if (labelPlan.isNotEmpty && (!_samePlan(plan, labelPlan) || !sc.eatInContainer)) {
      final (lt, _) = contactHistory(product, labelPlan, recipe, sc.watt, draw, true, steam);
      final base = _headline(exposure(migrate(c, lt, draw, subs, mass), portion, sc.bodyWeightKg));
      vsLabel = base > 0 ? headline / base : null;
    }

    if (tinfo.energyRatio != null && tinfo.energyRatio! < P['energy_short_ratio']) flags.add('below_recipe_energy');
    if (c.maxUseC != null && tinfo.tContactMax > c.maxUseC!) flags.add('above_container_max_use');
    final pol = c.polymer == null ? null : P.polymers[c.polymer];
    if (pol != null && subs.any((s) => P.substances[s]!.model == DiffusionModel.piringer) && tinfo.tContactMax > pol.tMaxValidC) {
      flags.add('outside_model_validity');
    }
    if (subs.any((s) => P.substances[s]!.model == DiffusionModel.arrhenius)) flags.add('arrhenius_extrapolated');
    if (!product.fatKnown) flags.add('fat_unknown');
    if (mig.values.any((r) => r.kowCapped)) flags.add('kow_capped_to_data');

    PctRange? range;
    if (mc) {
      final rng = Rng(P['mc_seed'].toInt());
      final vals = <double>[];
      final n = P['mc_samples'].toInt();
      for (var i = 0; i < n; i++) {
        final dr = randomDraw(rng, c, fc, subs);
        final (tt, _) = contactHistory(product, plan, recipe, sc.watt, dr, sc.eatInContainer, steam);
        vals.add(_headline(exposure(migrate(c, tt, dr, subs, mass), portion, sc.bodyWeightKg)));
      }
      vals.sort();
      range = PctRange(percentile(vals, 0.05)!, percentile(vals, 0.50)!, percentile(vals, 0.95)!);
    }

    return EvalResult(
      productId: product.id,
      containerKey: ckey,
      status: 'ok',
      flags: flags,
      recipe: recipe,
      groups: groups,
      headlinePct: headline,
      headlineGroup: headlineGroup,
      band: band(headline),
      range: range,
      substances: mig,
      temperature: tinfo,
      vsLabel: vsLabel,
    );
  }

  /// Estimate from measured migration (container status measured). The range is the low and
  /// high of the measurements, not a Monte Carlo result. Mirrors Engine.measured in Python.
  EvalResult _measured(Product product, String ckey, Scenario sc, ResolvedRecipe recipe, List<String> flags) {
    final recs = P.measured[ckey] ?? const <MeasuredRecord>[];
    final portion = sc.portion ?? 1.0 / (product.servings ?? 1.0);
    final massKg = product.foodMassG / 1000.0;
    final lo = <String, double>{}, mid = <String, double>{}, hi = <String, double>{};
    for (final r in recs) {
      final f = (r.basis == 'per_kg_food' ? massKg : 1.0) * portion;
      lo[r.group] = (lo[r.group] ?? 0.0) + r.low * f;
      mid[r.group] = (mid[r.group] ?? 0.0) + r.mid * f;
      hi[r.group] = (hi[r.group] ?? 0.0) + r.high * f;
    }
    final tdi = {for (final g in mid.keys) g: sc.bodyWeightKg * P.groups[g]!.tdi};
    final groups = {for (final g in mid.keys) g: mid[g]! / tdi[g]! * 100.0};
    String? hg;
    PctRange? range;
    if (groups.isNotEmpty) {
      hg = groups.entries.reduce((a, b) => b.value > a.value ? b : a).key;
      range = PctRange(lo[hg]! / tdi[hg]! * 100.0, groups[hg]!, hi[hg]! / tdi[hg]! * 100.0);
    }
    return EvalResult(
      productId: product.id,
      containerKey: ckey,
      status: 'measured',
      flags: [...flags, 'measurement_based'],
      recipe: recipe,
      groups: groups,
      headlinePct: hg == null ? null : groups[hg],
      headlineGroup: hg,
      band: hg == null ? null : band(groups[hg]),
      range: range,
      vsLabel: null,
    );
  }

  /// Same meal in other containers or on the stove, for the "what if" cards.
  Map<String, EvalResult> alternatives(Scenario sc, {List<String> containers = const ['ceramic', 'glass'], bool includeStove = true}) {
    final out = <String, EvalResult>{};
    for (final k in containers) {
      out[k] = evaluate(sc.copyWith(containerKey: k), mc: false);
    }
    if (includeStove) out['stove'] = evaluate(sc.copyWith(method: HeatMethod.stove), mc: false);
    return out;
  }
}
