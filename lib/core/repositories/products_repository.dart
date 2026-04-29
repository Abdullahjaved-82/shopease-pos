import 'package:drift/drift.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/repositories/repository_base.dart';
import 'package:pos_system/core/sync/sync_log_repository.dart';

class ProductsRepository extends RepositoryBase {
  ProductsRepository(this._db)
      : super(
          SyncLogRepository(_db),
          'local',
        );

  final AppDatabase _db;

  Stream<List<Product>> watchAll() => _db.select(_db.products).watch();

  Stream<List<Product>> watchPaged({
    int limit = 20,
    int offset = 0,
    int? categoryId,
    String? search,
    OrderingTerm Function(Products p)? orderBy,
  }) {
    final query = _buildQuery(limit: limit, offset: offset, categoryId: categoryId, search: search, orderBy: orderBy);
    return query.watch();
  }

  Future<List<Product>> fetchPage({
    int limit = 20,
    int offset = 0,
    int? categoryId,
    String? search,
    OrderingTerm Function(Products p)? orderBy,
  }) {
    final query = _buildQuery(limit: limit, offset: offset, categoryId: categoryId, search: search, orderBy: orderBy);
    return query.get();
  }

  Future<List<Product>> getAll() => _db.select(_db.products).get();

  Future<Product?> getById(int id) => (_db.select(_db.products)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<int> insert(ProductsCompanion companion) async {
    final id = await _db.into(_db.products).insert(companion);
    final row = await getById(id);
    if (row != null) {
      await logInsert(tableName: 'products', recordId: id, data: _toSyncData(row));
    }
    return id;
  }

  Future<bool> updateProduct(ProductsCompanion companion) async {
    final ok = await _db.update(_db.products).replace(companion);
    final id = companion.id.value;
    if (ok) {
      final row = await getById(id);
      if (row != null) {
        await logUpdate(tableName: 'products', recordId: id, data: _toSyncData(row));
      }
    }
    return ok;
  }

  Future<int> deleteById(int id) async {
    final count = await (_db.delete(_db.products)..where((p) => p.id.equals(id))).go();
    if (count > 0) {
      await logDelete(tableName: 'products', recordId: id);
    }
    return count;
  }

  Map<String, dynamic> _toSyncData(Product row) => {
        'id': row.id,
        'name': row.name,
        'barcode': row.barcode,
        'categoryId': row.categoryId,
        'unit': row.unit,
        'reorderLevel': row.reorderLevel,
        'costPrice': row.costPrice,
        'salePrice': row.salePrice,
        'stockQuantity': row.stockQuantity,
        'isActive': row.isActive,
        'createdAt': row.createdAt.toUtc().toIso8601String(),
        'updatedAt': row.updatedAt.toUtc().toIso8601String(),
      };

  SimpleSelectStatement<$ProductsTable, Product> _buildQuery({
    required int limit,
    required int offset,
    int? categoryId,
    String? search,
    OrderingTerm Function(Products p)? orderBy,
  }) {
    final query = _db.select(_db.products)
      ..limit(limit, offset: offset);
    if (categoryId != null) {
      query.where((p) => p.categoryId.equals(categoryId));
    }
    if (search != null && search.isNotEmpty) {
      final pattern = '%${search.toLowerCase()}%';
      query.where(
        (p) => p.name.lower().like(pattern) | p.barcode.lower().like(pattern),
      );
    }
    if (orderBy != null) {
      query.orderBy([orderBy]);
    }
    return query;
  }
}

