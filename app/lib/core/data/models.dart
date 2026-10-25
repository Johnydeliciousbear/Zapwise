// Data classes for the ZapWise reference data (assets/data/*.json).
//
// The JSON is generated from ZapWise_DB.xlsx by db/export_assets.py. Field names here
// follow the JSON keys so the two stay easy to compare.

double? _d(Object? v) => v == null ? null : (v as num).toDouble();
double _dd(Object? v, [double fallback = 0]) => v == null ? fallback : (v as num).toDouble();

class Polymer {
  final String key;
  final String name;
  final double apPrime; // Piringer upper bound
  final double tau;
  final double tMaxValidC;
  final double? density;
  final double huangB; // Huang 2017 QPPR material coefficient
  final double huangTau;
  final String kpfMaterial; // material label in the partition regression

  const Polymer({
    required this.key,
    required this.name,
    required this.apPrime,
    required this.tau,
    required this.tMaxValidC,
    this.density,
    this.huangB = 0,
    this.huangTau = 0,
    this.kpfMaterial = '',
  });

  factory Polymer.fromJson(String key, Map<String, dynamic> j) => Polymer(
        key: key,
        name: j['name'] as String,
        apPrime: _dd(j['ap_prime']),
        tau: _dd(j['tau']),
        tMaxValidC: _dd(j['t_max_valid_c'], 999),
        density: _d(j['density']),
        huangB: _dd(j['huang_b']),
        huangTau: _dd(j['huang_tau']),
        kpfMaterial: (j['kpf_material'] ?? '') as String,
      );
}

/// Huang and Jolliet 2019 partition regression [S76]:
/// log10 Kpf = b0 + bKow x + bEtoh E + bKowEtoh x E + bInvT (1/T - 1/Tref) + material offset,
/// x = log Kow capped at the highest measured value for the food's EtOH-eq band.
class KpfModel {
  final double b0, bKow, bEtoh, bKowEtoh, bInvT;
  final Map<String, double> materialOffsets;
  final List<(double, double, double)> domain; // (etoh low, etoh high, highest log Kow)
  const KpfModel({
    required this.b0,
    required this.bKow,
    required this.bEtoh,
    required this.bKowEtoh,
    required this.bInvT,
    required this.materialOffsets,
    required this.domain,
  });

  factory KpfModel.fromJson(Map<String, dynamic> j) {
    final c = j['coefficients'] as Map<String, dynamic>;
    return KpfModel(
      b0: _dd(c['b0']),
      bKow: _dd(c['b_kow']),
      bEtoh: _dd(c['b_etoh']),
      bKowEtoh: _dd(c['b_kow_etoh']),
      bInvT: _dd(c['b_invt']),
      materialOffsets: {for (final e in (j['material_offsets'] as Map<String, dynamic>).entries) e.key: _dd(e.value)},
      domain: [for (final d in j['domain'] as List) (_dd(d['etoh_low']), _dd(d['etoh_high']), _dd(d['logkow_max']))],
    );
  }

  /// Highest measured log Kow for this EtOH-eq (the last band when beyond all bands).
  double kowCap(double etoh) {
    for (final (lo, hi, cap) in domain) {
      if (lo <= etoh && etoh < hi) return cap;
    }
    return domain.last.$3;
  }
}

/// Constants of the Huang 2017 diffusion QPPR [S78].
class Huang2017 {
  final double intercept, bLogMw, betaInvT;
  const Huang2017({required this.intercept, required this.bLogMw, required this.betaInvT});
  factory Huang2017.fromJson(Map<String, dynamic> j) =>
      Huang2017(intercept: _dd(j['intercept']), bLogMw: _dd(j['b_logmw']), betaInvT: _dd(j['beta_invt']));
}

enum DiffusionModel { piringer, arrhenius }

class Substance {
  final String key;
  final String name;
  final double mw;
  final double? logKow;
  final String group;
  final double rpf;
  final DiffusionModel model;
  final double? d0;
  final double? eaKj;
  final double diffusible;

  const Substance({
    required this.key,
    required this.name,
    required this.mw,
    required this.logKow,
    required this.group,
    required this.rpf,
    required this.model,
    this.d0,
    this.eaKj,
    required this.diffusible,
  });

  /// Organic migrants get a partition coefficient from the regression; antimony (no log Kow) uses K = 1.
  bool get hasKow => logKow != null;

  factory Substance.fromJson(String key, Map<String, dynamic> j) => Substance(
        key: key,
        name: j['name'] as String,
        mw: _dd(j['mw']),
        logKow: _d(j['log_kow']),
        group: j['group'] as String,
        rpf: _dd(j['rpf'], 1),
        model: j['model'] == 'arrhenius' ? DiffusionModel.arrhenius : DiffusionModel.piringer,
        d0: _d(j['d0']),
        eaKj: _d(j['ea_kj']),
        diffusible: _dd(j['diffusible'], 1),
      );
}

class ReferenceGroup {
  final String key;
  final String labelEn;
  final double tdi; // ug per kg body weight per day
  final String agency;
  final int? year;
  final String sources;

  const ReferenceGroup({required this.key, required this.labelEn, required this.tdi, required this.agency, this.year, required this.sources});

  factory ReferenceGroup.fromJson(String key, Map<String, dynamic> j) => ReferenceGroup(
        key: key,
        labelEn: j['label_en'] as String,
        tdi: _dd(j['tdi']),
        agency: j['agency'] as String,
        year: (j['year'] as num?)?.toInt(),
        sources: (j['sources'] ?? '') as String,
      );
}

class ContentRange {
  final double low; // mg/kg of plastic
  final double high;
  const ContentRange(this.low, this.high);
  double get mid => 0.5 * (low + high);
}

/// ok: diffusion model. measured: from measured migration. info: explained, no number.
/// inert: no plastic touches food. noData: unknown plastic (no number). block: do not heat (reason shown).
enum ContainerStatus { ok, measured, info, inert, noData, block }

ContainerStatus _status(String s) => switch (s) {
      'ok' => ContainerStatus.ok,
      'measured' => ContainerStatus.measured,
      'info' => ContainerStatus.info,
      'inert' => ContainerStatus.inert,
      'no_data' => ContainerStatus.noData,
      _ => ContainerStatus.block,
    };

/// Status as the string used in results and stored meal records.
String statusName(ContainerStatus s) => switch (s) {
      ContainerStatus.ok => 'ok',
      ContainerStatus.measured => 'measured',
      ContainerStatus.info => 'info',
      ContainerStatus.inert => 'inert',
      ContainerStatus.noData => 'no_data',
      ContainerStatus.block => 'block',
    };

/// A measured migration value used when a container has status measured.
class MeasuredRecord {
  final String substance;
  final String group;
  final double low;
  final double mid;
  final double high;
  final String unit;
  final String basis; // per_kg_food or per_item
  final String conditions;
  final String sources;
  const MeasuredRecord({required this.substance, required this.group, required this.low, required this.mid, required this.high, required this.unit, required this.basis, required this.conditions, required this.sources});

  factory MeasuredRecord.fromJson(Map<String, dynamic> j) => MeasuredRecord(
        substance: j['substance'] as String,
        group: j['group'] as String,
        low: _dd(j['low']),
        mid: _dd(j['mid']),
        high: _dd(j['high']),
        unit: (j['unit'] ?? '') as String,
        basis: (j['basis'] ?? 'per_kg_food') as String,
        conditions: (j['conditions'] ?? '') as String,
        sources: (j['sources'] ?? '') as String,
      );
}

class ContainerType {
  final String key;
  final String labelEn;
  final ContainerStatus status;
  final String? contentKey;
  final String? polymer;
  final double? density;
  final double? thicknessCm;
  final double? thicknessLow;
  final double? thicknessHigh;
  final double? areaRefCm2;
  final String form;
  final double? maxUseC;
  final String reasonEn;
  final String sources;
  final String contactMode; // wall, or steam for steam bags

  const ContainerType({
    required this.key,
    required this.labelEn,
    required this.status,
    this.contentKey,
    this.polymer,
    this.density,
    this.thicknessCm,
    this.thicknessLow,
    this.thicknessHigh,
    this.areaRefCm2,
    required this.form,
    this.maxUseC,
    required this.reasonEn,
    required this.sources,
    this.contactMode = 'wall',
  });

  factory ContainerType.fromJson(String key, Map<String, dynamic> j) => ContainerType(
        key: key,
        labelEn: j['label_en'] as String,
        status: _status(j['status'] as String),
        contentKey: j['content_key'] as String?,
        polymer: j['polymer'] as String?,
        density: _d(j['density']),
        thicknessCm: _d(j['thickness_cm']),
        thicknessLow: _d(j['thickness_low']),
        thicknessHigh: _d(j['thickness_high']),
        areaRefCm2: _d(j['area_ref_cm2']),
        form: (j['form'] ?? '') as String,
        maxUseC: _d(j['max_use_c']),
        reasonEn: (j['reason_en'] ?? '') as String,
        sources: (j['sources'] ?? '') as String,
        contactMode: (j['contact_mode'] ?? 'wall') as String,
      );
}

class FoodClass {
  final String key;
  final double fatMin;
  final double fatMax;
  final double etohLow; // food ethanol equivalent (% v/v) range for the partition regression
  final double etohHigh;
  final double capLow;
  final double capHigh;

  const FoodClass({required this.key, required this.fatMin, required this.fatMax, required this.etohLow, required this.etohHigh, required this.capLow, required this.capHigh});

  factory FoodClass.fromJson(Map<String, dynamic> j) => FoodClass(
        key: j['key'] as String,
        fatMin: _dd(j['fat_min']),
        fatMax: _dd(j['fat_max']),
        etohLow: _dd(j['etoh_low']),
        etohHigh: _dd(j['etoh_high']),
        capLow: _dd(j['cap_low']),
        capHigh: _dd(j['cap_high']),
      );
}

enum StepKind { cook, cookTable, stand, action, oven }

StepKind _kind(String s) => switch (s) {
      'cook' => StepKind.cook,
      'cook_table' => StepKind.cookTable,
      'stand' => StepKind.stand,
      'oven' => StepKind.oven,
      _ => StepKind.action,
    };

class LabelStep {
  final StepKind kind;
  final String text;
  final double? timeS;
  final double? timeSMax;
  const LabelStep({required this.kind, required this.text, this.timeS, this.timeSMax});

  factory LabelStep.fromJson(Map<String, dynamic> j) =>
      LabelStep(kind: _kind(j['kind'] as String), text: (j['text'] ?? '') as String, timeS: _d(j['time_s']), timeSMax: _d(j['time_s_max']));

  Map<String, dynamic> toJson() => {
        'kind': switch (kind) {
          StepKind.cook => 'cook',
          StepKind.cookTable => 'cook_table',
          StepKind.stand => 'stand',
          StepKind.oven => 'oven',
          StepKind.action => 'action',
        },
        'text': text,
        'time_s': timeS,
        'time_s_max': timeSMax,
      };
}

class WattEntry {
  final double watt;
  final double timeS;
  final double? timeSMax;
  const WattEntry(this.watt, this.timeS, [this.timeSMax]);
  factory WattEntry.fromJson(Map<String, dynamic> j) => WattEntry(_dd(j['watt']), _dd(j['time_s']), _d(j['time_s_max']));
  double get mid => timeSMax == null ? timeS : 0.5 * (timeS + timeSMax!);
}

class Recipe {
  final double refWatt;
  final bool refWattAssumed;
  final List<LabelStep> steps;
  final List<WattEntry> wattTable;
  final String completeness;
  final String doNotMicrowave; // yes, no, unknown
  final bool ovenOnly;
  final double? minWatt;
  final bool noReheatTray;
  final String ovenText;

  const Recipe({
    required this.refWatt,
    required this.refWattAssumed,
    required this.steps,
    required this.wattTable,
    required this.completeness,
    required this.doNotMicrowave,
    required this.ovenOnly,
    this.minWatt,
    this.noReheatTray = false,
    this.ovenText = '',
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        refWatt: _dd(j['ref_watt'], 1100),
        refWattAssumed: (j['ref_watt_assumed'] ?? false) as bool,
        steps: [for (final s in (j['steps'] as List? ?? const [])) LabelStep.fromJson(s as Map<String, dynamic>)],
        wattTable: [for (final s in (j['watt_table'] as List? ?? const [])) WattEntry.fromJson(s as Map<String, dynamic>)],
        completeness: (j['completeness'] ?? 'none') as String,
        doNotMicrowave: (j['do_not_microwave'] ?? 'unknown') as String,
        ovenOnly: (j['oven_only'] ?? false) as bool,
        minWatt: _d(j['min_watt']),
        noReheatTray: (j['no_reheat_tray'] ?? false) as bool,
        ovenText: (j['oven_text'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'ref_watt': refWatt,
        'ref_watt_assumed': refWattAssumed,
        'steps': [for (final s in steps) s.toJson()],
        'watt_table': [for (final w in wattTable) {'watt': w.watt, 'time_s': w.timeS, 'time_s_max': w.timeSMax}],
        'completeness': completeness,
        'do_not_microwave': doNotMicrowave,
        'oven_only': ovenOnly,
        'min_watt': minWatt,
        'no_reheat_tray': noReheatTray,
        'oven_text': ovenText,
      };
}

enum Storage { frozen, chilled, shelf }

class Product {
  final String id;
  final String brand;
  final String name;
  final String? upc;
  final String category;
  final double? netG;
  final double? servings;
  final double foodMassG;
  final double? fatFraction;
  final String fatClass;
  final bool fatKnown;
  final Storage storage;
  final String containerKey;
  final String containerConfidence; // label, photo (resin code read on the tray), inferred, unknown, user
  final Recipe recipe;
  final List<String> searchTokens;
  final List<String> flags;

  const Product({
    required this.id,
    required this.brand,
    required this.name,
    this.upc,
    required this.category,
    this.netG,
    this.servings,
    required this.foodMassG,
    this.fatFraction,
    required this.fatClass,
    required this.fatKnown,
    required this.storage,
    required this.containerKey,
    required this.containerConfidence,
    required this.recipe,
    required this.searchTokens,
    this.flags = const [],
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        brand: j['brand'] as String,
        name: j['name'] as String,
        upc: j['upc'] as String?,
        category: j['category'] as String,
        netG: _d(j['net_g']),
        servings: _d(j['servings']),
        foodMassG: _dd(j['food_mass_g'], 300),
        fatFraction: _d(j['fat_fraction']),
        fatClass: (j['fat_class'] ?? 'medium') as String,
        fatKnown: (j['fat_known'] ?? true) as bool, // same default as the Python engine
        storage: switch (j['storage']) { 'frozen' => Storage.frozen, 'chilled' => Storage.chilled, _ => Storage.shelf },
        containerKey: (j['container_key'] ?? 'pp_container') as String,
        containerConfidence: (j['container_confidence'] ?? 'unknown') as String,
        recipe: Recipe.fromJson(j['recipe'] as Map<String, dynamic>),
        searchTokens: [for (final t in (j['search_tokens'] as List? ?? const [])) t as String],
        flags: [for (final t in (j['flags'] as List? ?? const [])) t as String],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'name': name,
        'upc': upc,
        'category': category,
        'net_g': netG,
        'servings': servings,
        'food_mass_g': foodMassG,
        'fat_fraction': fatFraction,
        'fat_class': fatClass,
        'fat_known': fatKnown,
        'storage': storage.name,
        'container_key': containerKey,
        'container_confidence': containerConfidence,
        'recipe': recipe.toJson(),
        'search_tokens': searchTokens,
        'flags': flags,
      };

  String get displayName => '$brand $name';
}

/// Everything in zapwise_params.json.
class ZapParams {
  final Map<String, Polymer> polymers;
  final Map<String, Substance> substances;
  final Map<String, ReferenceGroup> groups;
  final Map<String, Map<String, ContentRange>> contents; // material -> substance -> range
  final Map<String, ContainerType> containers;
  final Map<String, List<MeasuredRecord>> measured; // container key -> measured values
  final List<FoodClass> foodClasses;
  final Map<String, double> p; // ModelParams sheet
  final Map<String, double> bodyWeights;
  final Map<String, Map<String, String>> sources;
  final String version;
  final KpfModel kpf;
  final Huang2017 huang2017;

  const ZapParams({
    required this.polymers,
    required this.substances,
    required this.groups,
    required this.contents,
    required this.containers,
    this.measured = const {},
    required this.foodClasses,
    required this.p,
    required this.bodyWeights,
    required this.sources,
    required this.version,
    required this.kpf,
    required this.huang2017,
  });

  factory ZapParams.fromJson(Map<String, dynamic> j) {
    final contents = <String, Map<String, ContentRange>>{};
    (j['contents'] as Map<String, dynamic>).forEach((mat, m) {
      contents[mat] = {
        for (final e in (m as Map<String, dynamic>).entries)
          e.key: ContentRange(_dd((e.value as Map)['low']), _dd((e.value as Map)['high'])),
      };
    });
    return ZapParams(
      polymers: {for (final e in (j['polymers'] as Map<String, dynamic>).entries) e.key: Polymer.fromJson(e.key, e.value as Map<String, dynamic>)},
      substances: {for (final e in (j['substances'] as Map<String, dynamic>).entries) e.key: Substance.fromJson(e.key, e.value as Map<String, dynamic>)},
      groups: {for (final e in (j['groups'] as Map<String, dynamic>).entries) e.key: ReferenceGroup.fromJson(e.key, e.value as Map<String, dynamic>)},
      contents: contents,
      containers: {for (final e in (j['containers'] as Map<String, dynamic>).entries) e.key: ContainerType.fromJson(e.key, e.value as Map<String, dynamic>)},
      measured: {
        for (final e in ((j['measured'] ?? const <String, dynamic>{}) as Map<String, dynamic>).entries)
          e.key: [for (final r in e.value as List) MeasuredRecord.fromJson(r as Map<String, dynamic>)],
      },
      foodClasses: [for (final f in j['food_classes'] as List) FoodClass.fromJson(f as Map<String, dynamic>)],
      p: {for (final e in (j['params'] as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble()},
      bodyWeights: {for (final e in (j['body_weights'] as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble()},
      sources: {
        for (final e in (j['sources'] as Map<String, dynamic>).entries)
          e.key: {'citation': (e.value as Map)['citation'] as String, 'url': (e.value as Map)['url'] as String},
      },
      version: ((j['meta'] as Map?)?['version'] ?? '0') as String,
      kpf: KpfModel.fromJson(j['kpf'] as Map<String, dynamic>),
      huang2017: Huang2017.fromJson(j['huang2017'] as Map<String, dynamic>),
    );
  }

  double operator [](String key) {
    final v = p[key];
    if (v == null) throw ArgumentError('missing model parameter $key');
    return v;
  }

  FoodClass foodClass(String key) => foodClasses.firstWhere((f) => f.key == key);
}
