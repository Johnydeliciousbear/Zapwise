// The pixel kitchen on the home tab (196 x 216 px scene, coordinates from the prototype).
// Tap areas: Zappy the microwave, the container shelf, the fridge note (quests), the stove,
// the counter appliances (air fryer, toaster oven, kettle) and an empty slot for new ones.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../ui/sprites.dart';
import '../../ui/theme.dart';
import 'package:zapwise/ui/i18n.dart';

const double kSceneW = 196, kSceneH = 216;

/// Bottom-left corners of the five shelf places (scene pixels).
const List<(double, double)> kShelfSlots = [(123.0, 91.0), (146.0, 91.0), (168.0, 91.0), (123.0, 121.0), (155.0, 121.0)];

class KitchenKeys {
  final zappy = GlobalKey(debugLabel: 'zappy');
  final shelf = GlobalKey(debugLabel: 'shelf');
  final fridge = GlobalKey(debugLabel: 'fridge');
  final stove = GlobalKey(debugLabel: 'stove');
  final slot = GlobalKey(debugLabel: 'slot');
}

class KitchenScene extends StatefulWidget {
  final List<ShelfItem> shelf;
  final List<ApplianceKind> counter; // in the order they sit on the counter
  final bool rewardScene;
  final double? watt;
  final Set<String> seen;
  final Mood mood;
  final String questTag; // e.g. 'Quest 1/3'; shown on the fridge
  final KitchenKeys keys;
  final VoidCallback onZappy, onShelf, onFridge, onStove, onSlot;
  final ValueChanged<ApplianceKind> onAppliance;

  const KitchenScene({
    super.key,
    required this.shelf,
    required this.counter,
    required this.rewardScene,
    required this.watt,
    required this.seen,
    required this.mood,
    required this.questTag,
    required this.keys,
    required this.onZappy,
    required this.onShelf,
    required this.onFridge,
    required this.onStove,
    required this.onSlot,
    required this.onAppliance,
  });

  @override
  State<KitchenScene> createState() => _KitchenSceneState();
}

class _KitchenSceneState extends State<KitchenScene> {
  Timer? _blinkTimer;
  bool _blink = false;

  @override
  void initState() {
    super.initState();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 3800), (_) {
      if (!mounted || widget.mood != Mood.neutral) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
      setState(() => _blink = true);
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted) setState(() => _blink = false);
      });
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        // fit the width and, when the parent gives a height, the height too, so the scan button below stays on screen
        var s = c.maxWidth / kSceneW;
        if (c.maxHeight.isFinite) s = s < c.maxHeight / kSceneH ? s : c.maxHeight / kSceneH;
        if (s >= 2) s = s.floorToDouble(); // whole-number scale when the screen allows it
        final w = kSceneW * s, h = kSceneH * s;

        Positioned at(double x, double y, double pw, double ph, Widget child) => Positioned(left: x * s, top: y * s, width: pw * s, height: ph * s, child: child);

        Widget hot({required Key key, required String label, required VoidCallback onTap, Widget? child}) => Semantics(
              button: true,
              label: label,
              child: GestureDetector(key: key, behavior: HitTestBehavior.opaque, onTap: onTap, child: child ?? const SizedBox.expand()),
            );

        // a small label centred on scene x, with its top at scene y
        Widget tag(double cx, double top, String text, VoidCallback onTap, {bool highlight = false}) => Positioned(
              left: cx * s,
              top: top * s,
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0),
                child: ExcludeSemantics(
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 3 * s, vertical: 0.5 * s),
                      decoration: BoxDecoration(
                        color: highlight ? ZC.butter : ZC.paper,
                        borderRadius: BorderRadius.circular(3 * s),
                        border: Border.all(color: ZC.cocoa, width: s),
                      ),
                      child: TText(text, maxLines: 1, style: TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w800, fontSize: 5.5 * s, height: 1.25, color: ZC.cocoa)),
                    ),
                  ),
                ),
              ),
            );

        final hints = <(String, double, double)>[
          ('zappy', 74.0, 124.0),
          ('shelf', 186.0, 68.0),
          ('fridge', 30.0, 118.0),
          ('stove', 180.0, 134.0),
          ('slot', 108.0, 124.0),
        ];

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: PixelImage(widget.rewardScene ? 'scene/kitchen_reward' : 'scene/kitchen', scale: s, semanticLabel: 'Your pixel kitchen')),
              for (var i = 0; i < widget.shelf.length && i < kShelfSlots.length; i++)
                () {
                  final name = containerSprite(widget.shelf[i].containerKey);
                  final (sw, sh) = kSpriteSize[name]!;
                  final (x, y) = kShelfSlots[i];
                  return at(x, y - sh, sw.toDouble(), sh.toDouble(), IgnorePointer(child: PixelImage(name, scale: s)));
                }(),
              at(118, 74, 76, 50, hot(key: widget.keys.shelf, label: 'Container shelf, ${widget.shelf.length} containers', onTap: widget.onShelf)),
              at(2, 124, 38, 70, hot(key: widget.keys.fridge, label: 'Quest note on the fridge', onTap: widget.onFridge)),
              at(152, 140, 34, 54, hot(key: widget.keys.stove, label: 'Stove', onTap: widget.onStove)),
              at(
                48,
                132,
                30,
                22,
                hot(
                  key: widget.keys.zappy,
                  label: widget.watt == null ? 'Zappy, your microwave, watts not set' : 'Zappy, your microwave, ${widget.watt!.round()} watts',
                  onTap: widget.onZappy,
                  child: ZappyBody(_blink ? Mood.blink : widget.mood, scale: s),
                ),
              ),
              ..._counter(s, at, hot),
              // state tags: show what each thing is and where it stands, so it reads as tappable
              tag(63, 157, widget.watt == null ? 'Set watts' : '${widget.watt!.round()} W', widget.onZappy, highlight: widget.watt == null),
              tag(152, 126, widget.shelf.isEmpty ? 'Add dishes' : '${widget.shelf.length} ${widget.shelf.length == 1 ? 'dish' : 'dishes'}', widget.onShelf,
                  highlight: widget.shelf.isEmpty),
              tag(21, 172, widget.questTag, widget.onFridge),
              tag(169, 179, 'Stove', widget.onStove),
              for (final (k, x, y) in hints)
                if (!widget.seen.contains(k)) Positioned(left: x * s, top: y * s, child: IgnorePointer(child: _Sparkle(scale: s))),
            ]),
          ),
        );
      });
}

/// Counter appliances between Zappy and the stove, then the + slot if there is room for it.
extension on _KitchenSceneState {
  List<Widget> _counter(double scale, Positioned Function(double, double, double, double, Widget) at,
      Widget Function({required Key key, required String label, required VoidCallback onTap, Widget? child}) hot) {
    const art = {
      ApplianceKind.airFryer: ('objects/air_fryer', 22.0, 25.0, 'Air fryer'),
      ApplianceKind.oven: ('objects/toaster_oven', 24.0, 16.0, 'Toaster oven'),
      ApplianceKind.kettle: ('objects/kettle', 14.0, 16.0, 'Electric kettle'),
    };
    final out = <Widget>[];
    var x = 84.0;
    for (final k in widget.counter) {
      final a = art[k];
      if (a == null) continue;
      final (sprite, w, h, label) = a;
      out.add(at(x, 154 - h, w, h, hot(key: ValueKey(k.name), label: label, onTap: () => widget.onAppliance(k), child: PixelImage(sprite, scale: scale))));
      x += w + 2;
    }
    if (x + 26 <= 151) out.add(at(x + 2, 131, 26, 22, hot(key: widget.keys.slot, label: 'Add an appliance', onTap: widget.onSlot, child: const _Slot())));
    return out;
  }
}

class _Slot extends StatelessWidget {
  const _Slot();

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashPainter(),
        child: const Center(child: TText('+', style: TextStyle(fontFamily: ZFont.body, fontSize: 24, color: ZC.strawShade, fontWeight: FontWeight.w800))),
      );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6));
    canvas.drawRRect(r, Paint()..color = const Color(0x59FFFFFF));
    final paint = Paint()
      ..color = ZC.strawShade
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..addRRect(r.deflate(1));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

class _Sparkle extends StatefulWidget {
  final double scale;
  const _Sparkle({required this.scale});

  @override
  State<_Sparkle> createState() => _SparkleState();
}

class _SparkleState extends State<_Sparkle> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return PixelImage('objects/sparkle', scale: widget.scale);
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.55).animate(_a),
      child: ScaleTransition(scale: Tween(begin: 1.0, end: 0.75).animate(_a), child: PixelImage('objects/sparkle', scale: widget.scale)),
    );
  }
}
