// "Is this your product?" One card when the match is clear, three choices when it is not,
// and an invitation to add the product when nothing matches.
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/core.dart';
import '../../ui/product_head.dart';
import '../../ui/soft.dart';
import '../../ui/sprites.dart';
import '../../ui/theme.dart';
import '../flows.dart';
import 'product_search_sheet.dart';
import 'package:zapwise/ui/i18n.dart';

class ConfirmScreen extends StatelessWidget {
  final ScanOutcome outcome;
  final String photoPath;
  const ConfirmScreen({super.key, required this.outcome, required this.photoPath});

  Future<void> _pick(BuildContext context, Product p) async {
    final s = AppScope.read(context);
    final v = outcome.vision;
    if (v != null) {
      // the confirmed photo makes the next scan of this package faster
      try {
        await s.service.rememberProductPhoto(p.id, v);
      } catch (_) {}
    }
    if (context.mounted) openGuide(context, p, replace: true);
  }

  Future<void> _search(BuildContext context) async {
    final p = await showProductSearch(context);
    if (p != null && context.mounted) openGuide(context, p, replace: true);
  }

  void _register(BuildContext context) => openRegister(
        context,
        frontPhoto: photoPath,
        ocrText: outcome.text.text,
        barcode: outcome.text.barcodes.isEmpty ? null : outcome.text.barcodes.first,
        vision: outcome.vision,
        replace: true,
      );

  @override
  Widget build(BuildContext context) {
    final m = outcome.match;
    final best = m.best;
    final title = switch (m.decision) {
      MatchDecision.confirm => 'Is this your product?',
      MatchDecision.choose => 'Which one is it?',
      MatchDecision.register => 'New to me',
    };
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: title, onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: gapped([
              if (m.decision == MatchDecision.confirm && best != null) ...[
                _ProductCard(c: best),
                PixelButton(label: 'Yes, that\'s it', onPressed: () => _pick(context, best.product)),
                if (m.ranked.length > 1) const Padding(padding: EdgeInsets.only(top: 6), child: TText('Other close matches', style: ZT.h3)),
                for (final c in m.ranked.skip(1).take(2)) _Choice(c: c, onTap: () => _pick(context, c.product)),
              ],
              if (m.decision == MatchDecision.choose) ...[
                TText('Tap the one you have.', style: ZT.small),
                for (final c in m.ranked.take(3)) _Choice(c: c, onTap: () => _pick(context, c.product), showScore: true),
              ],
              if (m.decision == MatchDecision.register) ...[
                Raised(
                  child: Column(children: [
                    const Zappy(Mood.thinking, scale: 3),
                    const SizedBox(height: 10),
                    TText('I don\'t know this box yet', style: ZT.h2, textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    TText('Snap two more photos and I\'ll add it, for you and the next person.',
                        style: ZT.small, textAlign: TextAlign.center),
                  ]),
                ),
                PixelButton(label: 'Help add this product', onPressed: () => _register(context)),
              ],
              SoftButton(label: 'Find it by name', lead: const ZIcon('learn'), onPressed: () => _search(context)),
              SoftButton(label: 'Skip the scan', sub: 'Pick the container and type the box time', lead: const ZIcon('timer'), onPressed: () => openQuickEstimate(context, replace: true)),
              if (m.decision != MatchDecision.register) Center(child: ZLink('My product isn\'t here', onTap: () => _register(context))),
            ])),
          ),
        ]),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Candidate c;
  const _ProductCard({required this.c});

  @override
  Widget build(BuildContext context) {
    final p = c.product;
    final container = AppScope.of(context).params.containers[p.containerKey];
    return ProductHead(
      product: p,
      containerLabel: container?.labelEn ?? p.containerKey,
      tags: [BandChip(BandKind.lower, text: c.barcode ? 'Barcode match' : '${(c.score * 100).round()}% match')],
    );
  }
}

class _Choice extends StatelessWidget with LineRow {
  final Candidate c;
  final VoidCallback onTap;
  final bool showScore;
  const _Choice({required this.c, required this.onTap, this.showScore = false});

  @override
  Widget build(BuildContext context) => SoftButton(
        label: c.product.name,
        sub: c.product.brand,
        trailing: showScore ? '${(c.score * 100).round()}%' : null,
        lead: SizedBox(width: 48, height: 40, child: Center(child: PixelFit(productSprite(c.product), maxWidth: 48, maxHeight: 40))),
        onPressed: onTap,
      );
}
