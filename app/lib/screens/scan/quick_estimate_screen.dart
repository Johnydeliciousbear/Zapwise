// Quick estimate: for meals that are not in the app (store brands, dollar-store meals) or when
// the scan fails. The person picks the container from pictures, sets the time printed on the box
// with + and - buttons and taps the net weight printed on the front. The meal is built in memory
// and goes through the normal heating guide and result screens; nothing is registered.
import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../sheets/shelf_sheets.dart' show shortLabel;
import '../../ui/copy.dart';
import '../../ui/soft.dart';
import '../../ui/sprites.dart';
import '../../ui/theme.dart';
import '../guide/guide_screen.dart';
import 'package:zapwise/ui/i18n.dart';

/// Packaging people heat meals in, in the order the picture grid shows them.
const kQuickContainers = ['cpet_tray', 'pp_container', 'paper_cup', 'steam_bag', 'pouch', 'pet_board_tray', 'paperboard_tray', 'takeout_tub', 'eps_foam', 'pet_clamshell'];

/// Ids of meals made here start with this, so the log can name them.
const kQuickIdPrefix = 'quick-';

class QuickEstimateScreen extends StatefulWidget {
  const QuickEstimateScreen({super.key});

  @override
  State<QuickEstimateScreen> createState() => _QuickEstimateScreenState();
}

class _QuickEstimateScreenState extends State<QuickEstimateScreen> {
  String? _container;
  double _seconds = 180;
  double _watt = 1100;
  bool _wattPicked = false;
  String _fat = 'medium';
  double? _oz; // net weight from the box front, in ounces
  bool _other = false;
  final _otherCtl = TextEditingController();

  static const _watts = [700.0, 800.0, 900.0, 1000.0, 1100.0, 1200.0];
  static const _ozChoices = [6.0, 8.0, 10.0, 12.0, 16.0];
  static const _gPerOz = 28.3495;

  @override
  void dispose() {
    _otherCtl.dispose();
    super.dispose();
  }

  /// Grams of food from the net weight; null until one is chosen or typed.
  double? get _grams {
    final o = _other ? double.tryParse(_otherCtl.text.trim().replaceAll(',', '.')) : _oz;
    return o != null && o > 0 ? o * _gPerOz : null;
  }
  // fat share used for each choice: the middle of the app's lean, medium and fatty classes
  static const _fatShare = {'lean': 0.02, 'medium': 0.06, 'fatty': 0.14};

  Product _build(String key, double grams) => Product(
        id: '$kQuickIdPrefix$key',
        brand: 'My meal',
        name: 'Quick estimate',
        category: 'user',
        netG: grams,
        servings: 1,
        foodMassG: grams,
        fatFraction: _fatShare[_fat],
        fatClass: _fat,
        fatKnown: true,
        storage: key == 'paper_cup' ? Storage.shelf : Storage.frozen, // cup noodles sit on a shelf
        containerKey: key,
        containerConfidence: 'user',
        recipe: Recipe(
          refWatt: _watt,
          refWattAssumed: !_wattPicked,
          steps: [LabelStep(kind: StepKind.cook, text: 'cook on HIGH', timeS: _seconds)],
          wattTable: const [],
          completeness: _wattPicked ? 'complete' : 'partial',
          doNotMicrowave: 'no',
          ovenOnly: false,
        ),
        searchTokens: const [],
        flags: const ['quick estimate'],
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            TopBar(title: 'Quick estimate', onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: gapped([
                const TText('No product needed. Pick the container and type the time printed on the box.', style: ZT.small),
                const TText('What is the meal in?', style: ZT.h3),
                _grid(),
                const TText('Time on the box', style: ZT.h3),
                Row(children: [
                  _Step(icon: Icons.remove_rounded, label: '30 seconds less', onTap: _seconds > 30 ? () => setState(() => _seconds -= 30) : null),
                  Expanded(child: Center(child: Text(mmss(_seconds), style: ZT.bigNumber.copyWith(fontSize: 46, height: 1.05)))),
                  _Step(icon: Icons.add_rounded, label: '30 seconds more', onTap: _seconds < 1200 ? () => setState(() => _seconds += 30) : null),
                ]),
                const TText('For how many watts? Leave it at 1100 if the box doesn\'t say.', style: ZT.smallMuted, textAlign: TextAlign.center),
                ChoiceRow<double>(
                  options: [for (final w in _watts) (w, '${w.round()} W')],
                  selected: _watt,
                  onSelected: (w) => setState(() {
                    _watt = w;
                    _wattPicked = true;
                  }),
                ),
                const TText('How fatty is it?', style: ZT.h3),
                ChoiceRow<String>(
                  options: const [('lean', 'Not much (rice, veggies, soup)'), ('medium', 'Some (pasta, chicken)'), ('fatty', 'A lot (cheese, cream, fried)')],
                  selected: _fat,
                  onSelected: (f) => setState(() => _fat = f),
                ),
                const TText('Net weight on the box', style: ZT.h3),
                const TText('Printed on the front, like “NET WT 10 OZ (283 g)”.', style: ZT.smallMuted),
                ChoiceRow<double>(
                  options: [for (final o in _ozChoices) (o, '${o.round()} oz'), (-1.0, 'Other')],
                  small: {for (final o in _ozChoices) o: '${(o * _gPerOz).round()} g'},
                  selected: _other ? -1.0 : _oz,
                  onSelected: (o) => setState(() {
                    _other = o < 0;
                    _oz = o < 0 ? null : o;
                  }),
                ),
                if (_other)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const TText('Net weight', style: ZT.bodyBold),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        controller: _otherCtl,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        style: ZT.body.copyWith(fontWeight: FontWeight.w800, fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: 'oz',
                          isDense: true,
                          contentPadding: EdgeInsets.fromLTRB(4, 12, 4, 10),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: ZC.lineStrong, width: 2)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: ZC.roseDeep, width: 2)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('oz', style: ZT.bodyBold),
                  ]),
                PixelButton(
                  label: 'Show my estimate',
                  onPressed: _container == null || _grams == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GuideScreen(product: _build(_container!, _grams!), unverified: true))),
                ),
              ])),
            ),
          ]),
        ),
      );

  Widget _grid() => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
        children: [
          for (final k in kQuickContainers)
            Semantics(
              button: true,
              selected: _container == k,
              label: tr(context, shortLabel(k)),
              excludeSemantics: true,
              onTap: () => setState(() => _container = k),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _container = k),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _container == k ? const Color(0x8CFBC9CF) : null, borderRadius: BorderRadius.circular(14)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    PixelFit(containerSprite(k), maxWidth: 72, maxHeight: 48),
                    const SizedBox(height: 6),
                    TText(shortLabel(k),
                        style: ZT.small.copyWith(fontSize: 12.5, fontWeight: FontWeight.w800, color: _container == k ? ZC.roseDeep : ZC.cocoa),
                        textAlign: TextAlign.center,
                        maxLines: 2),
                  ]),
                ),
              ),
            ),
        ],
      );
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Step({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tr(context, label),
        child: GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.4 : 1,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(color: ZC.milk, shape: BoxShape.circle, boxShadow: kRaisedShadowSmall),
              child: Icon(icon, color: ZC.cocoa, size: 28),
            ),
          ),
        ),
      );
}
