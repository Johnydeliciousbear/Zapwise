// Other kitchen appliances: add one to the counter, air fryer, stove.
import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/core.dart';
import '../ui/sheets.dart';
import '../ui/soft.dart';
import '../ui/sprites.dart';
import '../ui/theme.dart';
import 'package:zapwise/ui/i18n.dart';

Future<void> showAddApplianceSheet(BuildContext context) => showZapSheet<void>(context, (ctx) {
      final s = AppScope.of(ctx);
      Widget tile(ApplianceKind kind, String name, Widget art) {
        final on = s.hasAppliance(kind);
        final content = Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            art,
            const SizedBox(height: 8),
            TText(name, style: ZT.small.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            if (on) TText('On your counter', style: ZT.smallMuted.copyWith(fontSize: 12)),
          ]),
        );
        // a tile without a card; the ones on the counter are tinted
        return Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => s.toggleAppliance(kind, name),
            child: Container(
              height: 120,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: on ? const Color(0x8CFBC9CF) : null, borderRadius: BorderRadius.circular(14)),
              child: content,
            ),
          ),
        );
      }

      return SheetBody(title: 'Add an appliance', children: [
        TText('Pick what you have. It goes on your counter.', style: ZT.smallMuted),
        Row(children: [
          Expanded(child: tile(ApplianceKind.airFryer, 'Air fryer', const PixelImage('objects/air_fryer', scale: 2))),
          const SizedBox(width: 10),
          Expanded(child: tile(ApplianceKind.oven, 'Toaster oven', const PixelImage('objects/toaster_oven', scale: 3))),
          const SizedBox(width: 10),
          Expanded(child: tile(ApplianceKind.kettle, 'Electric kettle', const PixelImage('objects/kettle', scale: 3))),
        ]),
        TText('No estimate for these yet. The plastic tray usually stays out of them, which already helps.',
            style: ZT.foot),
      ]);
    });

/// Sheet for an appliance on the counter: what it means for ZapWise, and a way to take it off.
Future<void> showCounterApplianceSheet(BuildContext context, ApplianceKind kind) => showZapSheet<void>(context, (ctx) {
      final s = AppScope.of(ctx);
      final (title, sprite, scale, text) = switch (kind) {
        ApplianceKind.oven => ('Toaster oven', 'objects/toaster_oven', 4.0,
            'It\'s on your counter. Toaster oven heating isn\'t estimated yet. Food goes on the metal rack or a pan, so the plastic tray stays out.'),
        ApplianceKind.kettle => ('Electric kettle', 'objects/kettle', 5.0,
            'It\'s on your counter. For cup noodles, boil water here and pour it over the noodles in a bowl. That skips the paper or foam cup.'),
        _ => ('Air fryer', 'objects/air_fryer', 3.0,
            'No estimate for air fryers yet. The food goes in the basket, not its plastic tray, so that already helps.'),
      };
      return SheetBody(title: title, children: [
        Row(children: [
          PixelImage(sprite, scale: scale),
          const SizedBox(width: 14),
          Expanded(child: TText(text, style: ZT.small)),
        ]),
        SoftButton(
          label: 'Remove from counter',
          lead: const ZIcon('swap'),
          onPressed: () async {
            await s.toggleAppliance(kind, title);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
        ),
        Center(
          child: ZLink('Add an appliance', onTap: () {
            Navigator.of(ctx).pop();
            showAddApplianceSheet(context);
          }),
        ),
      ]);
    });

/// Kept for older callers.
Future<void> showAirFryerSheet(BuildContext context) => showCounterApplianceSheet(context, ApplianceKind.airFryer);

Future<void> showStoveSheet(BuildContext context) => showZapSheet<void>(context, (ctx) => SheetBody(title: 'Stove', children: [
      Row(children: [
        const PixelImage('objects/stove', scale: 2),
        const SizedBox(width: 14),
        Expanded(
          child: TText('A metal pot adds no plastic. When a meal can go in a pot, I\'ll offer it.', style: ZT.small),
        ),
      ]),
    ]));
