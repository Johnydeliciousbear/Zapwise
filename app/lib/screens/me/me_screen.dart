// Me tab: who eats at home, the microwave, limits in use, products you added, your data.
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../sheets/microwave_sheet.dart';
import '../../sheets/person_sheets.dart';
import '../../ui/copy.dart';
import '../../ui/sheets.dart';
import '../../ui/soft.dart';
import '../../ui/sprites.dart';
import '../../ui/theme.dart';
import '../shell.dart';
import 'package:zapwise/ui/i18n.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.params;
    final active = s.activeProfile;
    final mw = s.microwave;
    return ListView(
      padding: EdgeInsets.only(bottom: tabBottomPadding(context)),
      children: [
        const TabHeader(title: 'Me'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: gapped([
            // first on the tab and in both languages, so someone who reads only Spanish can find it
            const Text('Language / Idioma', style: ZT.h3),
            ChoiceRow<String>(options: const [('en', 'English'), ('es', 'Español')], selected: LangScope.of(context), onSelected: (l) => setLanguage(l)),
            const Padding(padding: EdgeInsets.only(top: 6), child: TText('Family', style: ZT.h3)),
            for (final pr in s.profiles)
              SoftButton(
                label: pr.isDefault ? 'You' : pr.name,
                sub: '${ageLabel(pr.group)}, about ${kgText(pr.bodyWeightKg)}',
                trailing: pr.id == active.id ? 'Showing' : null,
                selected: pr.id == active.id,
                lead: ZIcon(pr.isDefault ? 'me' : 'heart'),
                onPressed: () => s.setActive(pr.id),
              ),
            _AddPersonRow(onAdd: () => showPersonSheet(context), onEdit: () => showPersonSheet(context, edit: active)),
            const Padding(padding: EdgeInsets.only(top: 6), child: TText('Your kitchen', style: ZT.h3)),
            SoftButton(
              label: 'Microwave',
              sub: mw?.watt == null ? 'Watts not set (using ${p['default_ref_watt'].round()} W)' : '${mw!.watt!.round()} W${mw.measuredWatt != null ? ', boil test done' : ''}',
              lead: const ZappyBody(Mood.neutral, scale: 1.4),
              onPressed: () => showMicrowaveSheet(context),
            ),
            if (s.registrations.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.only(top: 6), child: TText('Products you added', style: ZT.h3)),
              TText(
                  '${s.registrations.length} added, ${s.registrations.where((r) => r.status == 'shared').length} shared with Open Food Facts.',
                  style: ZT.smallMuted),
            ],
            const Padding(padding: EdgeInsets.only(top: 6), child: TText('Your data', style: ZT.h3)),
            TText('Everything stays on this phone unless you share a product.', style: ZT.smallMuted),
            if (s.sampleMealIds.isNotEmpty)
              SoftButton(
                label: 'Remove sample meals',
                lead: const ZIcon('log'),
                onPressed: () async {
                  await s.removeSampleMeals();
                  if (context.mounted) toast(context, 'Sample meals removed');
                },
              ),
            SoftButton(
              label: 'Replay the kitchen tour',
              lead: const ZIcon('quest'),
              onPressed: () {
                s.replayTutorial();
                ShellNav.goTab(context, 0);
              },
            ),
            SoftButton(label: 'Reset everything', lead: const ZIcon('swap'), onPressed: () => showResetSheet(context)),
            // the agency numbers are for curious readers; most people never need them, so they fold away
            const _LimitsCard(),
            TText('ZapWise $kAppVersion. Sources are in the Learn tab.', style: ZT.foot, textAlign: TextAlign.center),
          ])),
        ),
      ],
    );
  }
}

/// "Add a family member" and "Edit" share one row with a line under it.
class _AddPersonRow extends StatelessWidget with LineRow {
  final VoidCallback onAdd;
  final VoidCallback onEdit;
  const _AddPersonRow({required this.onAdd, required this.onEdit});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ZC.line))),
        child: Row(children: [
          Expanded(
            child: Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAdd,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  child: const Row(children: [ZIcon('heart'), SizedBox(width: 12), Expanded(child: TText('Add a family member', style: ZT.button))]),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: SizedBox(width: 72, height: 56, child: Center(child: TText('Edit', style: ZT.button.copyWith(color: ZC.roseDeep)))),
            ),
          ),
        ]),
      );
}

class _LimitsCard extends StatefulWidget {
  const _LimitsCard();

  @override
  State<_LimitsCard> createState() => _LimitsCardState();
}

class _LimitsCardState extends State<_LimitsCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).params;
    return Fold(
      title: 'Daily safe limits',
      open: _open,
      onToggle: () => setState(() => _open = !_open),
      children: [
        for (final g in p.groups.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TText('${g.labelEn}: ${g.tdi % 1 == 0 ? g.tdi.round() : g.tdi} µg/kg/day (${g.agency}${g.year != null ? ' ${g.year}' : ''})', style: ZT.small),
          ),
        const SizedBox(height: 4),
        const TText('Lead has no safe level, so it uses a reference point instead.', style: ZT.foot),
      ],
    );
  }
}
