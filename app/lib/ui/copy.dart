// Words and number formats shown to the user. Kept in one place so a Spanish version can
// replace them. Writing rules from the design chart: verbs on buttons, never scold,
// always say the number is an estimate and what it counts.
import '../core/data/models.dart';
import '../core/engine/engine.dart';
import 'soft.dart';
import 'sprites.dart';

/// App version shown on the Me tab; keep it the same as pubspec.yaml.
const kAppVersion = '0.5.0';

/// 0.13 -> '0.1%', 3.4 -> '3.4%', 12.2 -> '12%'.
String pctText(double? p) {
  if (p == null) return '–';
  if (p <= 0) return '~0%';
  if (p < 0.1) return '<0.1%';
  if (p < 10) return '${p.toStringAsFixed(1)}%';
  return '${p.round()}%';
}

/// Seconds as m:ss.
String mmss(double seconds) {
  final s = seconds.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Seconds in words: '3 min 30 s', '45 s'.
String timeWords(double seconds) {
  final s = seconds.round();
  final m = s ~/ 60, r = s % 60;
  if (m == 0) return '$r s';
  if (r == 0) return '$m min';
  return '$m min $r s';
}

String grams(double? g) => g == null ? '' : '${g.round()} g';

String ozAndGrams(double? g) => g == null ? '' : '${(g / 28.3495).toStringAsFixed(1)} oz (${g.round()} g)';

BandKind bandKind(Band? b) => switch (b) {
      Band.lower => BandKind.lower,
      Band.middle => BandKind.middle,
      Band.higher => BandKind.higher,
      null => BandKind.none,
    };

BandKind bandOfPct(double? p, ZapParams params) {
  if (p == null) return BandKind.none;
  if (p < params['band_low_pct']) return BandKind.lower;
  if (p < params['band_high_pct']) return BandKind.middle;
  return BandKind.higher;
}

Mood moodFor(BandKind b) => switch (b) {
      BandKind.lower => Mood.happy,
      BandKind.middle => Mood.neutral,
      BandKind.higher => Mood.worried,
      BandKind.none => Mood.neutral,
    };

/// One sentence per engine flag. Flags without an entry are not shown.
const Map<String, String> kFlagText = {
  'below_recipe_energy': 'That\'s less time than the box. Make sure the center is steaming hot (165°F).',
  'above_container_max_use': 'This gets hotter than the container is made for.',
  'outside_model_validity': 'The plastic gets hotter than the model was tested for, so this number is rough.',
  'arrhenius_extrapolated': 'Antimony numbers come from lab tests at 120 to 150°C, a bit hotter than most microwaving.',
  'fat_unknown': 'I don\'t know how much fat is in this, so I guessed a medium amount.',
  'ref_watt_assumed': 'This box doesn\'t list a wattage, so I used 1100 W.',
  'below_label_min_watt': 'The box says your microwave is too weak for this meal.',
  'outside_label_table': 'Your wattage isn\'t on the box\'s chart, so I used the closest one.',
  'measurement_based': 'This number comes from lab tests on similar cups.',
  'oven_step_not_modeled': 'Oven steps aren\'t included.',
};

/// Notes that change what the user does. They stay in view; the rest go under the details fold.
const Set<String> kPracticalFlags = {'below_recipe_energy', 'below_label_min_watt', 'above_container_max_use', 'outside_label_table', 'ref_watt_assumed'};

/// Note texts for a list of flags. The assumed-wattage note is dropped when the user's microwave
/// is within 5% of that wattage, because then it changes nothing.
List<String> flagNotes(List<String> flags, {required double watt, required double refWatt, bool practical = true}) => [
      for (final f in flags)
        if (kFlagText.containsKey(f) &&
            kPracticalFlags.contains(f) == practical &&
            !(f == 'ref_watt_assumed' && (watt - refWatt).abs() <= 0.05 * refWatt))
          kFlagText[f]!,
    ];

/// One plain line at the top of a result: what to do next.
String verdictText(BandKind band, {required bool inert, required String containerKey}) {
  if (inert) return 'No plastic touches your food. You\'re all set.';
  final swap = containerKey == 'paper_cup' ? 'bowl' : 'plate';
  return switch (band) {
    BandKind.lower => 'Low. A $swap makes it almost zero.',
    BandKind.middle => 'A $swap would cut this to almost zero.',
    BandKind.higher => 'That\'s high for one meal. Use a $swap.',
    BandKind.none => 'A $swap makes it almost zero.',
  };
}

/// Words under the big number. Lead has no safe level, so its share is of a reference point.
String limitCaption(String? group, String whose) => group == 'lead' ? 'of the lead\nreference point' : 'of $whose daily\nsafe limit';

/// What the meal is heated in, for the result and log lines.
String methodLabel({required String containerKey, required ZapParams params, bool stove = false, bool oven = false}) {
  if (oven) return 'In the oven';
  if (stove || containerKey == 'stove_pot') return 'On the stove';
  if (containerKey == 'ceramic') return 'Microwaved on a plate';
  if (containerKey == 'glass') return 'Microwaved in a glass dish';
  return 'Microwaved in the ${containerNoun(containerKey)}';
}

/// Short noun for 'from this tray'.
String containerNoun(String key) => switch (key) {
      'cpet_tray' || 'pp_container' || 'pet_board_tray' || 'paperboard_tray' => 'tray',
      'paper_cup' => 'cup',
      'steam_bag' || 'popcorn_bag' => 'bag',
      'susceptor_sleeve' => 'sleeve',
      'pouch' => 'pouch',
      'takeout_tub' => 'tub',
      'pet_clamshell' => 'clamshell',
      'eps_foam' => 'foam box',
      'glass' => 'glass dish',
      'ceramic' => 'plate',
      'stove_pot' => 'pot',
      _ => 'container',
    };

/// Chip text and band for a container on the shelf.
(String, BandKind) shelfChip(ContainerType c) => switch (c.status) {
      ContainerStatus.inert => ('No plastic', BandKind.lower),
      ContainerStatus.ok || ContainerStatus.measured => ('Microwave-safe', BandKind.middle),
      ContainerStatus.block => ('Don\'t heat', BandKind.higher),
      ContainerStatus.info || ContainerStatus.noData => ('Check the label', BandKind.none),
    };

/// Age groups offered for profiles: key in body_weights, label.
const List<(String, String)> kAgeGroups = [
  ('adult', 'Adult'),
  ('teen', 'Teen, 13 to 17'),
  ('child', 'Kid, 8 to 12'),
  ('toddler', 'Toddler, 1 to 3'),
];

String ageLabel(String group) => kAgeGroups.firstWhere((g) => g.$1 == group, orElse: () => (group, group)).$2;

String kgText(double kg) => '${kg.round()} kg (${(kg * 2.20462).round()} lb)';
