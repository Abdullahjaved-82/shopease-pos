import 'package:drift/drift.dart';
import 'package:pos_system/core/database/app_database.dart';

class InventoryRepository {
  InventoryRepository(this._db);

  final AppDatabase _db;

  /// Records a stock movement and updates the product's stock (and optional cost price).
  Future<int> recordMovement({
    required int productId,
    required String type,
    required int qty,
    String? note,
    required int userId,
    double? newCostPrice,
  }) async {
    return _db.transaction(() async {
      final product = await (_db.select(_db.products)..where((p) => p.id.equals(productId))).getSingle();
      final updatedQty = product.stockQuantity + qty;
      await (_db.update(_db.products)..where((p) => p.id.equals(productId))).write(
        ProductsCompanion(
          stockQuantity: Value(updatedQty),
          costPrice: newCostPrice != null ? Value(newCostPrice) : const Value.absent(),
        ),
      );

      return _db.into(_db.stockMovements).insert(
            StockMovementsCompanion.insert(
              productId: productId,
              type: type,
              qty: qty,
              note: Value(note),
              userId: userId,
            ),
          );
    });
  }

  Stream<List<StockMovement>> getMovements(int productId) {
    return (_db.select(_db.stockMovements)
          ..where((m) => m.productId.equals(productId))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .watch();
  }

  Stream<List<StockMovement>> watchMovements({int? productId, String? typePrefix, DateTime? start, DateTime? end}) {
    final query = _db.select(_db.stockMovements);
    if (productId != null) {
      query.where((m) => m.productId.equals(productId));
    }
    if (typePrefix != null) {
      query.where((m) => m.type.like('$typePrefix%'));
    }
    if (start != null) {
      query.where((m) => m.createdAt.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      query.where((m) => m.createdAt.isSmallerOrEqualValue(end));
    }
    query.orderBy([(m) => OrderingTerm.desc(m.createdAt)]);
    return query.watch();
  }

  Stream<List<Product>> getLowStockProducts(int threshold) {
    return (_db.select(_db.products)..where((p) => p.stockQuantity.isSmallerThanValue(threshold))).watch();
  }

  Stream<List<Product>> watchLowStockAgainstReorder() {
    return (_db.select(_db.products)
          ..where((p) => p.stockQuantity.isSmallerThan(p.reorderLevel)))
        .watch();
  }
}






