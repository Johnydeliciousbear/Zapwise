// Heating guide: the total time in large type, the box steps for the user's microwave, one safety
// note, then how to heat it.
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/core.dart';
import '../../sheets/microwave_sheet.dart';
import '../../sheets/shelf_sheets.dart';
import '../../ui/copy.dart';
import '../../ui/product_head.dart';
import '../../ui/soft.dart';
import '../../ui/sprites.dart';
import '../../ui/theme.dart';
import '../result/result_screen.dart';
import 'package:zapwise/ui/i18n.dart';

class GuideScreen extends StatefulWidget {
  final Product product;
  final bool unverified;
  const GuideScreen({super.key, required this.product, this.unverified = false});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  String? _checkedContainer; // set when the user checked an unknown tray
  double _extra = 0; // seconds added to the last cook step

  Product get p => widget.product;

  void _go({String? containerKey, HeatMethod method = HeatMethod.microwave, double extra = 0}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ResultScreen(args: ResultArgs(product: p, containerKey: containerKey, method: method, extraCookS: extra)),
    ));
  }

  Future<void> _checkTray() async {
    final key = await showContainerCheck(context, first: p.containerKey);
    if (key != null && mounted) setState(() => _checkedContainer = key);
  }

  Future<void> _useMine() async {
    final key = await chooseShelfContainer(context);
    if (key != null && mounted) _go(containerKey: key);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final params = s.params;
    final recipe = s.service.recipeFor(p, s.watt);
    final containerKey = _checkedContainer ?? p.containerKey;
    final c = params.containers[containerKey];
    final ovenOnly = p.recipe.ovenOnly;
    final cookTotal = recipe.cookSeconds;
    final tag = _checkedContainer != null
        ? 'Checked by you'
        : switch (p.containerConfidence) {
            'label' => 'From the box',
            'inferred' => 'Typical for this brand',
            'photo' => 'Read from the tray',
            'user' => 'Added by you',
            _ => 'Not checked yet',
          };
    final unsure = _checkedContainer == null && p.containerConfidence == 'unknown';

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: 'How to heat it', onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: gapped([
              ProductHead(product: p, containerLabel: c?.labelEn ?? containerKey, tags: [
                Tag(tag, color: unsure ? ZC.peach : ZC.butter),
                if (widget.unverified || p.containerConfidence == 'user') const Tag('Not verified yet'),
              ]),
              if (unsure)
                SoftButton(
                  label: 'Check the tray',
                  sub: 'Not sure what this tray is. Snap the bottom to check.',
                  lead: const ZIcon('container'),
                  onPressed: _checkTray,
                ),
              if (ovenOnly) ..._oven(context) else ..._microwave(context, s.wattSet, s.watt, recipe, cookTotal),
            ])),
          ),
        ]),
      ),
    );
  }

  /// Boxes with no microwave steps: say why, then offer the way the box does it.
  List<Widget> _oven(BuildContext context) {
    final r = p.recipe;
    final stoveMeal = p.containerKey == 'stove_pot';
    final cup = p.containerKey == 'eps_foam' || p.category == 'cup_bowl';
    final body = stoveMeal
        ? 'The box only has stove directions.'
        : cup
            ? 'The box says not to microwave this cup. Foam isn\'t made for heat.'
            : r.doNotMicrowave == 'yes'
                ? 'The box says oven only. Raw or breaded food has to reach 165°F (74°C) all the way through, and microwaves heat unevenly.'
                : 'The box only has oven directions.';
    return [
      WarnCard(title: 'Don\'t microwave this one', body: body),
      if (r.ovenText.isNotEmpty) ...[
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TText('Oven directions', style: _label),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const ZIcon('flame'),
            const SizedBox(width: 10),
            Expanded(child: TText(r.ovenText, style: _stepStyle)),
          ]),
        ]),
        PixelButton(label: 'Heat it in the oven', icon: 'flame', onPressed: () => _go(containerKey: _checkedContainer)),
      ] else if (stoveMeal)
        PixelButton(label: 'Heat it on the stove', icon: 'flame', onPressed: () => _go(method: HeatMethod.stove))
      else if (cup) ...[
        const TText('Boil water in a kettle or pot, then pour it over the noodles in a bowl.', style: ZT.small),
        PixelButton(label: 'Boil water and use a bowl', onPressed: () => _go(method: HeatMethod.stove)),
      ] else
        const TText('Follow the directions on the box.', style: ZT.smallMuted),
    ];
  }

  static final TextStyle _label = ZT.smallMuted.copyWith(fontWeight: FontWeight.w800);
  static final TextStyle _stepStyle = ZT.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.35);

  List<Widget> _microwave(BuildContext context, bool wattSet, double watt, ResolvedRecipe recipe, double cookTotal) {
    final s = AppScope.of(context);
    final steps = recipe.steps.where((x) => x.kind != 'oven').toList();
    final hasCook = cookTotal > 0;
    // with no cook step there is no time to change, so the time, its notes and the +/- row stay hidden
    final notes = hasCook ? flagNotes(recipe.flags, watt: watt, refWatt: p.recipe.refWatt) : const <String>[];
    final ck = _checkedContainer ?? p.containerKey;
    final where = ck == 'ceramic' ? 'on a plate' : 'in the ${containerNoun(ck)}';
    // the seconds added with + and - go on the last cook step, so the steps add up to the total
    final lastCook = steps.lastIndexWhere((x) => x.kind == 'cook');
    return [
      if (hasCook)
        Column(children: [
          TText(wattSet ? 'Total heating time' : 'Box time (${watt.round()} W)', style: _label),
          Text(mmss(cookTotal + _extra), style: ZT.bigNumber.copyWith(fontSize: 46, height: 1.05)),
          if (!wattSet) ZLink('Set your watts', onTap: () => showMicrowaveSheet(context)),
        ]),
      if (steps.isEmpty)
        const WarnCard(title: 'No microwave steps yet', body: 'Follow the box, or move it to a plate and skip the plastic.')
      else
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TText(wattSet ? 'Steps for your ${watt.round()} W microwave' : 'Steps from the box', style: _label),
          const SizedBox(height: 2),
          for (final (i, st) in steps.indexed)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 38),
              child: Row(children: [
                ZIcon(switch (st.kind) { 'cook' => 'timer', 'stand' => 'check', _ => 'swap' }, size: 24),
                const SizedBox(width: 10),
                Expanded(child: TText(_stepText(st), style: _stepStyle)),
                if (st.kind == 'cook' || st.kind == 'stand') Text(mmss(st.timeS + (i == lastCook ? _extra : 0)), style: ZT.h3.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
        ]),
      for (final n in notes) NoteLine(n),
      // undercooking is the faster danger, so every microwave meal gets this note
      if (hasCook) ...[
        WarnCard(
          title: 'Heat it all the way through',
          body: wattSet
              ? 'Stir and let it stand when the box says. The middle should be steaming hot: 165°F (74°C).'
              : 'This is the box time. A weaker microwave needs longer. Check that the middle is steaming hot, 165°F (74°C).',
        ),
        _TimeAdjust(extra: _extra, onChanged: (v) => setState(() => _extra = v), minExtra: -cookTotal * 0.5),
      ],
      PixelButton(
        label: hasCook ? 'Heat it $where (${mmss(cookTotal + _extra)})' : 'Heat it $where',
        onPressed: () => _go(containerKey: _checkedContainer, extra: _extra),
      ),
      SoftButton(label: 'Move it to a plate', lead: const ZIcon('plate'), onPressed: () => _go(containerKey: 'ceramic', extra: _extra)),
      SoftButton(
        label: 'Use my own dish',
        sub: s.shelf.isEmpty ? 'Your shelf is empty' : '${s.shelf.length} on your shelf',
        lead: const ZIcon('container'),
        onPressed: _useMine,
      ),
      SoftButton(label: 'Heat it on the stove', lead: const ZIcon('flame'), onPressed: () => _go(method: HeatMethod.stove)),
    ];
  }

  String _stepText(ResolvedStep st) {
    final t = st.text.trim();
    final cap = t.isEmpty ? st.kind : t[0].toUpperCase() + t.substring(1);
    if (st.kind == 'cook' && st.timeHi > st.timeLo + 1) return '$cap (${mmss(st.timeLo)} to ${mmss(st.timeHi)})';
    return cap;
  }
}

class _TimeAdjust extends StatelessWidget {
  final double extra;
  final double minExtra;
  final ValueChanged<double> onChanged;
  const _TimeAdjust({required this.extra, required this.onChanged, required this.minExtra});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(children: [
          const ZIcon('timer'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TText('Change the time', style: ZT.button),
              TText(extra == 0 ? 'Box time' : '${extra > 0 ? '+' : '−'}${timeWords(extra.abs())}', style: ZT.smallMuted),
            ]),
          ),
          _StepBtn(icon: Icons.remove_rounded, label: '30 seconds less', onTap: extra - 30 >= minExtra ? () => onChanged(extra - 30) : null),
          const SizedBox(width: 8),
          _StepBtn(icon: Icons.add_rounded, label: '30 seconds more', onTap: extra < 600 ? () => onChanged(extra + 30) : null),
        ]),
      );
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.4 : 1,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: ZC.milk, shape: BoxShape.circle, boxShadow: kRaisedShadowSmall),
              child: Icon(icon, color: ZC.cocoa),
            ),
          ),
        ),
      );
}
