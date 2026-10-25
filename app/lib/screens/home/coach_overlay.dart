// First-run kitchen tour: dims the screen, rings one object and lets Zappy explain it.
import 'package:flutter/material.dart';

import '../../ui/soft.dart';
import '../../ui/sprites.dart';
import '../../ui/theme.dart';
import 'package:zapwise/ui/i18n.dart';

class CoachStep {
  final GlobalKey? target; // null: no ring, bubble in the middle
  final String text;
  const CoachStep(this.target, this.text);
}

class CoachOverlay extends StatefulWidget {
  final GlobalKey stackKey; // the Stack this overlay fills; target rects are measured against it
  final List<CoachStep> steps;
  final VoidCallback onDone;
  const CoachOverlay({super.key, required this.stackKey, required this.steps, required this.onDone});

  @override
  State<CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<CoachOverlay> {
  int _i = 0;
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  Future<void> _measure() async {
    final t = widget.steps[_i].target;
    if (t == null || t.currentContext == null) {
      if (mounted) setState(() => _hole = null);
      return;
    }
    await Scrollable.ensureVisible(t.currentContext!, alignment: 0.5, duration: const Duration(milliseconds: 200));
    if (!mounted) return;
    final box = t.currentContext?.findRenderObject() as RenderBox?;
    final stack = widget.stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.hasSize) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: stack);
    setState(() => _hole = (topLeft & box.size).inflate(6));
  }

  void _next() {
    if (_i >= widget.steps.length - 1) {
      widget.onDone();
      return;
    }
    setState(() {
      _i++;
      _hole = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final hole = _hole;
        const bubbleH = 190.0;
        double top;
        if (hole == null) {
          top = c.maxHeight * 0.3;
        } else if (hole.bottom + bubbleH + 14 < c.maxHeight) {
          top = hole.bottom + 14;
        } else {
          top = hole.top - bubbleH;
          if (top < 16) top = 16;
        }
        final last = _i == widget.steps.length - 1;
        return Stack(children: [
          Positioned.fill(child: GestureDetector(onTap: () {}, child: CustomPaint(painter: _DimPainter(hole)))),
          Positioned(
            left: 16,
            right: 16,
            top: top,
            child: Semantics(
              container: true,
              label: 'Kitchen tour',
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                decoration: BoxDecoration(
                  color: ZC.paper,
                  borderRadius: BorderRadius.circular(ZS.pixelRadius),
                  border: Border.all(color: ZC.cocoa, width: 3),
                  boxShadow: const [BoxShadow(color: ZC.cocoa, offset: Offset(4, 4))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const ZappyBody(Mood.happy, scale: 2),
                    const SizedBox(width: 12),
                    Expanded(child: TText(widget.steps[_i].text, style: ZT.body.copyWith(fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    PixelButton(label: 'Skip', small: true, ghost: true, onPressed: widget.onDone),
                    const Spacer(),
                    for (var k = 0; k < widget.steps.length; k++)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(color: k == _i ? ZC.rose : ZC.blush, shape: BoxShape.circle, border: Border.all(color: ZC.cocoa, width: 1.5)),
                      ),
                    const Spacer(),
                    PixelButton(label: last ? 'Let\'s go' : 'Next', small: true, onPressed: _next),
                  ]),
                ]),
              ),
            ),
          ),
        ]);
      });
}

class _DimPainter extends CustomPainter {
  final Rect? hole;
  _DimPainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    final h = hole;
    if (h != null) path.addRRect(RRect.fromRectAndRadius(h, const Radius.circular(14)));
    canvas.drawPath(path, Paint()..color = ZC.dim);
    if (h != null) {
      canvas.drawRRect(RRect.fromRectAndRadius(h, const Radius.circular(14)), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ZC.butter);
    }
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.hole != hole;
}
