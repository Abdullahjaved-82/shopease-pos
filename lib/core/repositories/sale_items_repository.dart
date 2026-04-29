import 'package:pos_system/core/database/app_database.dart';

class SaleItemsRepository {
  SaleItemsRepository(this._db);

  final AppDatabase _db;

  Stream<List<SaleItem>> watchForSale(int saleId) {
    return (_db.select(_db.saleItems)..where((i) => i.saleId.equals(saleId))).watch();
  }

  Future<List<SaleItem>> getForSale(int saleId) {
    return (_db.select(_db.saleItems)..where((i) => i.saleId.equals(saleId))).get();
  }

  Future<int> insert(SaleItemsCompanion companion) => _db.into(_db.saleItems).insert(companion);

  Future<bool> updateItem(SaleItemsCompanion companion) async {
    return _db.update(_db.saleItems).replace(companion);
  }

  Future<int> deleteById(int id) => (_db.delete(_db.saleItems)..where((i) => i.id.equals(id))).go();

  Future<int> deleteBySale(int saleId) => (_db.delete(_db.saleItems)..where((i) => i.saleId.equals(saleId))).go();
}

