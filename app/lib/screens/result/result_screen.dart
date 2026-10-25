// "Your result": % of the daily limit from this container, the likely range, the band,
// family comparison and ways to lower it. The engine runs in a background isolate.
import 'dart:isolate';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/core.dart';
import '../../sheets/calc_sheet.dart';
import '../../sheets/quest_sheet.dart';
import '../../ui/charts.dart';
import '../../ui/copy.dart';
import '../../ui/sheets.dart';
import '../../ui/soft.dart';
import '../../ui/sprites.dart';
import '../../ui/theme.dart';
import '../flows.dart';
import '../shell.dart';
import 'package:zapwise/ui/i18n.dart';

class ResultArgs {
  final Product product;
  final String? containerKey; // null: the product's own container
  final HeatMethod method;
  final double extraCookS;
  const ResultArgs({required this.product, this.containerKey, this.method = HeatMethod.microwave, this.extraCookS = 0});

  ResultArgs withContainer(String key) => ResultArgs(product: product, containerKey: key, method: HeatMethod.microwave, extraCookS: extraCookS);
}

/// Top-level on purpose: a closure made inside a State method can carry the State (and its
/// widget tree) into the isolate message, which cannot be sent. This one holds only its arguments.
Future<EvalResult> _evaluateInBackground(ZapEngine engine, Scenario sc) => Isolate.run(() => engine.evaluate(sc));

/// How many times bigger the estimate gets with 2 more minutes of heating (centre values, no
/// Monte Carlo, so both runs are compared like for like). Null when there is nothing to compare.
Future<double?> _plusTwoMinutesRatio(ZapEngine engine, Scenario sc) => Isolate.run(() {
      final base = engine.evaluate(sc, mc: false).headlinePct;
      final more = engine.evaluate(sc.copyWith(extraCookS: sc.extraCookS + 120), mc: false).headlinePct;
      if (base == null || more == null || base <= 0) return null;
      return more / base;
    });

class ResultScreen extends StatefulWidget {
  final ResultArgs args;
  const ResultScreen({super.key, required this.args});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  EvalResult? _r;
  Scenario? _sc;
  double _bw = 70; // body weight the result was computed for
  Object? _error;
  bool _saving = false;
  bool _details = false;
  double? _plus2; // estimate with 2 more minutes, as a multiple of this one

  @override
  void initState() {
    super.initState();
    _compute();
  }

  Future<void> _compute() async {
    final s = AppScope.read(context);
    final a = widget.args;
    final prof = s.activeProfile;
    final sc = Scenario(product: a.product, containerKey: a.containerKey, watt: s.watt, extraCookS: a.extraCookS, bodyWeightKg: prof.bodyWeightKg, method: a.method);
    final engine = s.service.engine;
    try {
      final r = await _evaluateInBackground(engine, sc);
      if (mounted) {
        setState(() {
          _r = r;
          _sc = sc;
          _bw = prof.bodyWeightKg;
        });
      }
      if (a.method == HeatMethod.microwave && a.extraCookS == 0 && r.status != 'inert' && (r.headlinePct ?? 0) > 0) {
        try {
          final x = await _plusTwoMinutesRatio(engine, sc);
          if (mounted) setState(() => _plus2 = x);
        } catch (_) {
          // the comparison is extra; the estimate above still stands without it
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// % of the TDI scales with 1 / body weight, so other people need no new run.
  double? _scaled(double? pct, double bw) => pct == null ? null : pct * _bw / bw;

  Future<void> _save() async {
    final r = _r, sc = _sc;
    if (r == null || sc == null || _saving) return;
    setState(() => _saving = true);
    final s = AppScope.read(context);
    final nav = rootNavKey.currentState ?? Navigator.of(context);
    // log the meal for the person currently selected, with their own body weight
    await s.saveMeal(sc.copyWith(bodyWeightKg: s.activeProfile.bodyWeightKg), r.groups.isEmpty || _bw == s.activeProfile.bodyWeightKg ? r : _rescaled(r, s.activeProfile.bodyWeightKg));
    if (!mounted) return;
    final ctx = nav.context;
    ShellNav.goTab(context, 0);
    toast(ctx, 'Saved to today\'s log');
    if (ctx.mounted) await celebrateFinished(ctx);
  }

  EvalResult _rescaled(EvalResult r, double bw) => EvalResult(
        productId: r.productId,
        containerKey: r.containerKey,
        status: r.status,
        flags: r.flags,
        recipe: r.recipe,
        groups: {for (final e in r.groups.entries) e.key: e.value * _bw / bw},
        headlinePct: _scaled(r.headlinePct, bw),
        headlineGroup: r.headlineGroup,
        band: r.band,
        range: r.range,
        substances: r.substances,
        temperature: r.temperature,
        vsLabel: r.vsLabel,
      );

  void _switchTo(String containerKey) => Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ResultScreen(args: widget.args.withContainer(containerKey))));

  void _stove() => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => ResultScreen(args: ResultArgs(product: widget.args.product, method: HeatMethod.stove, extraCookS: widget.args.extraCookS))));

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = _r;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: 'Your result', onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: r == null
                ? _waiting()
                : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: gapped(_body(context, s, r))),
          ),
        ]),
      ),
    );
  }

  Widget _waiting() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Zappy(_error == null ? Mood.thinking : Mood.worried, scale: 3),
          const SizedBox(height: 12),
          TText(_error == null ? 'Working it out' : 'Couldn\'t work this out: $_error', style: ZT.h3, textAlign: TextAlign.center),
        ]),
      );

  List<Widget> _body(BuildContext context, AppState s, EvalResult r) {
    final params = s.params;
    final prof = s.activeProfile;
    final pct = _scaled(r.headlinePct, prof.bodyWeightKg);
    final band = bandOfPct(pct, params);
    final c = params.containers[r.containerKey];
    final stove = widget.args.method == HeatMethod.stove;
    final kidKg = params.bodyWeights['child'] ?? 30.0;
    final out = <Widget>[];
    var numberShown = false; // microwave notes only sit next to a number

    final oven = r.status == 'oven_only' || r.status == 'label_no_microwave';
    if (!s.profileChosen && s.profiles.length == 1) {
      out.add(Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ZC.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const TText('Who\'s eating?', style: ZT.h3),
          const SizedBox(height: 6),
          ChoiceRow<String>(options: kAgeGroups, selected: prof.group, onSelected: (g) => s.chooseOwnGroup(g)),
        ]),
      ));
    }
    out.add(TText(methodLabel(containerKey: r.containerKey, params: params, stove: stove, oven: oven), style: ZT.smallMuted, textAlign: TextAlign.center));

    switch (r.status) {
      case 'block':
        out.add(WarnCard(title: 'Don\'t heat food in this', body: c?.reasonEn.isNotEmpty == true ? c!.reasonEn : 'This container isn\'t made for heat.'));
        out.add(SoftButton(label: 'Move it to a plate', lead: const ZIcon('plate'), trailing: 'almost 0%', onPressed: () => _switchTo('ceramic')));
      case 'oven_only':
      case 'label_no_microwave':
        out.add(_message(Mood.neutral, 'Oven only', '${widget.args.product.recipe.ovenText.isEmpty ? 'The box only has oven directions.' : widget.args.product.recipe.ovenText}\n\nNo number for oven heating yet.'));
      case 'info':
      case 'no_data':
        out.add(_message(Mood.neutral, r.status == 'info' ? 'No number for this one' : 'No data on this container yet',
            c?.reasonEn.isNotEmpty == true ? c!.reasonEn : 'No lab data to go on yet.'));
      case 'ok' when r.flags.contains('no_recipe'):
        out.add(_message(Mood.thinking, 'No microwave steps yet',
            'I need the box\'s microwave directions to work this out. On a plate, there\'s no plastic to worry about.'));
        out.add(SoftButton(label: 'Move it to a plate', lead: const ZIcon('plate'), trailing: 'almost 0%', onPressed: () => _switchTo('ceramic')));
      default:
        numberShown = true;
        out.add(_gauge(r, pct, band, prof, params));
        // the habit that changes the number most: heating past the box time
        if (_plus2 != null && _plus2! >= 1.2 && !stove && widget.args.extraCookS == 0) out.add(_plusTwo(_plus2!));
        if (s.profiles.length > 1 && pct != null) out.add(_who(s, r));
        // with no family added, still show what the same meal means for a child
        if (s.profiles.length <= 1 && pct != null && pct > 0 && (prof.group == 'adult' || prof.group == 'teen')) {
          out.add(TText('For a ${kidKg.round()} kg kid, this same meal is ${pctText(_scaled(r.headlinePct, kidKg))}.', style: ZT.small, textAlign: TextAlign.center));
        }
        final extra = widget.args.extraCookS;
        if (extra != 0 && r.vsLabel != null && r.vsLabel! > 0) {
          out.add(TText(
              extra > 0
                  ? 'Heating ${timeWords(extra)} longer made this ${r.vsLabel!.toStringAsFixed(1)}× higher. Stick to the box time.'
                  : 'Heating ${timeWords(-extra)} less cut this by ${((1 - r.vsLabel!) * 100).round()}%.',
              style: ZT.small,
              textAlign: TextAlign.center));
        }
        if (pct != null && pct > 0) {
          out.add(const Padding(padding: EdgeInsets.only(top: 4), child: TText('Make it lower', style: ZT.h2)));
          out.add(SoftButton(label: 'Move it to a plate', lead: const ZIcon('plate'), trailing: 'almost 0%', onPressed: () => _switchTo('ceramic')));
          final glass = s.shelf.where((it) => s.params.containers[it.containerKey]?.status == ContainerStatus.inert).toList();
          if (glass.isNotEmpty) {
            out.add(SoftButton(
                label: 'My ${glass.first.name.toLowerCase()}',
                lead: PixelFit(containerSprite(glass.first.containerKey), maxWidth: 32, maxHeight: 32),
                trailing: 'almost 0%',
                onPressed: () => _switchTo(glass.first.containerKey)));
          }
          out.add(SoftButton(label: 'Heat it on the stove', lead: const ZIcon('flame'), trailing: 'almost 0%', onPressed: _stove));
        }
    }

    final refWatt = widget.args.product.recipe.refWatt;
    // microwave notes mean nothing for the oven, the stove, a plate or a screen with no number
    final notes = !numberShown || oven || stove || r.status == 'inert' ? const <String>[] : flagNotes(r.flags, watt: s.watt, refWatt: refWatt);
    final moreNotes = flagNotes(r.flags, watt: s.watt, refWatt: refWatt, practical: false);
    for (final n in notes) {
      out.add(NoteLine(n));
    }
    if (numberShown && (r.substances.isNotEmpty || r.groups.isNotEmpty)) out.add(_detailsCard(r, params, prof.bodyWeightKg, moreNotes));

    out.add(Padding(
      padding: const EdgeInsets.only(top: 6),
      child: PixelButton(label: _saving ? 'Saving' : 'Save to my log', onPressed: _saving ? null : _save),
    ));
    out.add(Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
      TText('Only counts what comes from the container. Not a medical test. ', style: ZT.foot),
      ZLink('How we calculate', fontSize: 12.5, onTap: () => showCalcSheet(context)),
    ]));
    return out;
  }

  Widget _message(Mood mood, String title, String body) => Raised(
        child: Column(children: [
          Zappy(mood, scale: 3),
          const SizedBox(height: 10),
          TText(title, style: ZT.h2, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          TText(body, style: ZT.small, textAlign: TextAlign.center),
        ]),
      );

  Widget _plusTwo(double x) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const ZIcon('timer'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TText('2 more minutes: about ${x.toStringAsFixed(1)}× more', style: ZT.bodyBold.copyWith(height: 1.3)),
              const SizedBox(height: 2),
              TText('Heating past the box time adds the most. Stick to the box time, or move it to a plate.', style: ZT.small.copyWith(height: 1.45)),
            ]),
          ),
        ]),
      );

  /// Zappy says the verdict; the ring and the band word sit centred under it.
  Widget _gauge(EvalResult r, double? pct, BandKind band, Profile prof, ZapParams params) {
    final inert = r.status == 'inert';
    final whose = prof.isDefault ? 'your' : '${prof.name}\'s';
    final (icon, word, color) = switch (band) {
      BandKind.lower => ('check', 'Low', ZC.mintDeep),
      BandKind.middle => ('info', 'Medium', const Color(0xFF8A6100)),
      BandKind.higher => ('alert', 'High', const Color(0xFFA4441E)),
      BandKind.none => ('info', '', ZC.cocoa2),
    };
    return Raised(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(children: [
        Row(children: [
          Zappy(moodFor(band), scale: 1.5),
          const SizedBox(width: 12),
          Expanded(child: TText(verdictText(band, inert: inert, containerKey: r.containerKey), style: ZT.h2.copyWith(fontSize: 17, height: 1.3))),
        ]),
        const SizedBox(height: 12),
        RingGauge(
          pct: pct ?? 0,
          band: band,
          size: 176,
          center: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(child: Text(pctText(pct), style: ZT.bigNumber)),
            TText(limitCaption(r.headlineGroup, whose), style: ZT.smallMuted.copyWith(fontSize: 11.5, height: 1.25), textAlign: TextAlign.center),
          ]),
        ),
        if (word.isNotEmpty || r.status == 'measured') ...[
          const SizedBox(height: 12),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (word.isNotEmpty) ...[
              ZIcon(icon, size: 24),
              const SizedBox(width: 8),
              TText(word, style: ZT.bodyBold.copyWith(color: color, height: 1.0)),
            ],
            if (r.status == 'measured') ...[const SizedBox(width: 8), const Tag('From lab tests')],
          ]),
        ],
      ]),
    );
  }

  /// Everyone in the family, one row each, split by lines.
  Widget _who(AppState s, EvalResult r) => Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: ZC.line))),
        child: Column(children: [
          for (final p in s.profiles)
            Semantics(
              button: true,
              selected: p.id == s.activeProfile.id,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => s.setActive(p.id),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ZC.line))),
                  child: Row(children: [
                    Expanded(
                      child: TText(p.isDefault ? 'You' : p.name,
                          style: ZT.button.copyWith(fontSize: 14, color: p.id == s.activeProfile.id ? ZC.roseDeep : ZC.cocoa)),
                    ),
                    Text(pctText(_scaled(r.headlinePct, p.bodyWeightKg)), style: ZT.h3.copyWith(color: p.id == s.activeProfile.id ? ZC.roseDeep : ZC.cocoa)),
                  ]),
                ),
              ),
            ),
        ]),
      );

  Widget _detailsCard(EvalResult r, ZapParams params, double bw, List<String> notes) => Fold(
        title: 'How we got this number',
        open: _details,
        onToggle: () => setState(() => _details = !_details),
        children: [
          if (r.range != null) TText('Likely range: ${pctText(_scaled(r.range!.p05, bw))} to ${pctText(_scaled(r.range!.p95, bw))}', style: ZT.small),
          if (r.headlineGroup != null && params.groups[r.headlineGroup] != null) TText(_limitLine(params.groups[r.headlineGroup]!), style: ZT.small),
          for (final n in notes) Padding(padding: const EdgeInsets.only(top: 4), child: TText(n, style: ZT.smallMuted)),
          const SizedBox(height: 6),
          if (r.temperature != null)
            TText(
                'Food ends at ${r.temperature!.tEndAvg.toStringAsFixed(0)}°C on average. The container wall peaks at ${r.temperature!.tContactMax.toStringAsFixed(0)}°C.',
                style: ZT.small),
          for (final e in r.groups.entries) TText('${params.groups[e.key]?.labelEn ?? e.key}: ${pctText(_scaled(e.value, bw))} of the limit', style: ZT.small),
          for (final e in r.substances.entries)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TText(
                '${params.substances[e.key]?.name ?? e.key}: ${_num(e.value.ug)} µg in the whole package, '
                '${(e.value.fraction * 100).toStringAsFixed(1)}% of the way to equilibrium, '
                'log K ${e.value.logK.toStringAsFixed(2)} at ${e.value.tEff.toStringAsFixed(0)}°C, Fo ${e.value.fo.toStringAsExponential(1)}',
                style: ZT.smallMuted,
              ),
            ),
          if (r.range != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TText('Range from ${params['mc_samples'].round()} Monte Carlo runs (5th to 95th percentile).', style: ZT.smallMuted),
            ),
        ],
      );

  String _limitLine(ReferenceGroup g) =>
      '${g.labelEn} ${g.key == 'lead' ? 'reference point' : 'daily safe limit'}: ${_num(g.tdi)} µg per kg of body weight (${g.agency}${g.year != null ? ' ${g.year}' : ''})';

  String _num(double v) {
    if (v == 0) return '0';
    if (v >= 100) return v.round().toString();
    if (v >= 1) return v.toStringAsFixed(1);
    if (v >= 0.01) return v.toStringAsFixed(2);
    return v.toStringAsExponential(1);
  }
}
