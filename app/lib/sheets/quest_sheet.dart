// Kitchen quests (the note on the fridge) and the celebration when one is done.
// Progress comes from the stored kitchen and log (quest_engine.dart); finished quests are
// claimed automatically and their stars and decorations are added.
import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/core.dart';
import '../ui/sheets.dart';
import '../ui/soft.dart';
import '../ui/sprites.dart';
import '../ui/theme.dart';
import 'package:zapwise/ui/i18n.dart';

const Map<String, String> kDecorNames = {'wall_clock': 'a wall clock', 'rug': 'a strawberry rug', 'fridge_plant': 'a fridge plant'};

/// Why each quest is worth doing, in one line.
const Map<String, String> kQuestWhy = {
  'starter_kitchen': 'Then every scan fits your kitchen.',
  'boil_test': 'Older microwaves can run weaker than their label says.',
  'plate_it': 'No plastic in the heat means almost 0%.',
  'by_the_label': 'Extra minutes can double what gets into food.',
};

/// What each quest asks, in steps the user can tick off.
List<(bool, String)> questTasks(QuestState q, AppScopeData d) => switch (q.def.id) {
      'starter_kitchen' => [
          (d.wattSet, 'Set your microwave\'s watts'),
          (d.shelfCount > 0, 'Add a container to your shelf'),
          (d.mealCount > 0, 'Save your first meal'),
        ],
      'boil_test' => [(q.progress >= 1, 'Tap Zappy and do the boil test')],
      'plate_it' => [(q.progress >= q.def.target, 'Heat on a plate, in glass or in a pot, then save')],
      'by_the_label' => [(q.progress >= q.def.target, 'Heat for the box time, then save')],
      _ => const [],
    };

class AppScopeData {
  final bool wattSet;
  final int shelfCount;
  final int mealCount;
  const AppScopeData(this.wattSet, this.shelfCount, this.mealCount);
}

Future<void> showQuestSheet(BuildContext context) => showZapSheet<void>(context, (ctx) {
      final s = AppScope.of(ctx);
      final d = AppScopeData(s.wattSet, s.shelf.length, s.meals.where((m) => !m.profileId.startsWith('sample:')).length);
      final current = s.currentQuest;
      return SheetBody(title: current?.def.period == QuestPeriod.weekly ? 'This week\'s quests' : 'Your quests', children: [
        for (final q in s.quests)
          Opacity(
            opacity: q.locked ? 0.5 : 1,
            child: Container(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ZC.line))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  ZIcon(q.claimed ? 'check' : (q.locked ? 'quest' : 'star'), size: 24),
                  const SizedBox(width: 10),
                  Expanded(child: TText(q.def.titleEn, style: ZT.h3)),
                  // a locked quest shows no progress yet, so it never looks done before it opens
                  if (!q.locked) Text('${q.progress}/${q.def.target}', style: ZT.h3.copyWith(color: ZC.cocoa2)),
                ]),
                if (kQuestWhy[q.def.id] != null) Padding(padding: const EdgeInsets.only(top: 2), child: TText(kQuestWhy[q.def.id]!, style: ZT.smallMuted)),
                if (!q.locked) ...[
                  const SizedBox(height: 8),
                  Track(q.progress / q.def.target),
                  const SizedBox(height: 4),
                  for (final (done, t) in questTasks(q, d))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ZIcon(done ? 'check' : 'quest', size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: TText(t, style: done ? ZT.smallMuted : ZT.small)),
                      ]),
                    ),
                ],
                const SizedBox(height: 6),
                TText(
                  q.claimed
                      ? 'Done${q.def.period == QuestPeriod.weekly ? ' this week' : ''}. +${q.def.stars} stars${q.def.decor != null ? ' and ${kDecorNames[q.def.decor] ?? q.def.decor}' : ''}.'
                      : q.locked
                          ? 'Unlocks after your first quest.'
                          : 'Reward: ${q.def.stars} stars${q.def.decor != null ? ' and ${kDecorNames[q.def.decor] ?? q.def.decor} for your kitchen' : ''}.',
                  style: ZT.smallMuted,
                ),
              ]),
            ),
          ),
        TText('Quests count how you heat, not how often.', style: ZT.smallMuted),
        Row(children: [
          const ZIcon('star'),
          const SizedBox(width: 8),
          TText('${s.stars} stars', style: ZT.h3),
          if (s.decor.isNotEmpty) Expanded(child: TText('  Unlocked: ${s.decor.map((x) => kDecorNames[x] ?? x).join(', ')}', style: ZT.smallMuted)),
        ]),
      ]);
    });

/// Claims finished quests and shows one celebration for each.
Future<void> celebrateFinished(BuildContext context) async {
  final s = AppScope.read(context);
  final done = await s.claimFinishedQuests();
  for (final q in done) {
    if (!context.mounted) return;
    await showZapSheet<void>(context, (ctx) => _Celebrate(q: q));
  }
}

class _Celebrate extends StatelessWidget {
  final QuestState q;
  const _Celebrate({required this.q});

  @override
  Widget build(BuildContext context) {
    final decor = q.def.decor == null ? '' : ' You unlocked ${kDecorNames[q.def.decor] ?? q.def.decor} for your kitchen.';
    final next = q.def.id == 'starter_kitchen' ? ' Your weekly quests are ready.' : '';
    return SheetBody(showClose: false, title: q.def.id == 'starter_kitchen' ? 'Kitchen set up' : 'Quest complete', children: [
      const Center(child: Zappy(Mood.celebrate, scale: 4)),
      TText('+${q.def.stars} stars.$decor$next', style: ZT.body, textAlign: TextAlign.center),
      PixelButton(label: 'See my kitchen', onPressed: () => Navigator.of(context).pop()),
    ]);
  }
}
