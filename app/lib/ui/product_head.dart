// Product line at the top of a flow screen: thumbnail, name, brand and weight, the container and
// small tags. No card around it.
import 'package:flutter/material.dart';

import '../core/data/models.dart';
import 'copy.dart';
import 'soft.dart';
import 'sprites.dart';
import 'theme.dart';
import 'package:zapwise/ui/i18n.dart';

class ProductHead extends StatelessWidget {
  final Product product;
  final String? containerLabel; // English label, translated here
  final List<Widget> tags;
  const ProductHead({super.key, required this.product, this.containerLabel, this.tags = const []});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final first = [tr(context, p.brand), if (p.netG != null) ozAndGrams(p.netG)].where((x) => x.isNotEmpty).join(', ');
    return Row(children: [
      ZThumb(productSprite(p), size: 72),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TText(p.name, style: ZT.h2),
          const SizedBox(height: 2),
          Text([first, if (containerLabel != null) tr(context, containerLabel!)].where((x) => x.isNotEmpty).join('\n'), style: ZT.smallMuted),
          if (tags.isNotEmpty) ...[const SizedBox(height: 6), Wrap(spacing: 6, runSpacing: 6, children: tags)],
        ]),
      ),
    ]);
  }
}
