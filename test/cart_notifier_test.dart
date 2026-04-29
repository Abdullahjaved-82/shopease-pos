import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/features/sales/application/cart_notifier.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  final product = Product(
    id: 1,
    name: 'Test Product',
    barcode: 'ABC',
    categoryId: null,
    unit: 'pcs',
    reorderLevel: 0,
    costPrice: 10,
    salePrice: 100,
    stockQuantity: 10,
    isActive: true,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  test('subtotal, discounts, and change are computed correctly', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(cartNotifierProvider.notifier);
    notifier.addItem(product);
    notifier.updateQty(product.id, 2);
    notifier.setLineDiscount(product.id, 10); // 10% line discount
    notifier.setOrderDiscount(5); // 5% order discount
    notifier.setAmountTendered(200);

    final state = container.read(cartNotifierProvider);

    expect(state.subtotal, closeTo(200, 0.001));
    expect(state.discountAmount, closeTo(29, 0.001)); // 20 line + 9 order
    expect(state.total, closeTo(171, 0.001));
    expect(state.change, closeTo(29, 0.001));
  });

  test('removing items and zero quantities clears them', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(cartNotifierProvider.notifier);
    notifier.addItem(product);
    notifier.updateQty(product.id, 0);

    final state = container.read(cartNotifierProvider);
    expect(state.items, isEmpty);
    expect(state.total, 0);
  });
}

