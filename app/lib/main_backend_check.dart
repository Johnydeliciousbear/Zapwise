// Minimal screen to check that the core works on a real phone before the full UI exists.
//   flutter run -t lib/main_backend_check.dart
// Shows the label recipe and estimate for one seed product, the alternatives, and whether
// the vision model loaded.
import 'package:flutter/material.dart';

import 'core/core.dart';

void main() => runApp(const MaterialApp(home: BackendCheck()));

class BackendCheck extends StatefulWidget {
  const BackendCheck({super.key});
  @override
  State<BackendCheck> createState() => _BackendCheckState();
}

class _BackendCheckState extends State<BackendCheck> {
  String _log = 'loading...';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final b = StringBuffer();
    try {
      final assets = await ZapAssets.load();
      final engine = ZapEngine(assets.params);
      b.writeln('data ${assets.params.version}: ${assets.products.length} products, ${assets.params.containers.length} containers');
      final p = assets.byId['zw-001']!;
      final sw = Stopwatch()..start();
      final r = engine.evaluate(Scenario(product: p, watt: 1100));
      b.writeln('${p.displayName}\n  container ${r.containerKey}, status ${r.status}');
      for (final s in r.recipe.steps) {
        b.writeln('  ${s.kind} ${s.timeS.round()} s  ${s.text}');
      }
      b.writeln('  ${r.headlinePct?.toStringAsFixed(3)} % TDI (${r.band?.name}), range ${r.range?.p05.toStringAsFixed(3)}-${r.range?.p95.toStringAsFixed(3)}');
      b.writeln('  flags ${r.flags}  (${sw.elapsedMilliseconds} ms with Monte Carlo)');
      final more = engine.evaluate(Scenario(product: p, watt: 1100, extraCookS: 120), mc: false);
      b.writeln('  +2 min: ${more.headlinePct?.toStringAsFixed(3)} % (x${more.vsLabel?.toStringAsFixed(2)})');
      engine.alternatives(Scenario(product: p)).forEach((k, v) => b.writeln('  $k: ${v.status} ${v.headlinePct ?? '-'}'));
      try {
        final vm = await VisionModel.load();
        b.writeln('vision model loaded: ${vm.labels.classes}');
        vm.close();
      } catch (e) {
        b.writeln('vision model failed: $e');
      }
    } catch (e, st) {
      b.writeln('error $e\n$st');
    }
    setState(() => _log = b.toString());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ZapWise core check')),
        body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: SelectableText(_log, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
      );
}
