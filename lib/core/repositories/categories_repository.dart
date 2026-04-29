import 'package:drift/drift.dart';
import 'package:pos_system/core/database/app_database.dart';

class CategoryWithCount {
  CategoryWithCount({required this.category, required this.productCount});

  final Category category;
  final int productCount;
}

class CategoriesRepository {
  CategoriesRepository(this._db);

  final AppDatabase _db;

  Stream<List<Category>> watchAll() => _db.select(_db.categories).watch();

  Future<List<Category>> getAll() => _db.select(_db.categories).get();

  /// Returns categories with their linked product counts.
  Stream<List<CategoryWithCount>> watchWithCounts() {
    final productCount = _db.products.id.count();
    final query = _db.select(_db.categories).join([
      leftOuterJoin(_db.products, _db.products.categoryId.equalsExp(_db.categories.id)),
    ])
      ..groupBy([_db.categories.id])
      ..addColumns([productCount]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => CategoryWithCount(
                  category: row.readTable(_db.categories),
                  productCount: row.read(productCount) ?? 0,
                ),
              )
              .toList(),
        );
  }

  Future<List<CategoryWithCount>> fetchWithCounts() => watchWithCounts().first;

  Future<int> countProductsForCategory(int categoryId) async {
    final query = _db.products.id.count();
    final result = await (_db.selectOnly(_db.products)
          ..where(_db.products.categoryId.equals(categoryId))
          ..addColumns([query]))
        .map((row) => row.read(query) ?? 0)
        .getSingle();
    return result;
  }

  Future<Category?> getById(int id) => (_db.select(_db.categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<Category?> getByName(String name) => (_db.select(_db.categories)..where((c) => c.name.equals(name))).getSingleOrNull();

  Future<int> insert(CategoriesCompanion companion) => _db.into(_db.categories).insert(companion);

  Future<bool> updateCategory(CategoriesCompanion companion) async {
    return _db.update(_db.categories).replace(companion);
  }

  Future<int> deleteById(int id) => (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();

  Future<bool> updateNameAndColor({required int id, required String name, required String colorHex}) async {
    final rowsUpdated = await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        id: Value(id),
        name: Value(name),
        colorHex: Value(colorHex),
      ),
    );
    return rowsUpdated > 0;
  }
}

