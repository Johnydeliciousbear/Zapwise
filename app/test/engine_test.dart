// Checks the Dart engine against numbers produced by the Python reference
// (engine_py/make_test_vectors.py -> test/fixtures/engine_vectors.json).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapwise/core/data/asset_repository.dart';
import 'package:zapwise/core/data/models.dart';
import 'package:zapwise/core/engine/engine.dart';
import 'package:zapwise/core/engine/math.dart';
import 'package:zapwise/core/engine/recipe.dart';
import 'package:zapwise/core/engine/thermal.dart';

const tol = 1e-6;

void expectClose(num? actual, num? expected, {String? reason, double rel = tol}) {
  if (expected == null) {
    expect(actual, isNull, reason: reason);
    return;
  }
  expect(actual, isNotNull, reason: reason);
  final e = expected.toDouble();
  final a = actual!.toDouble();
  final scale = e.abs() > 1e-300 ? e.abs() : 1.0;
  expect((a - e).abs() / scale, lessThanOrEqualTo(rel), reason: '${reason ?? ''} actual $a expected $e');
}

void main() {
  late ZapAssets assets;
  late ZapEngine engine;
  late Map<String, dynamic> v;

  setUpAll(() {
    assets = ZapAssets.fromStrings(
      File('assets/data/zapwise_params.json').readAsStringSync(),
      File('assets/data/products.json').readAsStringSync(),
      File('assets/data/catalog_embeddings.json').readAsStringSync(),
    );
    engine = ZapEngine(assets.params);
    v = jsonDecode(File('test/fixtures/engine_vectors.json').readAsStringSync()) as Map<String, dynamic>;
  });

  test('assets load and every product points to a known container', () {
    expect(assets.products.length, greaterThanOrEqualTo(100));
    for (final p in assets.products) {
      expect(assets.params.containers.containsKey(p.containerKey), isTrue, reason: p.id);
      expect(assets.params.foodClasses.any((f) => f.key == p.fatClass), isTrue, reason: p.id);
    }
  });

  test('random numbers match the Python sequence', () {
    final r = Rng((v['rng']['seed'] as num).toInt());
    for (final x in v['rng']['u32'] as List) {
      expect(r.nextU32(), (x as num).toInt());
    }
  });

  test('normal draws match the Python sequence', () {
    final r = Rng((v['rng']['seed'] as num).toInt());
    for (final x in v['normal'] as List) {
      expectClose(r.normal(), x as num);
    }
  });

  test('erfcx', () {
    for (final row in v['erfcx'] as List) {
      expectClose(erfcx((row[0] as num).toDouble()), row[1] as num, reason: 'z=${row[0]}');
    }
  });

  test('diffusion coefficients', () {
    for (final r in v['piringer'] as List) {
      expectClose(dPiringer((r['ap'] as num).toDouble(), (r['tau'] as num).toDouble(), (r['mr'] as num).toDouble(), (r['t'] as num).toDouble()), r['d'] as num);
    }
    for (final r in v['arrhenius'] as List) {
      expectClose(dArrhenius((r['d0'] as num).toDouble(), (r['ea'] as num).toDouble(), (r['t'] as num).toDouble()), r['d'] as num);
    }
    final h = assets.params.huang2017;
    for (final r in v['huang2017'] as List) {
      expectClose(
          dHuang2017(h.intercept, h.bLogMw, h.betaInvT, (r['b'] as num).toDouble(), (r['tau'] as num).toDouble(), (r['mw'] as num).toDouble(),
              (r['t'] as num).toDouble()),
          r['d'] as num);
    }
    final pp = assets.params.containers['pp_container']!;
    for (final r in v['d_mix'] as List) {
      expectClose(engine.dOf(r['sub'] as String, pp, (r['t'] as num).toDouble(), (r['w'] as num).toDouble()), r['d'] as num,
          reason: '${r['sub']} ${r['t']} ${r['w']}');
    }
  });

  test('partition coefficient regression', () {
    for (final r in v['log_kpf'] as List) {
      final c = assets.params.containers[r['container']]!;
      final (lk, x) = engine.logKpf(r['sub'] as String, c, (r['etoh'] as num).toDouble(), (r['t'] as num).toDouble(), (r['k_z'] as num).toDouble());
      final tag = '${r['sub']} ${r['container']} ${r['etoh']} ${r['t']}';
      expectClose(lk, r['log_k'] as num, reason: tag);
      expectClose(x, r['kow_used'] as num?, reason: tag);
    }
  });

  test('Crank roots and fraction', () {
    for (final r in v['crank_roots'] as List) {
      final got = crankRoots((r['alpha'] as num).toDouble(), 5);
      final exp = r['roots'] as List;
      for (var i = 0; i < 5; i++) {
        expectClose(got[i], exp[i] as num);
      }
    }
    for (final r in v['crank'] as List) {
      expectClose(crankFraction((r['fo'] as num).toDouble(), (r['alpha'] as num).toDouble()), r['f'] as num,
          reason: 'fo=${r['fo']} alpha=${r['alpha']}', rel: 1e-6);
    }
  });

  test('food enthalpy', () {
    for (final r in v['thermal'] as List) {
      final ft = FoodThermal(t0: (r['t0'] as num).toDouble());
      if (r['t'] != null) expectClose(ft.h((r['t'] as num).toDouble()), r['h'] as num);
      expectClose(ft.temp((r['h'] as num).toDouble()), r['back'] as num);
    }
  });

  test('wattage tables and recipe conversion', () {
    for (final r in v['table_time'] as List) {
      final p = assets.byId[r['product']]!;
      expectClose(tableTime(p.recipe.wattTable, (r['watt'] as num).toDouble()), r['t'] as num);
    }
    for (final r in v['recipes'] as List) {
      final p = assets.byId[r['product']]!;
      final got = resolveRecipe(p.recipe, (r['watt'] as num).toDouble());
      final exp = r['steps'] as List;
      expect(got.steps.length, exp.length, reason: r['product'] as String);
      for (var i = 0; i < exp.length; i++) {
        expect(got.steps[i].kind, exp[i]['kind']);
        expectClose(got.steps[i].timeS, exp[i]['time_s'] as num);
        expectClose(got.steps[i].timeLo, exp[i]['time_lo'] as num);
        expectClose(got.steps[i].timeHi, exp[i]['time_hi'] as num);
      }
      expect(got.flags, [for (final f in r['flags'] as List) f as String]);
    }
  });

  test('full scenarios, central value and Monte Carlo range', () {
    for (final s in v['scenarios'] as List) {
      final inp = s['input'] as Map<String, dynamic>;
      final product = assets.byId[inp['product_id']]!;
      final plan = inp['plan'] == null
          ? null
          : [
              for (final x in inp['plan'] as List) PlanStep(x['kind'] == 'cook' ? PlanKind.cook : PlanKind.stand, (x['time_s'] as num).toDouble()),
            ];
      final sc = Scenario(
        product: product,
        containerKey: inp['container_key'] as String?,
        watt: (inp['watt'] as num).toDouble(),
        plan: plan,
        extraCookS: ((inp['extra_cook_s'] ?? 0) as num).toDouble(),
        eatInContainer: (inp['eat_in_container'] ?? true) as bool,
        bodyWeightKg: ((inp['body_weight_kg'] ?? 70) as num).toDouble(),
        method: inp['method'] == 'stove' ? HeatMethod.stove : HeatMethod.microwave,
      );
      final r = engine.evaluate(sc);
      final tag = jsonEncode(inp);
      expect(r.status, s['status'], reason: tag);
      expectClose(r.headlinePct, s['headline_pct'] as num?, reason: tag);
      expect(r.band?.name, s['band'], reason: tag);
      expect(r.flags, [for (final f in s['flags'] as List) f as String], reason: tag);
      if (s['range'] != null) {
        expectClose(r.range!.p05, s['range']['p05'] as num, reason: '$tag p05');
        expectClose(r.range!.p50, s['range']['p50'] as num, reason: '$tag p50');
        expectClose(r.range!.p95, s['range']['p95'] as num, reason: '$tag p95');
      } else {
        expect(r.range, isNull, reason: '$tag range');
      }
      expect(r.groups.keys.toSet(), (s['groups'] as Map<String, dynamic>).keys.toSet(), reason: '$tag groups');
      (s['groups'] as Map<String, dynamic>).forEach((g, val) => expectClose(r.groups[g], val as num, reason: '$tag $g'));
      if (s['t_contact_max'] != null) {
        expectClose(r.temperature!.tContactMax, s['t_contact_max'] as num, reason: tag);
        expectClose(r.temperature!.tEndAvg, s['t_end_avg'] as num, reason: '$tag t end');
      } else {
        expect(r.temperature, isNull, reason: '$tag temperature');
      }
      // null for measured, info and the other statuses without a model run
      expectClose(r.vsLabel, s['vs_label'] as num?, reason: '$tag vs label');
      expect(r.substances.keys.toSet(), (s['substances'] as Map<String, dynamic>).keys.toSet(), reason: '$tag substances');
      (s['substances'] as Map<String, dynamic>).forEach((k, m) {
        expectClose(r.substances[k]!.ug, m['ug'] as num, reason: '$tag $k ug');
        expectClose(r.substances[k]!.fraction, m['fraction'] as num, reason: '$tag $k fraction');
        expectClose(r.substances[k]!.fo, m['fo'] as num, reason: '$tag $k fo');
        expectClose(r.substances[k]!.alpha, m['alpha'] as num, reason: '$tag $k alpha');
        expectClose(r.substances[k]!.logK, m['log_k'] as num, reason: '$tag $k log K');
        expectClose(r.substances[k]!.tEff, m['t_eff'] as num, reason: '$tag $k T eff');
      });
    }
  });

  test('moving the meal to a plate removes the migration estimate', () {
    final p = assets.byId['zw-001']!;
    final alt = engine.alternatives(Scenario(product: p));
    expect(alt['ceramic']!.status, 'inert');
    expect(alt['ceramic']!.headlinePct, 0.0);
    expect(alt['stove']!.status, 'inert');
  });

  test('longer cooking never lowers the estimate for a computed container', () {
    final p = assets.byId['zw-001']!;
    double? last;
    for (final extra in [0.0, 30.0, 60.0, 120.0]) {
      final r = engine.evaluate(Scenario(product: p, extraCookS: extra), mc: false);
      if (last != null) expect(r.headlinePct!, greaterThanOrEqualTo(last));
      last = r.headlinePct;
    }
  });

  test('food classes are ordered and cover 0..1', () {
    final fc = assets.params.foodClasses;
    expect(fc.first.fatMin, 0.0);
    for (var i = 1; i < fc.length; i++) {
      expect(fc[i].fatMin, fc[i - 1].fatMax);
    }
    expect(fc.last.fatMax, 1.0);
    expect(fc.map((f) => f.key), containsAll(<String>['lean', 'medium', 'fatty']));
  });

  test('container statuses used by the UI exist', () {
    final c = assets.params.containers;
    expect(c['eps_foam']!.status, ContainerStatus.block);
    expect(c['glass']!.status, ContainerStatus.inert);
    expect(c['steam_bag']!.status, ContainerStatus.ok);
    expect(c['steam_bag']!.contactMode, 'steam');
    expect(c['paper_cup']!.status, ContainerStatus.measured);
    expect(c['popcorn_bag']!.status, ContainerStatus.info);
    expect(c['cpet_tray']!.status, ContainerStatus.ok);
    expect(assets.params.measured['paper_cup'], isNotEmpty);
  });
}
