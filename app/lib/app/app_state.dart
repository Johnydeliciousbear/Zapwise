// App-wide state: the core service, the user's kitchen (appliances, shelf), family profiles,
// meals, quests and small settings. Screens read it through AppScope and call its methods;
// every method writes to the phone's database first and then notifies listeners.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/core.dart';

class AppState extends ChangeNotifier {
  final ZapWiseService service;
  final SharedPreferences prefs;

  AppState._(this.service, this.prefs);

  List<Profile> profiles = [];
  List<Appliance> appliances = [];
  List<ShelfItem> shelf = [];
  List<MealRecord> meals = []; // all profiles, oldest first
  List<QuestState> quests = [];
  Set<String> decor = {};
  Set<String> claimed = {};
  List<Registration> registrations = [];

  static const _kActive = 'active_profile';
  static const _kProfileChosen = 'profile_chosen';
  static const _kTutorial = 'tutorial_done';
  static const _kSeen = 'seen_hotspots';
  static const _kTips = 'tips_seen';
  static const _kSample = 'sample_meal_ids';

  static Future<AppState> start() async {
    final service = await ZapWiseService.start();
    final prefs = await SharedPreferences.getInstance();
    final s = AppState._(service, prefs);
    await s._ensureDefaultProfile();
    await s.refresh();
    return s;
  }

  ZapParams get params => service.assets.params;
  ZapAssets get assets => service.assets;

  // ---------------------------------------------------------------- settings
  bool get tutorialDone => prefs.getBool(_kTutorial) ?? false;
  Future<void> setTutorialDone() async {
    await prefs.setBool(_kTutorial, true);
    notifyListeners();
  }

  Future<void> replayTutorial() async {
    await prefs.setBool(_kTutorial, false);
    notifyListeners();
  }

  Set<String> get seenHotspots => (prefs.getStringList(_kSeen) ?? const []).toSet();
  Future<void> markSeen(String hotspot) async {
    if (seenHotspots.contains(hotspot)) return;
    await prefs.setStringList(_kSeen, [...seenHotspots, hotspot]);
    notifyListeners();
  }

  bool tipSeen(String key) => (prefs.getStringList(_kTips) ?? const []).contains(key);
  Future<void> dismissTip(String key) async {
    await prefs.setStringList(_kTips, {...(prefs.getStringList(_kTips) ?? const <String>[]), key}.toList());
    notifyListeners();
  }

  // ---------------------------------------------------------------- profiles
  Future<void> _ensureDefaultProfile() async {
    if ((await service.db.profiles()).isEmpty) {
      await service.db.saveProfile(Profile(id: 'me', name: 'You', bodyWeightKg: params.bodyWeights['adult'] ?? 70, group: 'adult', isDefault: true));
    }
  }

  Profile get activeProfile {
    final id = prefs.getString(_kActive) ?? 'me';
    return profiles.firstWhere((p) => p.id == id, orElse: () => profiles.firstWhere((p) => p.isDefault, orElse: () => profiles.first));
  }

  /// True once the user said who is eating (until then an adult at 70 kg is assumed).
  bool get profileChosen => prefs.getBool(_kProfileChosen) ?? false;

  Future<void> setActive(String id) async {
    await prefs.setString(_kActive, id);
    notifyListeners();
  }

  /// Sets the age group of the default profile ('Who is eating this?' on the result screen).
  Future<void> chooseOwnGroup(String group) async {
    final me = profiles.firstWhere((p) => p.isDefault, orElse: () => profiles.first);
    await service.db.saveProfile(Profile(id: me.id, name: me.name, bodyWeightKg: params.bodyWeights[group] ?? me.bodyWeightKg, group: group, isDefault: me.isDefault));
    await prefs.setBool(_kProfileChosen, true);
    await refresh();
  }

  Future<void> saveProfile({String? id, required String name, required String group, double? weightKg}) async {
    final pid = id ?? 'p${DateTime.now().millisecondsSinceEpoch}';
    final isDefault = profiles.any((p) => p.id == pid && p.isDefault);
    await service.db.saveProfile(Profile(id: pid, name: name, bodyWeightKg: weightKg ?? params.bodyWeights[group] ?? 70, group: group, isDefault: isDefault));
    if (isDefault) await prefs.setBool(_kProfileChosen, true);
    await refresh();
  }

  Future<void> deleteProfile(String id) async {
    final p = profiles.firstWhere((x) => x.id == id);
    if (p.isDefault) return;
    await service.db.deleteProfile(id);
    if (prefs.getString(_kActive) == id) await prefs.remove(_kActive);
    await refresh();
  }

  // ---------------------------------------------------------------- kitchen
  Appliance? get microwave {
    for (final a in appliances) {
      if (a.kind == ApplianceKind.microwave) return a;
    }
    return null;
  }

  /// The wattage used for recipes: the user's microwave, or the label default until it is set.
  double get watt => microwave?.watt ?? params['default_ref_watt'];
  bool get wattSet => microwave?.watt != null;

  Future<void> setMicrowave({double? rated, double? measured}) async {
    final old = microwave;
    await service.db.saveAppliance(Appliance(
      id: old?.id ?? 'microwave',
      kind: ApplianceKind.microwave,
      name: 'Microwave',
      ratedWatt: rated ?? old?.ratedWatt,
      measuredWatt: measured ?? old?.measuredWatt,
    ));
    await refresh();
  }

  bool hasAppliance(ApplianceKind k) => appliances.any((a) => a.kind == k);

  Future<void> toggleAppliance(ApplianceKind kind, String name) async {
    final existing = appliances.where((a) => a.kind == kind).toList();
    if (existing.isNotEmpty) {
      for (final a in existing) {
        await service.db.deleteAppliance(a.id);
      }
    } else {
      await service.db.saveAppliance(Appliance(id: '${kind.name}-${DateTime.now().millisecondsSinceEpoch}', kind: kind, name: name));
    }
    await refresh();
  }

  Future<ShelfItem> addToShelf(String containerKey, {String? name, String? photoPath}) async {
    final c = params.containers[containerKey]!;
    final item = ShelfItem(id: 's${DateTime.now().millisecondsSinceEpoch}', containerKey: containerKey, name: name ?? c.labelEn, photoPath: photoPath, createdAt: DateTime.now());
    await service.db.saveShelfItem(item);
    await refresh();
    return item;
  }

  Future<void> removeFromShelf(String id) async {
    await service.db.deleteShelfItem(id);
    await refresh();
  }

  // ---------------------------------------------------------------- meals and log
  Future<MealRecord> saveMeal(Scenario sc, EvalResult result) async {
    final rec = await service.logMeal(sc: sc, result: result, profileId: activeProfile.id);
    await refresh();
    return rec;
  }

  Future<void> deleteMeal(int id) async {
    await service.db.deleteMeal(id);
    await refresh();
  }

  Set<int> get sampleMealIds => {for (final s in prefs.getStringList(_kSample) ?? const <String>[]) int.parse(s)};

  /// Meals shown in the log for a profile, newest first. Sample meals belong to the default profile.
  List<MealRecord> mealsFor(Profile p) {
    final out = meals.where((m) => m.profileId == p.id || (p.isDefault && m.profileId == 'sample:${p.id}')).toList();
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  /// A week of example meals with real estimates, for demos. They are tagged as samples,
  /// never count toward quests, and can be removed in Me.
  Future<void> addSampleWeek() async {
    final me = profiles.firstWhere((p) => p.isDefault, orElse: () => profiles.first);
    final plan = <(String, String?)>[('zw-001', null), ('zw-007', null), ('zw-015', null), ('zw-001', null), ('zw-020', 'ceramic'), ('zw-003', null)];
    final today = DateTime.now();
    final ids = <String>[...(prefs.getStringList(_kSample) ?? const <String>[])];
    for (var i = 0; i < plan.length; i++) {
      final (pid, ck) = plan[i];
      final product = assets.byId[pid];
      if (product == null) continue;
      final sc = Scenario(product: product, containerKey: ck, watt: watt, bodyWeightKg: me.bodyWeightKg);
      final r = service.evaluate(sc, mc: false);
      final c = params.containers[r.containerKey]!;
      final at = DateTime(today.year, today.month, today.day - (6 - i), 12, 30);
      final id = await service.db.addMeal(MealRecord(
        profileId: 'sample:${me.id}',
        productId: pid,
        containerKey: r.containerKey,
        status: r.status,
        containerStatus: statusName(c.status),
        watt: watt,
        followedLabel: ck == null,
        groupsPct: r.groups,
        at: at,
      ));
      ids.add('$id');
    }
    await prefs.setStringList(_kSample, ids);
    await refresh();
  }

  Future<void> removeSampleMeals() async {
    for (final id in sampleMealIds) {
      await service.db.deleteMeal(id);
    }
    await prefs.remove(_kSample);
    await refresh();
  }

  // ---------------------------------------------------------------- quests
  int get stars => totalStars(claimed);

  /// First quest still to do (unlocked, not claimed), for the banner.
  QuestState? get currentQuest {
    for (final q in quests) {
      if (!q.locked && !q.claimed) return q;
    }
    return null;
  }

  /// Claims every finished quest and returns them, so the screen can celebrate.
  Future<List<QuestState>> claimFinishedQuests() async {
    final done = <QuestState>[];
    for (var round = 0; round < 3; round++) {
      // claiming the starter quest unlocks the others, so look again
      final qs = await service.quests();
      final ready = qs.where((q) => q.claimable).toList();
      if (ready.isEmpty) break;
      for (final q in ready) {
        await service.claim(q);
        done.add(q);
      }
    }
    if (done.isNotEmpty) await refresh();
    return done;
  }

  // ---------------------------------------------------------------- products
  Future<Product> registerProduct({
    required String brand,
    required String name,
    required Recipe recipe,
    required String containerKey,
    required double netG,
    double addedWaterG = 0,
    double? fatGPerPackage,
    Storage storage = Storage.frozen,
    String? barcode,
    List<String> photoPaths = const [],
    String ocrText = '',
    VisionOutput? vision,
    bool shareWithOff = false,
  }) async {
    final p = await service.registerProduct(
      brand: brand,
      name: name,
      recipe: recipe,
      containerKey: containerKey,
      netG: netG,
      addedWaterG: addedWaterG,
      fatGPerPackage: fatGPerPackage,
      storage: storage,
      barcode: barcode,
      photoPaths: photoPaths,
      ocrText: ocrText,
      vision: vision,
      shareWithOff: shareWithOff,
    );
    await refresh();
    return p;
  }

  // ---------------------------------------------------------------- reset and reload
  Future<void> resetEverything() async {
    await service.db.clearAll();
    final lang = prefs.getString('app_language'); // a reset keeps the language the person chose
    await prefs.clear();
    if (lang != null) await prefs.setString('app_language', lang);
    await _ensureDefaultProfile();
    await refresh();
  }

  Future<void> refresh() async {
    final db = service.db;
    profiles = await db.profiles();
    profiles.sort((a, b) => a.isDefault == b.isDefault ? a.name.compareTo(b.name) : (a.isDefault ? -1 : 1));
    appliances = await db.appliances();
    shelf = await db.shelf();
    meals = await db.meals();
    claimed = await db.claimedQuests();
    decor = await db.decor();
    quests = await service.quests();
    registrations = await db.registrations();
    notifyListeners();
  }
}
