// Find a product by typing part of its name.
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/core.dart';
import '../../ui/copy.dart';
import '../../ui/sheets.dart';
import '../../ui/soft.dart';
import '../../ui/sprites.dart';
import '../../ui/theme.dart';
import 'package:zapwise/ui/i18n.dart';

Future<Product?> showProductSearch(BuildContext context) => showZapSheet<Product>(context, (ctx) => const _SearchBody());

class _SearchBody extends StatefulWidget {
  const _SearchBody();

  @override
  State<_SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends State<_SearchBody> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final hits = s.service.searchProducts(_q, limit: 40);
    return SheetBody(title: 'Find your product', children: [
      ZTextField(hint: 'Brand or meal, like Lean Cuisine', autofocus: true, onChanged: (v) => setState(() => _q = v)),
      if (hits.isEmpty) TText('No match. Try one word from the box.', style: ZT.smallMuted),
      for (final p in hits)
        SoftButton(
          label: p.name,
          sub: '${p.brand}${p.netG != null ? ', ${ozAndGrams(p.netG)}' : ''}',
          lead: SizedBox(width: 48, height: 40, child: Center(child: PixelFit(productSprite(p), maxWidth: 48, maxHeight: 40))),
          onPressed: () => Navigator.of(context).pop(p),
        ),
    ]);
  }
}

/// Text field with a line under it.
class ZTextField extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool autofocus;
  final TextInputType? keyboardType;
  final String? label;
  final int maxLength;
  const ZTextField({super.key, required this.hint, this.onChanged, this.controller, this.autofocus = false, this.keyboardType, this.label, this.maxLength = 60});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (label != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: TText(label!, style: ZT.small.copyWith(fontWeight: FontWeight.w800))),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          maxLength: maxLength,
          onChanged: onChanged,
          style: ZT.body.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
          decoration: InputDecoration(
            hintText: tr(context, hint),
            hintStyle: ZT.body.copyWith(color: ZC.cocoa2),
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
            // a line under the field, rose while typing; no box
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: ZC.lineStrong, width: 2)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: ZC.roseDeep, width: 2)),
          ),
        ),
      ]);
}
