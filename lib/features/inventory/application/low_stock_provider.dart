import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/core/database/app_database.dart';

part 'low_stock_provider.g.dart';

@riverpod
Stream<List<Product>> lowStockProducts(LowStockProductsRef ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.watchLowStockAgainstReorder();
}

final lowStockCountProvider = StreamProvider<int>((ref) {
  return ref.watch(lowStockProductsProvider.stream).map((items) => items.length);
});

