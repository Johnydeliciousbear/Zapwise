// Ring gauge for one meal and bar chart for the week.
import 'dart:math' as m;

import 'package:flutter/material.dart';

import 'soft.dart';
import 'theme.dart';

/// Share of the daily limit as an arc in an inset ring. A full circle is 100 %.
class RingGauge extends StatelessWidget {
  final double pct;
  final BandKind band;
  final Widget center;
  final double size;
  const RingGauge({super.key, required this.pct, required this.band, required this.center, this.size = 168});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(pct, BandChip.colorOf(band)),
          child: Center(child: Padding(padding: const EdgeInsets.all(26), child: center)),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color color;
  _RingPainter(this.pct, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const InsetPainter(radius: 0, circle: true).paint(canvas, size);
    if (pct <= 0) return;
    final r = size.shortestSide / 2 - 14;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    // at least a few degrees so very small shares are still visible
    final sweep = m.max(0.06, m.min(1.0, pct / 100.0)) * 2 * m.pi;
    canvas.drawArc(rect, -m.pi / 2, sweep, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt
      ..color = ZC.cocoa);
    canvas.drawArc(rect, -m.pi / 2 + 0.02, sweep - 0.04, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.butt
      ..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct || old.color != color;
}

/// Seven bars, one per day, coloured by band; the label above each bar is the day's %.
class WeekBars extends StatelessWidget {
  final List<double> values; // % of the daily limit per day, oldest first
  final List<String> labels;
  final double lowCut; // band edges
  final double highCut;
  const WeekBars({super.key, required this.values, required this.labels, required this.lowCut, required this.highCut});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Daily share of the limit, last 7 days: ${[for (var i = 0; i < values.length; i++) '${labels[i]} ${values[i].toStringAsFixed(1)} percent'].join(', ')}',
        child: SizedBox(height: 160, width: double.infinity, child: CustomPaint(painter: _BarsPainter(values, labels, lowCut, highCut))),
      );
}

class _BarsPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double lowCut, highCut;
  _BarsPainter(this.values, this.labels, this.lowCut, this.highCut);

  void _text(Canvas canvas, String s, Offset center, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const top = 22.0;
    final base = size.height - 24;
    canvas.drawLine(Offset(0, base), Offset(size.width, base), Paint()
      ..color = ZC.shade
      ..strokeWidth = 2);
    final n = values.length;
    if (n == 0) return;
    final maxV = m.max(lowCut, values.fold<double>(0, (a, b) => m.max(a, b)));
    final bw = m.min(30.0, size.width / n * 0.6);
    final step = size.width / n;
    for (var i = 0; i < n; i++) {
      final cx = step * i + step / 2;
      final v = values[i];
      if (v > 0) {
        final h = m.max(4.0, (base - top) * v / maxV);
        final col = v < lowCut ? ZC.mint : (v < highCut ? ZC.butter : ZC.peach);
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(cx - bw / 2, base - h, bw, h), const Radius.circular(5));
        canvas.drawRRect(r, Paint()..color = col);
        canvas.drawRRect(r, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ZC.cocoa);
        _text(canvas, v < 10 ? v.toStringAsFixed(1) : v.round().toString(), Offset(cx, base - h - 10),
            const TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w800, fontSize: 12, color: ZC.cocoa));
      }
      _text(canvas, labels[i], Offset(cx, size.height - 9), const TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w700, fontSize: 11, color: ZC.cocoa2));
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.values != values || old.labels != labels;
}
