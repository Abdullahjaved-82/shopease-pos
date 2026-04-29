import 'package:drift/drift.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/security/crypto_utils.dart';

class UsersRepository {
  UsersRepository(this._db);

  final AppDatabase _db;

  Stream<List<User>> watchAll() => _db.select(_db.users).watch();

  Future<List<User>> getAll() => _db.select(_db.users).get();

  Future<User?> getById(int id) => (_db.select(_db.users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<User?> getByRole(String role) {
    return (_db.select(_db.users)
          ..where((u) => u.role.equals(role))
          // ..where((u) => u.isActive.equals(true)) // REMOVED to prevent SqliteException if column is missing on older DB schemas
          ..orderBy([(u) => OrderingTerm.desc(u.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<User?> getByPinHash(String pinHash) {
    return (_db.select(_db.users)
          ..where((u) => u.pinHash.equals(pinHash))
          ..orderBy([(u) => OrderingTerm.desc(u.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  // Backwards compatible helpers used by auth controller/tests
  Future<User?> getUserByRole(String role) => getByRole(role);

  Future<User?> getUserByPinHash(String pinHash) => getByPinHash(pinHash);

  Future<int> insert(UsersCompanion companion) => _db.into(_db.users).insert(companion);

  Future<bool> updateUser(UsersCompanion companion) async {
    return _db.update(_db.users).replace(companion);
  }

  Future<int> deleteById(int id) => (_db.delete(_db.users)..where((u) => u.id.equals(id))).go();

  Future<void> seedDefaultsIfEmpty() async {
    final existing = await _db.select(_db.users).get();
    if (existing.isNotEmpty) return;

    await _insertUser(name: 'Admin', role: 'admin', pin: '1234');
    await _insertUser(name: 'Cashier', role: 'cashier', pin: '0000');
  }

  Future<void> resetDefaultPins() async {
    await _upsertUserPin(role: 'admin', fallbackName: 'Admin', pin: '1234');
    await _upsertUserPin(role: 'cashier', fallbackName: 'Cashier', pin: '0000');
  }

  // Backwards compatibility for older tests
  Future<void> seedDefaultUsers() => seedDefaultsIfEmpty();

  Future<void> _insertUser({required String name, required String role, required String pin}) async {
    final salt = CryptoUtils.generateSalt();
    final pinHash = CryptoUtils.hashPin(pin, salt);
    await _db.into(_db.users).insert(
          UsersCompanion.insert(
            name: name,
            role: Value(role),
            salt: salt,
            pinHash: pinHash,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _upsertUserPin({
    required String role,
    required String fallbackName,
    required String pin,
  }) async {
    final salt = CryptoUtils.generateSalt();
    final pinHash = CryptoUtils.hashPin(pin, salt);
    
    // We do NOT update isActive here in case the column is missing in the user's local sqlite db
    final affected = await (_db.update(_db.users)..where((u) => u.role.equals(role))).write(
      UsersCompanion(
        salt: Value(salt),
        pinHash: Value(pinHash),
      ),
    );

    if (affected == 0) {
      await _insertUser(name: fallbackName, role: role, pin: pin);
    }
  }
}
