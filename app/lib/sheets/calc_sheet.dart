// "How we calculate": the steps of the estimate and the numbers the app actually uses
// (read from zapwise_params.json, so this sheet always matches the engine).
import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../ui/sheets.dart';
import '../ui/soft.dart';
import '../ui/theme.dart';
import 'package:zapwise/ui/i18n.dart';

Future<void> showCalcSheet(BuildContext context) => showZapSheet<void>(context, (ctx) {
      final p = AppScope.of(ctx).params;
      String n(String k, [int dp = 0]) => p[k].toStringAsFixed(dp);
      final fc = {for (final f in p.foodClasses) f.key: f};
      final k = p.kpf;
      final rows = <(String, String)>[
        ('Food temperature at the end of the box time (average)', '${n('T_target_avg_C')}°C'),
        ('Food next to the wall is hotter by', '${n('edge_excess_low_C')} to ${n('edge_excess_high_C')}°C'),
        ('Real microwave power vs. its rating', '${(p['power_factor_low'] * 100).round()} to ${(p['power_factor_high'] * 100).round()}%'),
        ('Steam bag film after ${(p['steam_onset_fraction'] * 100).round()}% of the cook time', '${n('T_boil_C')}°C'),
        ('Food EtOH-eq, lower fat (<${(fc['lean']!.fatMax * 100).round()}%)', '${fc['lean']!.etohLow.round()} to ${fc['lean']!.etohHigh.round()}%'),
        ('Food EtOH-eq, medium fat', '${fc['medium']!.etohLow.round()} to ${fc['medium']!.etohHigh.round()}%'),
        ('Food EtOH-eq, higher fat (≥${(fc['fatty']!.fatMin * 100).round()}%)', '${fc['fatty']!.etohLow.round()} to ${fc['fatty']!.etohHigh.round()}%'),
        ('Partition model error (log10 units)', '± ${p['kpf_resid_sd'].toStringAsFixed(2)}'),
        ('Diffusion: realistic (0) to upper bound (1), center', n('d_weight_central', 1)),
        ('Monte Carlo runs per estimate', n('mc_samples')),
        ('Bands: Low, Medium, High', '<${n('band_low_pct')}%, ${n('band_low_pct')}–${n('band_high_pct')}%, ≥${n('band_high_pct')}%'),
        ('Daily alert in the log', '${n('daily_alert_pct')}% of the limit'),
      ];
      return SheetBody(title: 'How we calculate', children: [
        Well(
          child: TText('% of daily limit = (amount moved into the food you eat × relative potency) ÷ (body weight × daily limit) × 100', style: ZT.small),
        ),
        TText(
          '1. Recipe: the box time is converted to your microwave\'s watts.\n'
          '2. Heat: an energy balance gives the food temperature second by second, and the wall next to the food runs hotter.\n'
          '3. Diffusion: how fast each chemical moves through the plastic at that temperature. ZapWise works between a realistic estimate (Huang et al. 2017) and the regulatory upper bound (Piringer, EU JRC). Antimony in PET trays uses lab-measured values (Haldimann et al. 2013).\n'
          '4. Partition: how much the chemical prefers the food over the plastic, from a regression fitted to 1,881 measurements (Huang and Jolliet 2019), using how fatty the food is.\n'
          '5. Migration: the diffusion equation for a plastic layer touching food (Crank).\n'
          '6. Exposure: the eaten share is compared with the daily limit for your body weight.',
          style: ZT.small,
        ),
        TText('log Kpf = ${k.b0} + ${k.bKow}·logKow ${k.bEtoh}·EtOH ${k.bKowEtoh}·logKow·EtOH + ${k.bInvT.round()}·(1/T − 1/298) + polymer',
            style: ZT.foot),
        Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: ZC.line))),
          child: Column(children: [
            for (final (a, b) in rows)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ZC.line))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: TText(a, style: ZT.small)),
                  const SizedBox(width: 10),
                  TText(b, style: ZT.small.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.right),
                ]),
              ),
          ]),
        ),
        TText('Containers that soften below cooking heat (clear PET, foam, take-out tubs) get a do-not-heat warning instead of a number. Every number above is in the ZapWise database with its source.',
            style: ZT.smallMuted),
      ]);
    });
