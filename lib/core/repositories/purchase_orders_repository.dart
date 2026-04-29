import 'package:drift/drift.dart';
import 'package:pos_system/core/database/app_database.dart';

class PurchaseOrderItemInput {
  PurchaseOrderItemInput({required this.productId, required this.qty, required this.costPrice});
  final int productId;
  final int qty;
  final double costPrice;
}

class PurchaseOrderItemWithProduct {
  PurchaseOrderItemWithProduct({required this.item, required this.product});
  final PurchaseOrderItem item;
  final Product product;
}

class PurchaseOrderWithSupplier {
  PurchaseOrderWithSupplier({required this.order, required this.supplier});
  final PurchaseOrder order;
  final Supplier supplier;
}

class PurchaseOrdersRepository {
  PurchaseOrdersRepository(this._db);

  final AppDatabase _db;

  Future<int> createOrder({
    required int supplierId,
    required List<PurchaseOrderItemInput> items,
    String status = 'draft',
    String? note,
  }) async {
    return _db.transaction(() async {
      final total = _calculateTotal(items);
      final orderId = await _db.into(_db.purchaseOrders).insert(
            PurchaseOrdersCompanion.insert(
              supplierId: supplierId,
              status: Value(status),
              total: Value(total),
              note: Value(note),
            ),
          );

      if (items.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(
            _db.purchaseOrderItems,
            items
                .map(
                  (i) => PurchaseOrderItemsCompanion.insert(
                    orderId: orderId,
                    productId: i.productId,
                    qty: i.qty,
                    costPrice: Value(i.costPrice),
                  ),
                )
                .toList(),
          );
        });
      }

      return orderId;
    });
  }

  Future<int> addItem({required int orderId, required int productId, required int qty, required double costPrice}) async {
    return _db.transaction(() async {
      final id = await _db.into(_db.purchaseOrderItems).insert(
            PurchaseOrderItemsCompanion.insert(
              orderId: orderId,
              productId: productId,
              qty: qty,
              costPrice: Value(costPrice),
            ),
          );
      await _recalculateTotal(orderId);
      return id;
    });
  }

  Future<void> markReceived({required int orderId, required int userId}) async {
    await _db.transaction(() async {
      final order = await (_db.select(_db.purchaseOrders)..where((o) => o.id.equals(orderId))).getSingleOrNull();
      if (order == null || order.status == 'received') return;

      final supplier = await (_db.select(_db.suppliers)..where((s) => s.id.equals(order.supplierId))).getSingleOrNull();
      final items = await (_db.select(_db.purchaseOrderItems)..where((i) => i.orderId.equals(orderId))).get();

      for (final item in items) {
        final product = await (_db.select(_db.products)..where((p) => p.id.equals(item.productId))).getSingle();
        final nextQty = product.stockQuantity + item.qty;
        await (_db.update(_db.products)..where((p) => p.id.equals(item.productId))).write(
          ProductsCompanion(
            stockQuantity: Value(nextQty),
            costPrice: item.costPrice != product.costPrice ? Value(item.costPrice) : const Value.absent(),
          ),
        );

        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: item.productId,
                type: 'purchase',
                qty: item.qty,
                note: Value('PO #$orderId'),
                userId: userId,
              ),
            );
      }

      await (_db.update(_db.purchaseOrders)..where((o) => o.id.equals(orderId))).write(
        const PurchaseOrdersCompanion(status: Value('received')),
      );

      if (supplier != null) {
        final nextBalance = supplier.balance + order.total;
        await (_db.update(_db.suppliers)..where((s) => s.id.equals(supplier.id))).write(
          SuppliersCompanion(balance: Value(nextBalance)),
        );
      }
    });
  }

  Stream<List<PurchaseOrder>> watchOrders({int? supplierId, String? status}) {
    final query = _db.select(_db.purchaseOrders)
      ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]);
    if (supplierId != null) {
      query.where((o) => o.supplierId.equals(supplierId));
    }
    if (status != null) {
      query.where((o) => o.status.equals(status));
    }
    return query.watch();
  }

  Stream<List<PurchaseOrderWithSupplier>> watchOrdersWithSupplier({int? supplierId}) {
    final query = _db.select(_db.purchaseOrders).join([
      innerJoin(_db.suppliers, _db.suppliers.id.equalsExp(_db.purchaseOrders.supplierId)),
    ])
      ..orderBy([OrderingTerm.desc(_db.purchaseOrders.createdAt)]);

    if (supplierId != null) {
      query.where(_db.purchaseOrders.supplierId.equals(supplierId));
    }

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => PurchaseOrderWithSupplier(
                  order: row.readTable(_db.purchaseOrders),
                  supplier: row.readTable(_db.suppliers),
                ),
              )
              .toList(),
        );
  }

  Stream<List<PurchaseOrderItemWithProduct>> watchItems(int orderId) {
    final query = _db.select(_db.purchaseOrderItems).join([
      innerJoin(_db.products, _db.products.id.equalsExp(_db.purchaseOrderItems.productId)),
    ])
      ..where(_db.purchaseOrderItems.orderId.equals(orderId));

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => PurchaseOrderItemWithProduct(
                  item: row.readTable(_db.purchaseOrderItems),
                  product: row.readTable(_db.products),
                ),
              )
              .toList(),
        );
  }

  Future<void> _recalculateTotal(int orderId) async {
    final totals = await (_db.customSelect(
      'SELECT SUM(qty * cost_price) as total FROM purchase_order_items WHERE order_id = ?;',
      variables: [Variable<int>(orderId)],
      readsFrom: {_db.purchaseOrderItems},
    ).getSingle());
    final total = totals.data['total'] as double? ?? 0.0;
    await (_db.update(_db.purchaseOrders)..where((o) => o.id.equals(orderId))).write(
      PurchaseOrdersCompanion(total: Value(total)),
    );
  }

  double _calculateTotal(List<PurchaseOrderItemInput> items) {
    return items.fold<double>(0, (sum, item) => sum + (item.costPrice * item.qty));
  }
}


