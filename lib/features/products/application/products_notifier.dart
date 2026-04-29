import 'package:drift/drift.dart' show OrderingMode, OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/core/repositories/products_repository.dart';
import 'package:pos_system/features/products/application/product_state.dart';

class ProductsNotifier extends AsyncNotifier<ProductListState> {
  late final ProductsRepository _repository;

  @override
  Future<ProductListState> build() async {
    _repository = ref.read(productsRepositoryProvider);
    return const ProductListState();
  }

  Future<void> loadMore({bool reset = false}) async {
    final current = state.value ?? const ProductListState();
    final offset = reset ? 0 : current.offset;
    final order = _sortToOrdering(current.sort);
    final page = await _repository.fetchPage(
      limit: current.limit,
      offset: offset,
      categoryId: current.categoryId,
      search: current.search,
      orderBy: order,
    );
    state = AsyncData(current.copyWith(
      products: reset ? page : [...current.products, ...page],
      offset: offset + page.length,
      hasMore: page.length >= current.limit,
    ));
  }

  void setSearch(String query) {
    final current = state.value ?? const ProductListState();
    state = AsyncData(current.copyWith(search: query, offset: 0, products: []));
    loadMore(reset: true);
  }

  void setCategory(int? categoryId) {
    final current = state.value ?? const ProductListState();
    state = AsyncData(current.copyWith(categoryId: categoryId, offset: 0, products: []));
    loadMore(reset: true);
  }

  void setSort(ProductSort sort) {
    final current = state.value ?? const ProductListState();
    state = AsyncData(current.copyWith(sort: sort, offset: 0, products: []));
    loadMore(reset: true);
  }

  Future<int> createProduct(ProductsCompanion companion) {
    return _repository.insert(companion);
  }

  Future<bool> updateProduct(ProductsCompanion companion) {
    return _repository.updateProduct(companion);
  }

  Future<int> deleteProduct(int id) {
    return _repository.deleteById(id);
  }

  Stream<List<Product>> watchPaged({int offset = 0, int limit = 20}) {
    final current = state.value ?? const ProductListState();
    final order = _sortToOrdering(current.sort);
    return _repository.watchPaged(
      offset: offset,
      limit: limit,
      categoryId: current.categoryId,
      search: current.search,
      orderBy: order,
    );
  }

  OrderingTerm Function(Products p)? _sortToOrdering(ProductSort sort) {
    switch (sort) {
      case ProductSort.nameAsc:
        return (p) => OrderingTerm(expression: p.name, mode: OrderingMode.asc);
      case ProductSort.nameDesc:
        return (p) => OrderingTerm(expression: p.name, mode: OrderingMode.desc);
      case ProductSort.priceAsc:
        return (p) => OrderingTerm(expression: p.salePrice, mode: OrderingMode.asc);
      case ProductSort.priceDesc:
        return (p) => OrderingTerm(expression: p.salePrice, mode: OrderingMode.desc);
      case ProductSort.stockAsc:
        return (p) => OrderingTerm(expression: p.stockQuantity, mode: OrderingMode.asc);
      case ProductSort.stockDesc:
        return (p) => OrderingTerm(expression: p.stockQuantity, mode: OrderingMode.desc);
    }
  }
}

final productsNotifierProvider = AsyncNotifierProvider<ProductsNotifier, ProductListState>(ProductsNotifier.new);


