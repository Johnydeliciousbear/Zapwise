// Pixel art assets (assets/ui). Sprites are stored at 1x and enlarged with nearest-neighbour
// sampling (FilterQuality.none), so edges stay sharp. Use whole-number scales where possible.
import 'package:flutter/widgets.dart';

import '../core/data/models.dart';
import 'package:zapwise/ui/i18n.dart';

const Map<String, (int, int)> kSpriteSize = {
  'brand/app_icon': (128, 128),
  'brand/wordmark': (71, 21),
  'icons/alert': (16, 16),
  'icons/camera': (16, 16),
  'icons/check': (16, 16),
  'icons/container': (16, 16),
  'icons/flame': (16, 16),
  'icons/heart': (16, 16),
  'icons/info': (16, 16),
  'icons/kitchen': (16, 16),
  'icons/learn': (16, 16),
  'icons/log': (16, 16),
  'icons/me': (16, 16),
  'icons/plate': (16, 16),
  'icons/quest': (16, 16),
  'icons/star': (16, 16),
  'icons/swap': (16, 16),
  'icons/timer': (16, 16),
  'objects/air_fryer': (22, 25),
  'objects/toaster_oven': (24, 16),
  'objects/kettle': (14, 16),
  'objects/can': (14, 15),
  'objects/cpet_tray': (24, 9),
  'objects/deli_tub': (18, 13),
  'objects/foam_box': (22, 13),
  'objects/fridge': (38, 72),
  'objects/glass_box': (20, 13),
  'objects/lamp': (16, 17),
  'objects/meal_box': (30, 23),
  'objects/melamine_bowl': (22, 12),
  'objects/paper_cup': (14, 16),
  'objects/paper_tray': (24, 9),
  'objects/pet_clam': (20, 11),
  'objects/plant': (13, 20),
  'objects/plates': (26, 10),
  'objects/popcorn_bag': (18, 15),
  'objects/pot': (26, 17),
  'objects/pouch': (16, 19),
  'objects/pp_cup': (12, 15),
  'objects/pp_tray': (24, 10),
  'objects/shelf': (72, 8),
  'objects/sleeve': (20, 12),
  'objects/sparkle': (9, 9),
  'objects/steam_bag': (20, 17),
  'objects/stove': (34, 38),
  'objects/wall_clock': (15, 15),
  'objects/window': (52, 40),
  'scene/kitchen': (196, 216),
  'scene/kitchen_reward': (196, 216),
  'zappy/blink': (42, 32),
  'zappy/body_blink': (30, 22),
  'zappy/body_celebrate': (30, 22),
  'zappy/body_happy': (30, 22),
  'zappy/body_neutral': (30, 22),
  'zappy/body_sleepy': (30, 22),
  'zappy/body_thinking': (30, 22),
  'zappy/body_worried': (30, 22),
  'zappy/celebrate': (42, 32),
  'zappy/happy': (42, 32),
  'zappy/neutral': (42, 32),
  'zappy/sleepy': (42, 32),
  'zappy/thinking': (42, 32),
  'zappy/worried': (42, 32),
};

String spritePath(String name) => 'assets/ui/$name.png';

/// A sprite at [scale] times its pixel size.
class PixelImage extends StatelessWidget {
  final String name; // e.g. 'objects/pot'
  final double scale;
  final String? semanticLabel;
  const PixelImage(this.name, {super.key, this.scale = 2, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final (w, h) = kSpriteSize[name] ?? (16, 16);
    return Image.asset(
      spritePath(name),
      width: w * scale,
      height: h * scale,
      fit: BoxFit.fill, // without this Flutter draws the sprite at its native size and never scales it up
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
      gaplessPlayback: true,
      semanticLabel: semanticLabel == null ? null : tr(context, semanticLabel!),
      excludeFromSemantics: semanticLabel == null,
    );
  }
}

/// A sprite scaled to fit inside a box, keeping its pixels square.
class PixelFit extends StatelessWidget {
  final String name;
  final double maxWidth;
  final double maxHeight;
  const PixelFit(this.name, {super.key, required this.maxWidth, required this.maxHeight});

  @override
  Widget build(BuildContext context) {
    final (w, h) = kSpriteSize[name] ?? (16, 16);
    var s = (maxWidth / w) < (maxHeight / h) ? maxWidth / w : maxHeight / h;
    if (s >= 1) s = s.floorToDouble();
    return SizedBox(width: maxWidth, height: maxHeight, child: Center(child: PixelImage(name, scale: s)));
  }
}

/// 16 x 16 pixel icon, 32 logical pixels by default.
class ZIcon extends StatelessWidget {
  final String name; // camera, plate, container, swap, timer, flame, info, alert, check, star, quest, heart, kitchen, log, learn, me
  final double size;
  const ZIcon(this.name, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) => PixelImage('icons/$name', scale: size / 16);
}

enum Mood { neutral, happy, thinking, worried, celebrate, sleepy, blink }

/// Zappy's face (42 x 32) for result and message cards.
class Zappy extends StatelessWidget {
  final Mood mood;
  final double scale;
  const Zappy(this.mood, {super.key, this.scale = 2});

  @override
  Widget build(BuildContext context) => PixelImage('zappy/${mood.name}', scale: scale, semanticLabel: 'Zappy looks ${mood.name}');
}

/// Zappy as the microwave on the counter (30 x 22).
class ZappyBody extends StatelessWidget {
  final Mood mood;
  final double scale;
  const ZappyBody(this.mood, {super.key, this.scale = 2});

  @override
  Widget build(BuildContext context) => PixelImage('zappy/body_${mood.name}', scale: scale);
}

/// Sprite for a container type key.
String containerSprite(String key) => switch (key) {
      'cpet_tray' => 'objects/cpet_tray',
      'pp_container' => 'objects/pp_tray',
      'pet_board_tray' => 'objects/paper_tray',
      'paperboard_tray' => 'objects/paper_tray',
      'paper_cup' => 'objects/paper_cup',
      'steam_bag' => 'objects/steam_bag',
      'pouch' => 'objects/pouch',
      'takeout_tub' => 'objects/deli_tub',
      'pet_clamshell' => 'objects/pet_clam',
      'eps_foam' => 'objects/foam_box',
      'ps_rigid' => 'objects/foam_box',
      'metal' => 'objects/can',
      'melamine' => 'objects/melamine_bowl',
      'glass' => 'objects/glass_box',
      'ceramic' => 'objects/plates',
      'stove_pot' => 'objects/pot',
      'popcorn_bag' => 'objects/popcorn_bag',
      'susceptor_sleeve' => 'objects/sleeve',
      _ => 'objects/meal_box',
    };

/// Sprite for a product thumbnail: boxed frozen meals show the box, the rest show their container.
String productSprite(Product p) {
  if (p.category == 'frozen_tray' || p.category == 'chilled_tray' || p.category == 'oven_only') return 'objects/meal_box';
  if (p.containerKey == 'pp_container' && p.category == 'cup_bowl') return 'objects/pp_cup';
  return containerSprite(p.containerKey);
}
