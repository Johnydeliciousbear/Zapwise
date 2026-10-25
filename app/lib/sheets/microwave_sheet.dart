// Zappy, the microwave: set the wattage from the door label, by hand, or with the boil test.
import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/core.dart';
import '../screens/capture_screen.dart';
import '../ui/copy.dart';
import '../ui/sheets.dart';
import '../ui/soft.dart';
import '../ui/sprites.dart';
import '../ui/theme.dart';
import 'package:zapwise/ui/i18n.dart';

Future<void> showMicrowaveSheet(BuildContext context) => showZapSheet<void>(context, (ctx) => const _MicrowaveBody());

class _MicrowaveBody extends StatefulWidget {
  const _MicrowaveBody();

  @override
  State<_MicrowaveBody> createState() => _MicrowaveBodyState();
}

class _MicrowaveBodyState extends State<_MicrowaveBody> {
  double? _w;
  double? _measured;
  String? _note;
  bool _noteOk = true; // false when the label photo found no watts
  bool _reading = false;
  bool _boilMode = false;
  final _watch = Stopwatch();
  Timer? _tick;

  static const _choices = [600.0, 700.0, 800.0, 900.0, 1000.0, 1100.0, 1200.0];

  @override
  void initState() {
    super.initState();
    final m = AppScope.read(context).microwave;
    _w = m?.ratedWatt ?? m?.measuredWatt;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _snap() async {
    final s = AppScope.read(context);
    final path = await Navigator.of(context).push<String>(CaptureScreen.route(
      title: 'Snap the label',
      hint: 'The label is inside the door or on the back',
      folder: 'appliances',
    ));
    if (path == null || !mounted) return;
    setState(() {
      _reading = true;
      _note = null;
    });
    final text = await s.service.readText(path);
    final w = wattFromApplianceLabel(text.text);
    if (!mounted) return;
    setState(() {
      _reading = false;
      _noteOk = w != null;
      if (w != null) {
        _w = w;
        _note = 'Found ${w.round()} W on the label.';
      } else {
        _note = 'Couldn\'t find the watts. Pick them below or try the boil test.';
      }
    });
  }

  void _toggleWatch() {
    if (_watch.isRunning) {
      _watch.stop();
      _tick?.cancel();
      final secs = _watch.elapsedMilliseconds / 1000.0;
      final w = wattFromBoilTest(secs);
      setState(() {
        _measured = w;
        _w ??= w;
        _noteOk = true;
        _note = 'Boiled in ${timeWords(secs)}, so about ${w.round()} W or more.';
      });
    } else {
      _watch
        ..reset()
        ..start();
      _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() {});
      });
      setState(() => _measured = null);
    }
  }

  Future<void> _save() async {
    final s = AppScope.read(context);
    final w = _w;
    if (w == null) return;
    await s.setMicrowave(rated: w, measured: _measured);
    if (!mounted) return;
    toast(context, 'Microwave set to ${w.round()} W');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => SheetBody(title: 'Your microwave', children: [
        Row(children: [
          const Zappy(Mood.happy, scale: 3),
          const SizedBox(width: 14),
          Expanded(
            child: TText('Find the watts on a label inside the door or on the back.',
                style: ZT.small),
          ),
        ]),
        if (!_boilMode) ...[
          SoftButton(
            label: 'Snap the label',
            sub: _reading ? 'Reading the label…' : 'Camera',
            lead: const ZIcon('camera'),
            onPressed: _reading ? null : _snap,
          ),
          if (_note != null) TText(_note!, style: _noteOk ? ZT.small.copyWith(color: ZC.mintDeep) : ZT.smallMuted),
          TText('Or pick yours', style: ZT.smallMuted, textAlign: TextAlign.center),
          ChoiceRow<double>(options: [for (final w in _choices) (w, '${w.round()} W')], selected: _w, onSelected: (w) => setState(() => _w = w)),
          if (_w != null && !_choices.contains(_w)) TText('From the label: ${_w!.round()} W', style: ZT.small),
          Center(child: ZLink('No label? Try the boil test', onTap: () => setState(() => _boilMode = true))),
          // a way out for people who can't find the label or time the boil test; the heating
          // guide then shows the box time with a check-it's-hot reminder (never a shorter time)
          SoftButton(
            label: 'I don\'t know',
            sub: 'Use the box time and check that it\'s hot',
            lead: const ZIcon('info'),
            onPressed: () {
              toast(context, 'OK. I\'ll show the box time and remind you to check that it\'s hot.');
              Navigator.of(context).pop();
            },
          ),
        ] else ...[
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const TText('Boil test', style: ZT.h3),
              const SizedBox(height: 6),
              TText(
                  '1. Pour 1 cup of ice-cold water into a 2-cup glass measuring cup.\n'
                  '2. Start the microwave on HIGH and tap Start here at the same time.\n'
                  '3. Tap Stop when the water boils.',
                  style: ZT.small),
              const SizedBox(height: 6),
              TText('Under 2 min: 1000 W or more. About 2:30: 800 W. About 3 min: 650 to 700 W.', style: ZT.foot),
            ]),
          Column(children: [
            TText(_watch.isRunning ? 'Waiting for the boil' : 'Stopwatch', style: ZT.smallMuted.copyWith(fontWeight: FontWeight.w800)),
            Text(mmss(_watch.elapsedMilliseconds / 1000.0), style: ZT.bigNumber.copyWith(fontSize: 46, height: 1.05)),
          ]),
          SoftButton(label: _watch.isRunning ? 'It\'s boiling' : 'Start', lead: const ZIcon('timer'), center: true, onPressed: _toggleWatch),
          if (_note != null) TText(_note!, style: ZT.small.copyWith(color: ZC.mintDeep)),
          Center(child: ZLink('Back to the label', onTap: () => setState(() => _boilMode = false))),
        ],
        PixelButton(label: _w == null ? 'Save' : 'Save ${_w!.round()} W', onPressed: _w == null ? null : _save),
      ]);
}
