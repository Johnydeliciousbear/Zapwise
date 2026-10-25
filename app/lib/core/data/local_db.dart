// On-phone storage (sqflite). Everything stays on the device; nothing is uploaded unless the
// user chooses to share a product registration.
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'records.dart';

class LocalDb {
  final Database db;
  LocalDb._(this.db);

  static const _version = 1;

  static Future<LocalDb> open({String fileName = 'zapwise.db'}) async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(p.join(dir, fileName), version: _version, onCreate: (d, v) async {
      final b = d.batch();
      b.execute('CREATE TABLE profiles(id TEXT PRIMARY KEY, name TEXT NOT NULL, body_weight_kg REAL NOT NULL, grp TEXT NOT NULL, is_default INTEGER NOT NULL)');
      b.execute('CREATE TABLE appliances(id TEXT PRIMARY KEY, kind TEXT NOT NULL, name TEXT NOT NULL, rated_watt REAL, measured_watt REAL)');
      b.execute('CREATE TABLE shelf(id TEXT PRIMARY KEY, container_key TEXT NOT NULL, name TEXT NOT NULL, photo_path TEXT, created_at INTEGER NOT NULL)');
      b.execute('''CREATE TABLE meals(id INTEGER PRIMARY KEY AUTOINCREMENT, profile_id TEXT NOT NULL, product_id TEXT NOT NULL,
          container_key TEXT NOT NULL, status TEXT NOT NULL, container_status TEXT NOT NULL, watt REAL NOT NULL,
          followed_label INTEGER NOT NULL, groups TEXT, at INTEGER NOT NULL, day TEXT NOT NULL)''');
      b.execute('CREATE INDEX meals_profile_day ON meals(profile_id, day)');
      b.execute('CREATE TABLE quests(id TEXT PRIMARY KEY, claimed_at INTEGER)');
      b.execute('CREATE TABLE decor(item TEXT PRIMARY KEY, unlocked_at INTEGER NOT NULL)');
      b.execute('''CREATE TABLE registrations(id INTEGER PRIMARY KEY AUTOINCREMENT, product_json TEXT NOT NULL, photo_paths TEXT,
          ocr_text TEXT, barcode TEXT, status TEXT NOT NULL, created_at INTEGER NOT NULL)''');
      b.execute('CREATE TABLE user_products(id TEXT PRIMARY KEY, product_json TEXT NOT NULL)');
      b.execute('CREATE TABLE user_vectors(id INTEGER PRIMARY KEY AUTOINCREMENT, product_id TEXT NOT NULL, vector BLOB NOT NULL)');
      await b.commit(noResult: true);
    });
    return LocalDb._(db);
  }

  // ---------------------------------------------------------------- profiles
  Future<void> saveProfile(Profile x) => db.insert('profiles', x.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<List<Profile>> profiles() async => (await db.query('profiles')).map(Profile.fromRow).toList();
  Future<void> deleteProfile(String id) => db.delete('profiles', where: 'id = ?', whereArgs: [id]);

  // ---------------------------------------------------------------- appliances
  Future<void> saveAppliance(Appliance x) => db.insert('appliances', x.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<List<Appliance>> appliances() async => (await db.query('appliances')).map(Appliance.fromRow).toList();
  Future<void> deleteAppliance(String id) => db.delete('appliances', where: 'id = ?', whereArgs: [id]);

  // ---------------------------------------------------------------- shelf (user's containers)
  Future<void> saveShelfItem(ShelfItem x) => db.insert('shelf', x.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<List<ShelfItem>> shelf() async => (await db.query('shelf', orderBy: 'created_at')).map(ShelfItem.fromRow).toList();
  Future<void> deleteShelfItem(String id) => db.delete('shelf', where: 'id = ?', whereArgs: [id]);

  // ---------------------------------------------------------------- meals
  Future<int> addMeal(MealRecord x) {
    final row = x.toRow()..remove('id');
    return db.insert('meals', row);
  }

  Future<List<MealRecord>> meals({String? profileId, DateTime? since}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (profileId != null) {
      where.add('profile_id = ?');
      args.add(profileId);
    }
    if (since != null) {
      where.add('at >= ?');
      args.add(since.millisecondsSinceEpoch);
    }
    final rows = await db.query('meals', where: where.isEmpty ? null : where.join(' AND '), whereArgs: args.isEmpty ? null : args, orderBy: 'at');
    return rows.map(MealRecord.fromRow).toList();
  }

  Future<void> deleteMeal(int id) => db.delete('meals', where: 'id = ?', whereArgs: [id]);

  // ---------------------------------------------------------------- quests and decor
  Future<Set<String>> claimedQuests() async => (await db.query('quests', where: 'claimed_at IS NOT NULL')).map((r) => r['id'] as String).toSet();
  Future<void> claimQuest(String id) => db.insert('quests', {'id': id, 'claimed_at': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<Set<String>> decor() async => (await db.query('decor')).map((r) => r['item'] as String).toSet();
  Future<void> unlockDecor(String item) =>
      db.insert('decor', {'item': item, 'unlocked_at': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.ignore);

  // ---------------------------------------------------------------- registrations and user products
  Future<int> addRegistration(Registration x) {
    final row = x.toRow()..remove('id');
    return db.insert('registrations', row);
  }

  Future<List<Registration>> registrations({String? status}) async =>
      (await db.query('registrations', where: status == null ? null : 'status = ?', whereArgs: status == null ? null : [status], orderBy: 'created_at'))
          .map(Registration.fromRow)
          .toList();

  Future<void> markRegistration(int id, String status) => db.update('registrations', {'status': status}, where: 'id = ?', whereArgs: [id]);

  Future<void> saveUserProduct(String id, String productJson) =>
      db.insert('user_products', {'id': id, 'product_json': productJson}, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<List<String>> userProductsJson() async => (await db.query('user_products')).map((r) => r['product_json'] as String).toList();

  Future<void> addUserVector(String productId, Uint8List float32Bytes) => db.insert('user_vectors', {'product_id': productId, 'vector': float32Bytes});
  Future<List<(String, Uint8List)>> userVectors() async =>
      (await db.query('user_vectors')).map((r) => (r['product_id'] as String, Uint8List.fromList((r['vector'] as List).cast<int>()))).toList();

  /// Deletes everything the user stored (Me > Reset). The tables stay.
  Future<void> clearAll() async {
    final b = db.batch();
    for (final t in ['profiles', 'appliances', 'shelf', 'meals', 'quests', 'decor', 'registrations', 'user_products', 'user_vectors']) {
      b.delete(t);
    }
    await b.commit(noResult: true);
  }

  Future<void> close() => db.close();
}
