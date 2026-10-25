// Family members (age group or weight) and the reset confirmation.
import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/core.dart';
import '../screens/scan/product_search_sheet.dart' show ZTextField;
import '../ui/copy.dart';
import '../ui/sheets.dart';
import '../ui/soft.dart';
import '../ui/theme.dart';
import 'package:zapwise/ui/i18n.dart';

Future<void> showPersonSheet(BuildContext context, {Profile? edit}) => showZapSheet<void>(context, (ctx) => _PersonBody(edit: edit));

class _PersonBody extends StatefulWidget {
  final Profile? edit;
  const _PersonBody({this.edit});

  @override
  State<_PersonBody> createState() => _PersonBodyState();
}

class _PersonBodyState extends State<_PersonBody> {
  late final _name = TextEditingController(text: widget.edit == null ? '' : (widget.edit!.isDefault ? 'You' : widget.edit!.name));
  late final _weight = TextEditingController();
  late String _group = widget.edit?.group ?? 'child';
  bool _lb = true;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      final typical = AppScope.read(context).params.bodyWeights[e.group];
      if (typical == null || (typical - e.bodyWeightKg).abs() > 0.01) _weight.text = (e.bodyWeightKg * 2.20462).round().toString();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = AppScope.read(context);
    final raw = double.tryParse(_weight.text.trim());
    final kg = raw == null || raw <= 0 ? null : (_lb ? raw / 2.20462 : raw);
    final name = _name.text.trim().isEmpty ? 'Family member' : _name.text.trim();
    await s.saveProfile(id: widget.edit?.id, name: widget.edit?.isDefault == true ? widget.edit!.name : name, group: _group, weightKg: kg);
    if (!mounted) return;
    toast(context, widget.edit == null ? '$name added' : 'Saved');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final isDefault = widget.edit?.isDefault == true;
    final typical = s.params.bodyWeights[_group];
    return SheetBody(title: widget.edit == null ? 'Add a family member' : (isDefault ? 'About you' : 'Edit ${widget.edit!.name}'), children: [
      if (!isDefault) ZTextField(hint: 'Name or nickname', controller: _name, label: 'Name or nickname', maxLength: 20),
      TText('Age group', style: ZT.small.copyWith(fontWeight: FontWeight.w800)),
      ChoiceRow<String>(options: kAgeGroups, selected: _group, onSelected: (g) => setState(() => _group = g)),
      TText(typical == null ? '' : 'Typical weight: ${kgText(typical)}', style: ZT.smallMuted),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: ZTextField(hint: 'Optional', controller: _weight, label: 'Weight', keyboardType: const TextInputType.numberWithOptions(decimal: true), maxLength: 5)),
        const SizedBox(width: 10),
        ChoiceRow<bool>(options: const [(true, 'lb'), (false, 'kg')], selected: _lb, onSelected: (v) => setState(() => _lb = v)),
      ]),
      TText('Saved only on this phone. Used to size the daily limit.', style: ZT.smallMuted),
      PixelButton(label: widget.edit == null ? 'Add' : 'Save', onPressed: _save),
      if (widget.edit != null && !isDefault)
        Center(
          child: ZLink('Remove ${widget.edit!.name}', onTap: () async {
            await s.deleteProfile(widget.edit!.id);
            if (context.mounted) Navigator.of(context).pop();
          }),
        ),
    ]);
  }
}

Future<void> showResetSheet(BuildContext context) => showZapSheet<void>(context, (ctx) => SheetBody(title: 'Reset everything?', children: [
      TText('This deletes your kitchen, shelf, log, quests, stars, family and added products from this phone.', style: ZT.small),
      PixelButton(
        label: 'Reset everything',
        onPressed: () async {
          await AppScope.read(ctx).resetEverything();
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
      SoftButton(label: 'Keep my data', center: true, onPressed: () => Navigator.of(ctx).pop()),
    ]));
