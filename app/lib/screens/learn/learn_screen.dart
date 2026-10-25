// Learn tab: short explainers behind the numbers, and every source the app uses.
// Numbers quoted here come from the app's own model (engine_py prints them) or the database.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../sheets/calc_sheet.dart';
import '../../ui/sheets.dart';
import '../../ui/soft.dart';
import '../../ui/sprites.dart';
import '../../ui/theme.dart';
import '../shell.dart';
import 'package:zapwise/ui/i18n.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  bool _sources = false;

  // reading sections split by lines, no cards
  Widget _card(String icon, String title, List<String> paragraphs) => LineSection(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [ZIcon(icon), const SizedBox(width: 10), Expanded(child: TText(title, style: ZT.h2.copyWith(fontSize: 17)))]),
          const SizedBox(height: 6),
          for (var i = 0; i < paragraphs.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 8), child: TText(paragraphs[i], style: ZT.body)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).params;
    final pht = p.groups['phthalate_dehp_eq'];
    final sb = p.groups['antimony'];
    final sources = p.sources.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return ListView(
      padding: EdgeInsets.only(bottom: tabBottomPadding(context)),
      children: [
        const TabHeader(title: 'Learn'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: gapped([
            // written for a 6th-grade reading level; the model details live in "How we calculate"
            _card('timer', 'Heat it all the way', [
              'Frozen meals can carry germs like Salmonella, especially raw or breaded chicken. If the middle does not get hot enough, the germs survive.',
              'ZapWise changes the box time to fit your microwave so the meal heats all the way. The middle should reach 165°F (74°C).',
            ]),
            _card('flame', 'Why heat matters', [
              'Chemicals move out of plastic by diffusion, which speeds up fast as things get hotter. In ZapWise\'s model, DEHP moves through polypropylene about 20 times faster at 212°F (100°C) than at 158°F (70°C). In the same few minutes, 4 to 5 times more can leave the plastic.',
              'Food touching the container wall gets hotter than the middle, and the corners of square trays heat fastest.',
            ]),
            _card('plate', 'Why fat matters', [
              'Phthalates dissolve much better in fat than in water. Based on 1,881 lab measurements, DEHP at 212°F (100°C) moves about 3,000 times more readily into a high-fat meal than into a watery one.',
              'That\'s why ZapWise checks how fatty a meal is (from the nutrition label), not just how long it heats.',
            ]),
            _card('alert', 'Phthalates', [
              'DEHP, DBP, BBP and DINP are used to make plastic soft. EFSA set a combined daily limit of ${pht?.tdi.round() ?? 50} µg per kg of body weight, counted as DEHP.',
              'Limits scale with body weight, so a 30 kg (66 lb) child hits the same share with less than half of what a 70 kg (154 lb) adult eats.',
            ]),
            _card('container', 'Antimony in black trays', [
              'Black oven-safe trays are usually CPET, a type of PET made with an antimony catalyst. The WHO daily limit is ${sb?.tdi.round() ?? 6} µg per kg of body weight.',
              'For antimony, ZapWise uses values measured on a real CPET tray, because the general formula is built for organic chemicals.',
            ]),
            _card('info', 'Lead in paper cups', [
              'Paper cups and bowls, like the ones for instant noodles, are lined with a thin plastic. A lab study filled 20 of these cups with near-boiling water for 15 minutes and found small amounts of lead in the water.',
              'For lead, ZapWise compares with a reference point from Europe\'s food safety agency, not a safe limit. Less lead is always better. Making the noodles in a pot or a bowl skips the cup.',
            ]),
            _card('info', 'BPA and microplastics', [
              'In 2023, EFSA cut its BPA limit to 0.2 ng per kg of body weight per day. The US FDA hasn\'t changed its view. BPA comes from polycarbonate and epoxy coatings, not the PET and PP trays ZapWise covers.',
              'There\'s no agreed daily limit for microplastics yet, so ZapWise doesn\'t give them a percentage.',
            ]),
            LineSection(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const ZIcon('check'), const SizedBox(width: 10), Expanded(child: TText('What ZapWise counts', style: ZT.h2.copyWith(fontSize: 17)))]),
                const SizedBox(height: 6),
                TText('Only what comes out of the container while your food heats and while you eat from it. Anything that got into the food at the factory isn\'t counted. Every result is an estimate, not a medical test.',
                    style: ZT.body),
                ZLink('How we calculate', onTap: () => showCalcSheet(context)),
              ]),
            ),
            Fold(
              title: 'All sources (${sources.length})',
              icon: 'learn',
              open: _sources,
              onToggle: () => setState(() => _sources = !_sources),
              children: [
                for (final e in sources)
                  GestureDetector(
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: e.value['url'] ?? ''));
                      toast(context, 'Link copied');
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TText('[${e.key}] ${e.value['citation']}', style: ZT.smallMuted.copyWith(fontSize: 12.5)),
                    ),
                  ),
                Padding(padding: const EdgeInsets.only(top: 8), child: TText('Press and hold a source to copy its link.', style: ZT.foot)),
              ],
            ),
            _card('heart', 'About ZapWise', [
              'Made by Woosung Choi, a California high school student, for the Congressional App Challenge. The kitchen, Zappy and every icon are original pixel art. The science, data and code were built with help from an AI assistant, and every number traces back to a source in the ZapWise database.',
            ]),
          ])),
        ),
      ],
    );
  }
}
