import 'package:pos_system/core/database/app_database.dart';

class SalesRepository {
  SalesRepository(this._db);

  final AppDatabase _db;

  Stream<List<Sale>> watchAll() => _db.select(_db.sales).watch();

  Future<List<Sale>> getAll() => _db.select(_db.sales).get();

  Future<Sale?> getById(int id) => (_db.select(_db.sales)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> insert(SalesCompanion companion) => _db.into(_db.sales).insert(companion);

  Future<bool> updateSale(SalesCompanion companion) async {
    return _db.update(_db.sales).replace(companion);
  }

  Future<int> deleteById(int id) => (_db.delete(_db.sales)..where((s) => s.id.equals(id))).go();
}

