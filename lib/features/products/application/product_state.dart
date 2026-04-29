import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pos_system/core/database/app_database.dart';

part 'product_state.freezed.dart';

enum ProductSort { nameAsc, nameDesc, priceAsc, priceDesc, stockAsc, stockDesc }

@freezed
class ProductListState with _$ProductListState {
  const factory ProductListState({
    @Default([]) List<Product> products,
    @Default(false) bool isLoading,
    @Default('') String search,
    int? categoryId,
    @Default(ProductSort.nameAsc) ProductSort sort,
    @Default(0) int offset,
    @Default(20) int limit,
    @Default(false) bool hasMore,
  }) = _ProductListState;
}

