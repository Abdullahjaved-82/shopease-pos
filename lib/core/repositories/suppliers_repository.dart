import 'package:drift/drift.dart';
import 'package:pos_system/core/database/app_database.dart';

class SuppliersRepository {
  SuppliersRepository(this._db);

  final AppDatabase _db;

  Stream<List<Supplier>> watchAll({String? search}) {
    final query = _db.select(_db.suppliers)
      ..orderBy([(s) => OrderingTerm.asc(s.name)]);
    if (search != null && search.isNotEmpty) {
      final pattern = '%${search.toLowerCase()}%';
      query.where((s) => s.name.lower().like(pattern));
    }
    return query.watch();
  }

  Future<List<Supplier>> getAll() => _db.select(_db.suppliers).get();

  Future<Supplier?> getById(int id) => (_db.select(_db.suppliers)..where((s) => s.id.equals(id))).getSingleOrNull();

  Stream<Supplier?> watchById(int id) {
    return (_db.select(_db.suppliers)..where((s) => s.id.equals(id))).watchSingleOrNull();
  }

  Future<int> insert(SuppliersCompanion companion) => _db.into(_db.suppliers).insert(companion);

  Future<bool> updateSupplier(SuppliersCompanion companion) => _db.update(_db.suppliers).replace(companion);

  Future<int> deleteById(int id) => (_db.delete(_db.suppliers)..where((s) => s.id.equals(id))).go();

  Future<double> getBalance(int supplierId) async {
    final row = await (_db.select(_db.suppliers)..where((s) => s.id.equals(supplierId))).getSingleOrNull();
    return row?.balance ?? 0;
  }

  Future<void> adjustBalance({required int supplierId, required double delta}) async {
    final supplier = await getById(supplierId);
    if (supplier == null) return;
    final next = supplier.balance + delta;
    await (_db.update(_db.suppliers)..where((s) => s.id.equals(supplierId))).write(
      SuppliersCompanion(balance: Value(next)),
    );
  }
}

