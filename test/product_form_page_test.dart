import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/features/products/presentation/product_form_page.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/repositories/categories_repository.dart';
import 'package:pos_system/core/repositories/products_repository.dart';
import 'package:pos_system/core/sync/sync_log_repository.dart';

class _FakeCategoriesRepository implements CategoriesRepository {
  _FakeCategoriesRepository();

  @override
  Stream<List<Category>> watchAll() => Stream.value(const []);

  @override
  Future<List<Category>> getAll() async => const [];

  @override
  Future<Category?> getById(int id) async => null;

  @override
  Future<Category?> getByName(String name) async => null;

  @override
  Future<int> insert(CategoriesCompanion companion) async => 0;

  @override
  Future<bool> updateCategory(CategoriesCompanion companion) async => true;

  @override
  Future<int> deleteById(int id) async => 0;

  @override
  Stream<List<CategoryWithCount>> watchWithCounts() => Stream.value(const []);

  @override
  Future<List<CategoryWithCount>> fetchWithCounts() async => const [];

  @override
  Future<int> countProductsForCategory(int categoryId) async => 0;

  @override
  Future<bool> updateNameAndColor({required int id, required String name, required String colorHex}) async => true;
}

class _FakeProductsRepository implements ProductsRepository {
  _FakeProductsRepository();

  @override
  String get deviceId => 'test';

  @override
  SyncLogRepository get syncLogRepository => throw UnimplementedError();

  @override
  Future<void> logDelete({required String tableName, required Object recordId}) async {}

  @override
  Future<void> logInsert({required String tableName, required Object recordId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> logUpdate({required String tableName, required Object recordId, required Map<String, dynamic> data}) async {}

  @override
  Future<int> deleteById(int id) async => 0;

  @override
  Future<List<Product>> fetchPage({int limit = 20, int offset = 0, int? categoryId, String? search, OrderingTerm Function(Products p)? orderBy}) async => const [];

  @override
  Future<List<Product>> getAll() async => const [];

  @override
  Future<Product?> getById(int id) async => null;

  @override
  Future<int> insert(ProductsCompanion companion) async => 0;

  @override
  Future<bool> updateProduct(ProductsCompanion companion) async => true;

  @override
  Stream<List<Product>> watchAll() => Stream.value(const []);

  @override
  Stream<List<Product>> watchPaged({int limit = 20, int offset = 0, int? categoryId, String? search, OrderingTerm Function(Products p)? orderBy}) => Stream.value(const []);
}

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [
        categoriesRepositoryProvider.overrideWith((ref) => _FakeCategoriesRepository()),
        productsRepositoryProvider.overrideWith((ref) => _FakeProductsRepository()),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('name required validation', (tester) async {
    await tester.pumpWidget(wrap(const ProductFormPage()));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Name is required'), findsOneWidget);
  });

  testWidgets('sale price must be greater than zero', (tester) async {
    await tester.pumpWidget(wrap(const ProductFormPage()));
    await tester.enterText(find.byType(TextFormField).at(0), 'Item');
    await tester.enterText(find.byType(TextFormField).at(3), '-1');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Sale price must be > 0'), findsOneWidget);
  });

  testWidgets('stock cannot be negative', (tester) async {
    await tester.pumpWidget(wrap(const ProductFormPage()));
    await tester.enterText(find.byType(TextFormField).at(0), 'Item');
    await tester.enterText(find.byType(TextFormField).at(3), '10');
    await tester.enterText(find.byType(TextFormField).at(4), '-2');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Stock cannot be negative'), findsOneWidget);
  });
}
