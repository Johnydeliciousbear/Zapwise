// Kitchen tab: quest banner, pixel kitchen, and the one pixel button, "Scan before you heat".
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/core.dart';
import '../../sheets/appliance_sheets.dart';
import '../../sheets/microwave_sheet.dart';
import '../../sheets/quest_sheet.dart';
import '../../sheets/shelf_sheets.dart';
import '../../ui/soft.dart';
import '../../ui/sprites.dart';
import '../../ui/theme.dart';
import '../flows.dart';
import '../shell.dart';
import 'coach_overlay.dart';
import 'kitchen_scene.dart';
import 'package:zapwise/ui/i18n.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final keys = KitchenKeys();
  final bannerKey = GlobalKey(debugLabel: 'banner');
  final ctaKey = GlobalKey(debugLabel: 'cta');
  final stackKey = GlobalKey(debugLabel: 'homeStack');

  Future<void> _open(String hotspot, Future<void> Function() action) async {
    final s = AppScope.read(context);
    await s.markSeen(hotspot);
    await action();
    if (mounted) await celebrateFinished(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final q = s.currentQuest;
    final lastMeal = s.meals.isEmpty ? null : s.meals.last.at;
    final sleepy = lastMeal != null && DateTime.now().difference(lastMeal).inDays >= 3;
    return Stack(key: stackKey, children: [
      // no scrolling: the kitchen takes the room that is left, so "Scan before you heat" is always on screen
      LayoutBuilder(builder: (context, box) {
        final column = Padding(
        padding: EdgeInsets.only(bottom: tabBottomPadding(context)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(children: [
              const PixelImage('brand/wordmark', scale: 2, semanticLabel: 'ZapWise'),
              const Spacer(),
              StarPill(stars: s.stars, onPressed: () => _open('fridge', () => showQuestSheet(context))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _QuestBanner(key: bannerKey, quest: q, onTap: () => showQuestSheet(context)),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: LayoutBuilder(builder: (context, room) {
              // the kitchen sits right under the banner; the scan button gets its own band between the
              // floor and the tab bar, centred in whatever height is left
              const band = 96.0; // button, its drop shadow and 16 px above and below
              var scale = room.maxWidth / kSceneW;
              final byHeight = (room.maxHeight - band) / kSceneH;
              if (byHeight < scale) scale = byHeight;
              if (scale >= 2) scale = scale.floorToDouble();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  height: kSceneH * scale,
                  child: KitchenScene(
            keys: keys,
            shelf: s.shelf,
            counter: [for (final k in const [ApplianceKind.airFryer, ApplianceKind.oven, ApplianceKind.kettle]) if (s.hasAppliance(k)) k],
            rewardScene: s.decor.contains('rug') || s.decor.contains('fridge_plant'),
            watt: s.microwave?.watt,
            seen: s.seenHotspots,
            mood: sleepy ? Mood.sleepy : Mood.neutral,
            questTag: q == null ? 'All done' : 'Quest ${q.progress}/${q.def.target}',
            onZappy: () => _open('zappy', () => showMicrowaveSheet(context)),
            onShelf: () => _open('shelf', () => showShelfSheet(context)),
            onFridge: () => _open('fridge', () => showQuestSheet(context)),
            onStove: () => _open('stove', () => showStoveSheet(context)),
            onSlot: () => _open('slot', () => showAddApplianceSheet(context)),
            onAppliance: (k) => _open('slot', () => showCounterApplianceSheet(context, k)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PixelButton(key: ctaKey, label: 'Scan before you heat', icon: 'camera', onPressed: () => startScan(context)),
                    ),
                  ),
                ),
              ]);
            }),
          ),
        ]),
        );
        // very short screens or very large text: fall back to scrolling instead of squeezing the kitchen
        const minHeight = 520.0;
        return box.maxHeight >= minHeight ? column : SingleChildScrollView(child: SizedBox(height: minHeight, child: column));
      }),
      if (!s.tutorialDone)
        Positioned.fill(
          child: CoachOverlay(
            stackKey: stackKey,
            steps: [
              const CoachStep(null, 'Hi, I\'m Zappy! Hot plastic trays can let chemicals seep into food. I\'ll help you heat meals right and keep that low.'),
              CoachStep(keys.zappy, 'Tap me to set my watts. They\'re on a label inside the door. Then every box time fits your microwave.'),
              CoachStep(keys.shelf, 'This shelf holds your dishes. Glass and ceramic add no plastic at all.'),
              CoachStep(ctaKey, 'Before you heat a boxed meal, scan the front. I\'ll tell you how long to heat it and what to heat it in.'),
              CoachStep(bannerKey, 'Each week I pin one easy habit here, like using a plate. Small swaps make the biggest difference.'),
            ],
            onDone: () => AppScope.read(context).setTutorialDone(),
          ),
        ),
    ]);
  }
}

class _QuestBanner extends StatelessWidget {
  final QuestState? quest;
  final VoidCallback onTap;
  const _QuestBanner({super.key, required this.quest, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final q = quest;
    final title = q == null ? 'All done! New quests on Monday.' : q.def.titleEn;
    final progress = q == null ? 1.0 : q.progress / q.def.target;
    return Semantics(
      button: true,
      label: 'Quest: $title, ${q?.progress ?? 1} of ${q?.def.target ?? 1}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Raised(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Well(radius: 12, small: true, padding: EdgeInsets.zero, child: Center(child: ZIcon(q?.def.id == 'starter_kitchen' ? 'quest' : 'star'))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TText(title, style: ZT.h3),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: Track(progress)),
                  const SizedBox(width: 10),
                  TText(q == null ? '' : '${q.progress}/${q.def.target}', style: ZT.h3.copyWith(color: ZC.cocoa2, fontSize: 15)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
