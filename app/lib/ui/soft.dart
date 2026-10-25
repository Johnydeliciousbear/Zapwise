// Soft UI building blocks: raised cards, inset wells, buttons, chips and the top bar.
// Only one pixel button (PixelButton) per screen; other choices use SoftButton.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'sprites.dart';
import 'theme.dart';
import 'package:zapwise/ui/i18n.dart';

const kRaisedShadow = [
  BoxShadow(color: ZC.shade, offset: Offset(6, 6), blurRadius: 14),
  BoxShadow(color: ZC.glow, offset: Offset(-6, -6), blurRadius: 14),
];
const kRaisedShadowSmall = [
  BoxShadow(color: ZC.shade, offset: Offset(3, 3), blurRadius: 8),
  BoxShadow(color: ZC.glow, offset: Offset(-3, -3), blurRadius: 8),
];

/// Raised (convex) card.
class Raised extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool small;
  final Color color;
  const Raised({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14), this.radius = ZS.cardRadius, this.small = false, this.color = ZC.milk});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), boxShadow: small ? kRaisedShadowSmall : kRaisedShadow),
        child: child,
      );
}

/// Inset (concave) well. Flutter has no inset box shadow, so the two inner shadows are painted.
class Well extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool small;
  final Color color;
  const Well({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14), this.radius = ZS.wellRadius, this.small = false, this.color = ZC.milk});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: InsetPainter(radius: radius, offset: small ? 2 : 4, blur: small ? 5 : 9, color: color),
        child: Padding(padding: padding, child: child),
      );
}

class InsetPainter extends CustomPainter {
  final double radius;
  final double offset;
  final double blur;
  final Color color;
  final bool circle;
  const InsetPainter({required this.radius, this.offset = 4, this.blur = 9, this.color = ZC.milk, this.circle = false});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = circle ? RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2)) : RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rr, Paint()..color = color);
    canvas.save();
    canvas.clipRRect(rr);
    final frame = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(blur * 3 + offset))
      ..addRRect(rr);
    final sigma = blur * 0.57735 + 0.5;
    canvas.drawPath(frame.shift(Offset(offset, offset)), Paint()
      ..color = ZC.shade
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma));
    canvas.drawPath(frame.shift(Offset(-offset, -offset)), Paint()
      ..color = ZC.glow
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma));
    canvas.restore();
  }

  @override
  bool shouldRepaint(InsetPainter old) => old.radius != radius || old.offset != offset || old.blur != blur || old.color != color || old.circle != circle;
}

/// The one strong action on a screen: 3 px cocoa border, hard shadow, presses down 5 px.
class PixelButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final bool small;
  final bool ghost;
  const PixelButton({super.key, required this.label, this.onPressed, this.icon, this.small = false, this.ghost = false});

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final drop = widget.small ? 3.0 : 5.0;
    final fill = !enabled ? ZC.disabledFill : (widget.ghost ? ZC.paper : ZC.straw);
    final edge = enabled ? ZC.cocoa : ZC.disabledEdge;
    final text = (widget.small ? ZT.cta.copyWith(fontSize: 15) : ZT.cta).copyWith(color: enabled ? ZC.cocoa : ZC.disabledText);
    return Semantics(
      button: true,
      enabled: enabled,
      label: tr(context, widget.label),
      excludeSemantics: true,
      onTap: widget.onPressed, // the GestureDetector's own tap action is excluded above
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          transform: Matrix4.translationValues(0, _down ? drop : 0, 0),
          constraints: BoxConstraints(minHeight: widget.small ? 40 : 58),
          padding: EdgeInsets.symmetric(horizontal: widget.small ? 14 : 16, vertical: 6),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(ZS.pixelRadius),
            border: Border.all(color: edge, width: widget.small ? 2.5 : 3),
            boxShadow: [BoxShadow(color: edge, offset: Offset(0, _down ? 0 : drop))],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (enabled && !widget.ghost)
                Positioned(top: 1, left: 3, right: 3, child: Container(height: 4, decoration: BoxDecoration(color: ZC.blush, borderRadius: BorderRadius.circular(2)))),
              Row(
                mainAxisSize: widget.small ? MainAxisSize.min : MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[ZIcon(widget.icon!, size: widget.small ? 24 : 32), const SizedBox(width: 10)],
                  Flexible(child: TText(widget.label, style: text, textAlign: TextAlign.center)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rows that sit flush under each other, split by a line. [gapped] joins neighbouring rows
/// and draws a line above the first one of a group.
mixin LineRow {
  bool get lined => true;
  bool get topLine => true; // false for a block that already ends a section above the rows
}

/// Lower-weight choice: a flat row with a line under it and a chevron that says it opens something.
class SoftButton extends StatefulWidget with LineRow {
  final String label;
  final String? sub; // small line under the label
  final String? trailing; // right-hand note, e.g. 'near 0%'
  final Widget? lead; // icon or sprite
  final VoidCallback? onPressed;
  final bool selected;
  final bool center; // a centred rose word with no line, for a secondary action
  const SoftButton({super.key, required this.label, this.sub, this.trailing, this.lead, this.onPressed, this.selected = false, this.center = false});

  @override
  bool get lined => !center;

  @override
  State<SoftButton> createState() => _SoftButtonState();
}

class _SoftButtonState extends State<SoftButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final center = widget.center;
    final content = Row(
      mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        if (widget.lead != null) ...[widget.lead!, const SizedBox(width: 12)],
        Flexible(
          fit: center ? FlexFit.loose : FlexFit.tight,
          child: Column(
            crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TText(widget.label, style: ZT.button.copyWith(color: center || widget.selected ? ZC.roseDeep : ZC.cocoa)),
              if (widget.sub != null && widget.sub!.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 2), child: TText(widget.sub!, style: ZT.smallMuted.copyWith(fontSize: 12.5))),
            ],
          ),
        ),
        if (widget.trailing != null) ...[const SizedBox(width: 8), TText(widget.trailing!, style: ZT.smallMuted, textAlign: TextAlign.right)],
        if (!center) ...[const SizedBox(width: 6), const Icon(Icons.chevron_right_rounded, color: ZC.cocoa2, size: 22)],
      ],
    );
    return Semantics(
      button: true,
      selected: widget.selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onPressed == null ? null : (_) => setState(() => _down = true),
        onTapUp: widget.onPressed == null ? null : (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onPressed,
        child: Container(
          constraints: BoxConstraints(minHeight: center ? 48 : 56),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          decoration: BoxDecoration(
            color: _down ? ZC.pressTint : null,
            border: center ? null : const Border(bottom: BorderSide(color: ZC.line)),
          ),
          alignment: Alignment.centerLeft,
          child: content,
        ),
      ),
    );
  }
}

/// Round raised button (back, close).
class RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String semantic;
  const RoundButton({super.key, required this.icon, required this.onPressed, required this.semantic});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tr(context, semantic),
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: ZC.milk, shape: BoxShape.circle, boxShadow: kRaisedShadowSmall),
            child: Icon(icon, color: ZC.cocoa, size: 22),
          ),
        ),
      );
}

/// Star counter: the star and the number, no pill around them.
class StarPill extends StatelessWidget {
  final int stars;
  final VoidCallback onPressed;
  const StarPill({super.key, required this.stars, required this.onPressed});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$stars stars, open quests',
        excludeSemantics: true,
        onTap: onPressed,
        child: GestureDetector(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 44,
            padding: const EdgeInsets.only(left: 6, right: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const ZIcon('star'),
              const SizedBox(width: 4),
              TText('$stars', style: ZT.h2.copyWith(fontFeatures: const [ui.FontFeature.tabularFigures()])),
            ]),
          ),
        ),
      );
}

enum BandKind { lower, middle, higher, none }

/// Result band chip: colour, icon and word together (never colour alone).
class BandChip extends StatelessWidget {
  final BandKind band;
  final String? text; // overrides the band word
  final bool outline; // false inside list rows, where a filled chip is enough
  const BandChip(this.band, {super.key, this.text, this.outline = true});

  static Color colorOf(BandKind b) => switch (b) {
        BandKind.lower => ZC.mint,
        BandKind.middle => ZC.butter,
        BandKind.higher => ZC.peach,
        BandKind.none => ZC.paper,
      };

  @override
  Widget build(BuildContext context) {
    final (icon, word) = switch (band) {
      BandKind.lower => ('check', 'Low'),
      BandKind.middle => ('info', 'Medium'),
      BandKind.higher => ('alert', 'High'),
      BandKind.none => ('info', ''),
    };
    if (!outline) {
      // no alignment here: it would stretch the chip across a Column
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colorOf(band),
          borderRadius: BorderRadius.circular(999),
          border: band == BandKind.none ? Border.all(color: ZC.lineStrong) : null,
        ),
        child: TText(text ?? word, style: ZT.small.copyWith(fontWeight: FontWeight.w800)),
      );
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.fromLTRB(6, 3, 12, 3),
      decoration: BoxDecoration(color: colorOf(band), borderRadius: BorderRadius.circular(999), border: Border.all(color: ZC.cocoa, width: 2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ZIcon(icon, size: 20),
        const SizedBox(width: 6),
        TText(text ?? word, style: ZT.small.copyWith(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// Small butter tag such as 'Not verified yet' or 'Sample'.
class Tag extends StatelessWidget {
  final String text;
  final Color color;
  const Tag(this.text, {super.key, this.color = ZC.butter});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: TText(text, style: ZT.small.copyWith(fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

/// Progress track: inset rail with a butter fill.
class Track extends StatelessWidget {
  final double value; // 0..1
  const Track(this.value, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 14,
        child: Well(
          radius: 999,
          small: true,
          padding: const EdgeInsets.all(3),
          child: LayoutBuilder(builder: (context, c) {
            final v = value < 0 ? 0.0 : (value > 1 ? 1.0 : value);
            var w = c.maxWidth * v;
            if (v > 0 && w < 8) w = c.maxWidth < 8 ? c.maxWidth : 8.0;
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: w,
                decoration: BoxDecoration(color: ZC.butter, borderRadius: BorderRadius.circular(999), border: Border.all(color: ZC.cocoa, width: 1.5)),
              ),
            );
          }),
        ),
      );
}

/// Choices as underlined words, centred; the selected one is rose with a thicker line.
class ChoiceRow<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final Set<T> disabled;
  final Map<T, String> small; // optional smaller note after a word, e.g. '170 g'
  const ChoiceRow({super.key, required this.options, required this.selected, required this.onSelected, this.disabled = const <Never>{}, this.small = const <Never, String>{}});

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 2,
        children: [
          for (final (v, label) in options)
            Semantics(
              button: true,
              selected: v == selected,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: disabled.contains(v) ? null : () => onSelected(v),
                child: Opacity(
                  opacity: disabled.contains(v) ? 0.55 : 1,
                  // the 44 px tap area stays as empty space; the line sits 3 px under the word
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Center(
                      widthFactor: 1,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(2, 0, 2, 3),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: v == selected ? ZC.roseDeep : ZC.lineStrong, width: v == selected ? 3 : 2)),
                        ),
                        child: small[v] == null
                          ? TText(label, textAlign: TextAlign.center, style: _style(v == selected))
                          : Text.rich(
                              TextSpan(children: [
                                TextSpan(text: tr(context, label), style: _style(v == selected)),
                                TextSpan(text: ' ${small[v]}', style: _style(v == selected).copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: ZC.cocoa2)),
                              ]),
                              textAlign: TextAlign.center,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );

  static TextStyle _style(bool on) => ZT.small.copyWith(fontSize: 14, height: 1.2, fontWeight: FontWeight.w800, color: on ? ZC.roseDeep : ZC.cocoa);
}

/// Two tabs over a line; the selected one is underlined in rose.
class Segmented<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ZC.line))),
        child: Row(children: [
          for (final (v, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(v),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: v == value ? ZC.roseDeep : const Color(0x00000000), width: 3))),
                    child: TText(label, style: ZT.small.copyWith(fontSize: 14, fontWeight: FontWeight.w800, color: v == value ? ZC.roseDeep : ZC.cocoa2)),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// Screen top bar with a back button and a centred pixel-font title.
class TopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  const TopBar({super.key, required this.title, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: SizedBox(
          height: 48,
          child: Row(children: [
            if (onBack != null) RoundButton(icon: Icons.chevron_left_rounded, onPressed: onBack!, semantic: 'Back') else const SizedBox(width: 44),
            Expanded(child: TText(title, style: ZT.title.copyWith(fontSize: 21), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
            trailing ?? const SizedBox(width: 44),
          ]),
        ),
      );
}

/// Tab screen header: left-aligned title and optional trailing widget.
class TabHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const TabHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: SizedBox(
          height: 48,
          child: Row(children: [Expanded(child: TText(title, style: ZT.title)), if (trailing != null) trailing!]),
        ),
      );
}

/// Underlined rose text link.
class ZLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final double fontSize;
  const ZLink(this.text, {super.key, required this.onTap, this.fontSize = 14});

  @override
  Widget build(BuildContext context) => Semantics(
        link: true,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: TText(text, style: ZT.link.copyWith(fontSize: fontSize))),
        ),
      );
}

/// Zappy speech card in the pixel style (hard shadow, white fill).
class ZappyTip extends StatelessWidget {
  final String text;
  final VoidCallback? onDismiss;
  final Mood mood;
  const ZappyTip(this.text, {super.key, this.onDismiss, this.mood = Mood.happy});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: ZC.paper,
          borderRadius: BorderRadius.circular(ZS.pixelRadius),
          border: Border.all(color: ZC.cocoa, width: 3),
          boxShadow: const [BoxShadow(color: ZC.cocoa, offset: Offset(4, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ZappyBody(mood, scale: 1.5),
            const SizedBox(width: 10),
            Expanded(child: TText(text, style: ZT.small.copyWith(fontSize: 14))),
          ]),
          if (onDismiss != null) Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(top: 8), child: PixelButton(label: 'Got it', small: true, onPressed: onDismiss))),
        ]),
      );
}

/// Warning note: a soft peach tint, no border.
class WarnCard extends StatelessWidget {
  final String title;
  final String body;
  const WarnCard({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: ZC.peachSoft, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const ZIcon('alert', size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TText(title, style: ZT.bodyBold.copyWith(height: 1.3)),
              const SizedBox(height: 2),
              TText(body, style: ZT.small.copyWith(height: 1.45)),
            ]),
          ),
        ]),
      );
}

/// Fold with a line above and below and no card: a header row that opens the details under it.
class Fold extends StatelessWidget {
  final String title;
  final String icon;
  final bool open;
  final VoidCallback onToggle;
  final List<Widget> children;
  const Fold({super.key, required this.title, required this.open, required this.onToggle, required this.children, this.icon = 'info'});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: ZC.line), bottom: BorderSide(color: ZC.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            button: true,
            expanded: open,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: SizedBox(
                height: 52,
                child: Row(children: [
                  ZIcon(icon, size: 24),
                  const SizedBox(width: 10),
                  Expanded(child: TText(title, style: ZT.button.copyWith(fontSize: 15))),
                  Text(open ? '−' : '+', style: ZT.button.copyWith(fontSize: 20)),
                ]),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
            ),
        ]),
      );
}

/// Section with a line under it, for reading text that used to sit in a card.
class LineSection extends StatelessWidget {
  final Widget child;
  const LineSection({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 18),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ZC.line))),
        child: child,
      );
}

/// One muted line with a small info icon, for notes that change what the user does.
class NoteLine extends StatelessWidget {
  final String text;
  const NoteLine(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const ZIcon('info', size: 20),
        const SizedBox(width: 8),
        Expanded(child: TText(text, style: ZT.smallMuted)),
      ]);
}

/// Inset square that holds a sprite thumbnail.
class ZThumb extends StatelessWidget {
  final String sprite;
  final double size;
  const ZThumb(this.sprite, {super.key, this.size = 78});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Well(radius: 16, small: true, padding: const EdgeInsets.all(8), child: Center(child: PixelFit(sprite, maxWidth: size - 16, maxHeight: size - 16))),
      );
}

/// Vertical list spacing helper. Neighbouring [LineRow]s sit flush, and the first row of a
/// group gets a line above it.
List<Widget> gapped(List<Widget> children, [double gap = ZS.gap]) {
  bool row(Widget w) => w is LineRow && (w as LineRow).lined; // LineRow is a mixin, not a Widget, so no promotion
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    final c = children[i];
    final joined = i > 0 && row(c) && row(children[i - 1]);
    if (i > 0 && !joined) out.add(SizedBox(height: gap));
    final top = row(c) && !joined && (c as LineRow).topLine;
    out.add(top ? DecoratedBox(decoration: const BoxDecoration(border: Border(top: BorderSide(color: ZC.line))), child: c) : c);
  }
  return out;
}
