// One entry point for the UI. Screens call these methods and never touch the engine,
// the database or the ML plugins directly.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../data/asset_repository.dart';
import '../data/local_db.dart';
import '../data/models.dart';
import '../data/records.dart';
import '../engine/engine.dart';
import '../engine/recipe.dart';
import '../quests/quest_engine.dart';
import '../recognition/container_cues.dart';
import '../recognition/container_identifier.dart' as ci;
import '../recognition/instruction_parser.dart';
import '../recognition/product_matcher.dart';
import '../recognition/text_reader.dart';
import '../recognition/vision_model.dart';
import '../tracking/exposure_log.dart';
import 'off_client.dart';

class ScanOutcome {
  final MatchResult match;
  final TextRead text;
  final VisionOutput? vision;
  const ScanOutcome(this.match, this.text, this.vision);
}

const _stop = {'the', 'and', 'with', 'of', 'in', 'a', 'n', 'style', 'flavor', 'original', 'single', 'serve', 'bowl', 'bowls', 'cup', 'cups', 'for'};

/// Same word list rule as db/export_assets.py, so user products match like seed products.
List<String> searchTokensFor(String brand, String name) {
  final t = '$brand $name'.toLowerCase().replaceAll("'", '').replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  return ({for (final w in t.split(RegExp(r'\s+'))) if (w.length > 1 && !_stop.contains(w)) w}.toList()..sort());
}

String fatClassFor(ZapParams p, double? fatFraction) {
  if (fatFraction == null) return 'medium';
  for (final fc in p.foodClasses) {
    if (fatFraction < fc.fatMax || identical(fc, p.foodClasses.last)) return fc.key;
  }
  return 'medium';
}

class ZapWiseService {
  ZapAssets assets;
  final ZapEngine engine;
  final LocalDb db;
  final VisionModel? vision;
  final TextReader? reader;
  ProductMatcher matcher;

  ZapWiseService._(this.assets, this.engine, this.db, this.vision, this.reader, this.matcher);

  static Future<ZapWiseService> start({bool withVision = true, bool withOcr = true}) async {
    final db = await LocalDb.open();
    var assets = await ZapAssets.load();
    final userProducts = [for (final j in await db.userProductsJson()) Product.fromJson(jsonDecode(j) as Map<String, dynamic>)];
    assets = assets.withUserProducts(userProducts);
    final vectors = await _userVectors(db);
    VisionModel? vision;
    if (withVision) {
      try {
        vision = await VisionModel.load();
      } catch (_) {
        vision = null; // the app still works with OCR and manual choices
      }
    }
    return ZapWiseService._(assets, ZapEngine(assets.params), db, vision, withOcr ? TextReader() : null, ProductMatcher.fromAssets(assets, userVectors: vectors));
  }

  static Future<Map<String, List<Float32List>>> _userVectors(LocalDb db) async {
    final out = <String, List<Float32List>>{};
    for (final (id, bytes) in await db.userVectors()) {
      out.putIfAbsent(id, () => []).add(Uint8List.fromList(bytes).buffer.asFloat32List());
    }
    return out;
  }

  // ---------------------------------------------------------------- scanning
  Future<ScanOutcome> scanPackage(String photoPath) async {
    final textF = reader?.read(photoPath) ?? Future.value(const TextRead('', []));
    VisionOutput? vis;
    try {
      if (vision != null) vis = await vision!.runOnPhoto(await File(photoPath).readAsBytes());
    } catch (_) {
      vis = null; // the photo model is a helper; barcode and text still decide
    }
    final text = await textF;
    final m = matcher.match(barcodes: text.barcodes, ocrText: text.text, embedding: vis?.embedding);
    return ScanOutcome(m, text, vis);
  }

  /// After the user confirms "yes, this is my product", keep the photo's embedding so the
  /// next scan of the same package matches faster.
  Future<void> rememberProductPhoto(String productId, VisionOutput v) async {
    await db.addUserVector(productId, v.embedding.buffer.asUint8List());
    matcher = ProductMatcher.fromAssets(assets, userVectors: await _userVectors(db));
  }

  /// Container photo -> container type. Markings read by OCR come first (resin code, "dual ovenable",
  /// "microwave safe"), the vision model second; when neither settles it the UI shows a picture question.
  Future<ContainerDecision> identifyContainerPhoto(String photoPath) async {
    final text = reader == null ? '' : (await reader!.read(photoPath, barcodes: false)).text;
    final cues = readContainerCues(text);
    ci.ContainerGuess? guess;
    if (vision != null) {
      final out = await vision!.runOnPhoto(await File(photoPath).readAsBytes());
      if (out != null) guess = containerFromProbs(out.probs);
    }
    return decideContainer(cues, guess);
  }

  ci.ContainerGuess containerFromProbs(List<double> probs) => ci.identifyContainer(probs, vision!.labels.appKeys, assets.params.containers.keys.toSet());

  /// OCR only (appliance labels, tray bottoms, box backs). Empty when OCR is not available.
  Future<TextRead> readText(String photoPath, {bool barcodes = false}) async {
    if (reader == null) return const TextRead('', []);
    try {
      return await reader!.read(photoPath, barcodes: barcodes);
    } catch (_) {
      return const TextRead('', []);
    }
  }

  /// Seed and registered products whose brand and name contain every word of [query].
  List<Product> searchProducts(String query, {int limit = 30}) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return assets.products.take(limit).toList();
    return assets.products.where((p) {
      final t = p.displayName.toLowerCase();
      return words.every(t.contains);
    }).take(limit).toList();
  }

  // ---------------------------------------------------------------- recipe and estimate
  ResolvedRecipe recipeFor(Product p, double watt) => resolveRecipe(p.recipe, watt);
  EvalResult evaluate(Scenario sc, {bool mc = true}) => engine.evaluate(sc, mc: mc);
  Map<String, EvalResult> alternatives(Scenario sc) => engine.alternatives(sc);

  Future<MealRecord> logMeal({required Scenario sc, required EvalResult result, required String profileId, DateTime? at}) async {
    final labelPlan = result.recipe.plan;
    final plan = engine.planFor(sc, result.recipe);
    var followed = plan.length == labelPlan.length;
    for (var i = 0; followed && i < plan.length; i++) {
      followed = plan[i] == labelPlan[i];
    }
    final c = assets.params.containers[result.containerKey]!;
    final rec = MealRecord(
      profileId: profileId,
      productId: sc.product.id,
      containerKey: result.containerKey,
      status: result.status,
      containerStatus: statusName(c.status),
      watt: sc.watt,
      followedLabel: followed,
      groupsPct: result.groups,
      at: at ?? DateTime.now(),
    );
    final id = await db.addMeal(rec);
    return MealRecord(
        id: id,
        profileId: rec.profileId,
        productId: rec.productId,
        containerKey: rec.containerKey,
        status: rec.status,
        containerStatus: rec.containerStatus,
        watt: rec.watt,
        followedLabel: rec.followedLabel,
        groupsPct: rec.groupsPct,
        at: rec.at);
  }

  Future<ExposureSummary> summary(String profileId, {int days = 7, DateTime? now}) async {
    final t = now ?? DateTime.now();
    final meals = await db.meals(profileId: profileId, since: t.subtract(Duration(days: days + 1)));
    return summarize(meals, now: t, days: days, dailyAlertPct: assets.params['daily_alert_pct'], highMealPct: assets.params['band_high_pct']);
  }

  // ---------------------------------------------------------------- unknown products
  ParsedInstructions parseDirections(String ocrText) => parseInstructions(ocrText, defaultWatt: assets.params['default_ref_watt']);

  /// Open Food Facts account from build settings, e.g.
  /// flutter run --dart-define=OFF_USER=name --dart-define=OFF_PASSWORD=secret [--dart-define=OFF_HOST=world.openfoodfacts.org]
  /// Without it, registrations stay on the phone with status pending.
  static OffConfig? offConfigFromEnvironment() {
    const user = String.fromEnvironment('OFF_USER');
    const pass = String.fromEnvironment('OFF_PASSWORD');
    const host = String.fromEnvironment('OFF_HOST', defaultValue: 'world.openfoodfacts.net');
    const basic = String.fromEnvironment('OFF_BASIC_AUTH');
    if (user.isEmpty || pass.isEmpty) return null;
    return OffConfig(host: host, userId: user, password: pass, userAgent: 'ZapWise/0.3 (Congressional App Challenge student project)', basicAuth: basic.isEmpty ? null : basic);
  }

  /// Saves a product the user registered ("help us add this product") and makes it scannable.
  /// With [shareWithOff], a barcode and an Open Food Facts account configured, the name and
  /// photos are also sent to Open Food Facts; otherwise the registration stays pending.
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
    final mass = netG + addedWaterG;
    final fat = fatGPerPackage == null ? null : fatGPerPackage / mass;
    final id = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final p = Product(
      id: id,
      brand: brand,
      name: name,
      upc: barcode,
      category: 'user',
      netG: netG,
      servings: 1,
      foodMassG: mass,
      fatFraction: fat,
      fatClass: fatClassFor(assets.params, fat),
      fatKnown: fat != null,
      storage: storage,
      containerKey: containerKey,
      containerConfidence: 'user',
      recipe: recipe,
      searchTokens: searchTokensFor(brand, name),
      flags: const ['registered by user'],
    );
    final js = jsonEncode(p.toJson());
    await db.saveUserProduct(id, js);
    final regId = await db.addRegistration(Registration(productJson: js, photoPaths: photoPaths, ocrText: ocrText, barcode: barcode, createdAt: DateTime.now()));
    final off = offConfigFromEnvironment();
    if (shareWithOff && off != null && barcode != null && barcode.isNotEmpty) {
      final client = OffClient(off);
      try {
        final res = await client.saveProduct(client.productFields(
          code: barcode,
          name: name,
          brand: brand,
          quantity: '${netG.round()} g',
          preparationText: ocrText.isEmpty ? null : ocrText,
        ));
        if (res['status'] == 1) {
          for (var i = 0; i < photoPaths.length; i++) {
            await client.uploadImage(code: barcode, imageField: i == 0 ? 'front' : 'packaging', photo: File(photoPaths[i]));
          }
          await db.markRegistration(regId, 'shared');
        }
      } catch (_) {
        // offline or rejected: stays pending on the phone
      } finally {
        client.close();
      }
    }
    if (vision != null) await db.addUserVector(id, vision.embedding.buffer.asUint8List());
    assets = assets.withUserProducts([p]);
    matcher = ProductMatcher.fromAssets(assets, userVectors: await _userVectors(db));
    return p;
  }

  // ---------------------------------------------------------------- quests
  /// Sample meals (profile id starting with 'sample:') never count toward quests.
  Future<List<QuestState>> quests({DateTime? now}) async => questStates(QuestContext(
        appliances: await db.appliances(),
        shelf: await db.shelf(),
        meals: (await db.meals()).where((x) => !x.profileId.startsWith('sample:')).toList(),
        claimed: await db.claimedQuests(),
        now: now ?? DateTime.now(),
      ));

  Future<void> claim(QuestState q) async {
    if (!q.claimable) return;
    await db.claimQuest(q.instanceId);
    if (q.def.decor != null) await db.unlockDecor(q.def.decor!);
  }

  Future<void> dispose() async {
    vision?.close();
    await reader?.close();
    await db.close();
  }
}
