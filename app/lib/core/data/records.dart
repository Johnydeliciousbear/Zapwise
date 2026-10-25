// Plain records stored on the phone. No Flutter imports, so the tracking and quest logic
// that reads them can be unit tested on a computer.

class Profile {
  final String id;
  final String name;
  final double bodyWeightKg;
  final String group; // adult, teen, child, toddler (default weight source)
  final bool isDefault;
  const Profile({required this.id, required this.name, required this.bodyWeightKg, required this.group, this.isDefault = false});

  Map<String, Object?> toRow() => {'id': id, 'name': name, 'body_weight_kg': bodyWeightKg, 'grp': group, 'is_default': isDefault ? 1 : 0};
  factory Profile.fromRow(Map<String, Object?> r) => Profile(
      id: r['id'] as String, name: r['name'] as String, bodyWeightKg: (r['body_weight_kg'] as num).toDouble(), group: r['grp'] as String, isDefault: r['is_default'] == 1);
}

enum ApplianceKind { microwave, airFryer, oven, stove, kettle } // new kinds go at the end: rows store the name

class Appliance {
  final String id;
  final ApplianceKind kind;
  final String name;
  final double? ratedWatt; // from the door label
  final double? measuredWatt; // from the water test, if done
  const Appliance({required this.id, required this.kind, required this.name, this.ratedWatt, this.measuredWatt});

  /// Power used in calculations. The rated value is what labels are written for, so it is preferred;
  /// the measured value is kept for the evidence screen and the water-test quest.
  double? get watt => ratedWatt ?? measuredWatt;

  Map<String, Object?> toRow() => {'id': id, 'kind': kind.name, 'name': name, 'rated_watt': ratedWatt, 'measured_watt': measuredWatt};
  factory Appliance.fromRow(Map<String, Object?> r) => Appliance(
      id: r['id'] as String,
      kind: ApplianceKind.values.byName(r['kind'] as String),
      name: r['name'] as String,
      ratedWatt: (r['rated_watt'] as num?)?.toDouble(),
      measuredWatt: (r['measured_watt'] as num?)?.toDouble());
}

/// Absorbed power from a water test: m c dT / t (W). Shown on the evidence screen; it is lower
/// than the rated power because small loads absorb only part of it [S26, S50].
double waterTestWatt({required double waterG, required double startC, required double endC, required double seconds}) =>
    waterG * 4.187 * (endC - startC) / seconds;

/// Rated-power class from the time-to-boil test (1 cup ice-cold water in a 2-cup glass measure on HIGH),
/// as published by Conagra and attributed to USDA [S25]:
/// boils in under 2 min = 1000 W or more, 2.5 min = about 800 W, 3 min = 650-700 W, longer = 300-500 W.
/// Returns the wattage to use when the door label cannot be read.
double wattFromBoilTest(double secondsToBoil) {
  if (secondsToBoil < 120) return 1000;
  if (secondsToBoil <= 150) return 800;
  if (secondsToBoil <= 180) return 700;
  return 500;
}

class ShelfItem {
  final String id;
  final String containerKey;
  final String name;
  final String? photoPath;
  final DateTime createdAt;
  const ShelfItem({required this.id, required this.containerKey, required this.name, this.photoPath, required this.createdAt});

  Map<String, Object?> toRow() => {'id': id, 'container_key': containerKey, 'name': name, 'photo_path': photoPath, 'created_at': createdAt.millisecondsSinceEpoch};
  factory ShelfItem.fromRow(Map<String, Object?> r) => ShelfItem(
      id: r['id'] as String,
      containerKey: r['container_key'] as String,
      name: r['name'] as String,
      photoPath: r['photo_path'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int));
}

/// One heated meal. groupsPct holds % TDI per reference group (empty when no number was shown).
class MealRecord {
  final int? id;
  final String profileId;
  final String productId;
  final String containerKey;
  final String status; // ok, measured, info, inert, no_data, block, ...
  final String containerStatus; // statusName(): ok, measured, info, inert, no_data, block
  final double watt;
  final bool followedLabel; // plan equal to the label plan
  final Map<String, double> groupsPct;
  final DateTime at;

  const MealRecord({
    this.id,
    required this.profileId,
    required this.productId,
    required this.containerKey,
    required this.status,
    required this.containerStatus,
    required this.watt,
    required this.followedLabel,
    required this.groupsPct,
    required this.at,
  });

  /// Calendar day in the phone's local time, used for daily totals.
  String get day => dayKey(at);

  Map<String, Object?> toRow() => {
        'id': id,
        'profile_id': profileId,
        'product_id': productId,
        'container_key': containerKey,
        'status': status,
        'container_status': containerStatus,
        'watt': watt,
        'followed_label': followedLabel ? 1 : 0,
        'groups': groupsPct.entries.map((e) => '${e.key}=${e.value}').join(';'),
        'at': at.millisecondsSinceEpoch,
        'day': day,
      };

  factory MealRecord.fromRow(Map<String, Object?> r) {
    final g = <String, double>{};
    final s = (r['groups'] as String?) ?? '';
    for (final part in s.split(';')) {
      if (part.isEmpty) continue;
      final i = part.indexOf('=');
      g[part.substring(0, i)] = double.parse(part.substring(i + 1));
    }
    return MealRecord(
      id: r['id'] as int?,
      profileId: r['profile_id'] as String,
      productId: r['product_id'] as String,
      containerKey: r['container_key'] as String,
      status: r['status'] as String,
      containerStatus: r['container_status'] as String,
      watt: (r['watt'] as num).toDouble(),
      followedLabel: r['followed_label'] == 1,
      groupsPct: g,
      at: DateTime.fromMillisecondsSinceEpoch(r['at'] as int),
    );
  }
}

String dayKey(DateTime t) {
  final l = t.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

/// A product the user photographed because it was not in the database.
class Registration {
  final int? id;
  final String productJson; // Product.toJson() of the user's entry
  final List<String> photoPaths;
  final String ocrText;
  final String? barcode;
  final String status; // pending, shared
  final DateTime createdAt;
  const Registration({this.id, required this.productJson, required this.photoPaths, required this.ocrText, this.barcode, this.status = 'pending', required this.createdAt});

  Map<String, Object?> toRow() => {
        'id': id,
        'product_json': productJson,
        'photo_paths': photoPaths.join('\n'),
        'ocr_text': ocrText,
        'barcode': barcode,
        'status': status,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
  factory Registration.fromRow(Map<String, Object?> r) => Registration(
        id: r['id'] as int?,
        productJson: r['product_json'] as String,
        photoPaths: ((r['photo_paths'] as String?) ?? '').split('\n').where((s) => s.isNotEmpty).toList(),
        ocrText: (r['ocr_text'] as String?) ?? '',
        barcode: r['barcode'] as String?,
        status: r['status'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      );
}
