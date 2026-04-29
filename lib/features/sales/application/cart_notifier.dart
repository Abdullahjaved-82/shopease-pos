import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';
import 'package:pos_system/core/repositories/loyalty_repository.dart';
import 'package:pos_system/features/settings/application/shop_settings_controller.dart';

part 'cart_notifier.g.dart';

enum PaymentMethod { cash, easypaisa, jazzcash, bank, credit }

class CartItem {
  CartItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.lineDiscountPercent = 0,
  });

  final int productId;
  final String name;
  final double unitPrice;
  final int quantity;
  final double lineDiscountPercent;

  double get lineSubtotal => unitPrice * quantity;
  double get lineDiscountAmount => lineSubtotal * (lineDiscountPercent.clamp(0, 100) / 100);
  double get lineTotal => lineSubtotal - lineDiscountAmount;

  CartItem copyWith({
    int? productId,
    String? name,
    double? unitPrice,
    int? quantity,
    double? lineDiscountPercent,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      lineDiscountPercent: lineDiscountPercent ?? this.lineDiscountPercent,
    );
  }
}

class CartState {
  CartState({
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.total,
    required this.amountTendered,
    required this.change,
    required this.orderDiscountPercent,
    required this.paymentMethod,
    this.customerId,
    this.redeemedPoints = 0,
    this.loyaltyDiscount = 0,
  });

  final List<CartItem> items;
  final double subtotal;
  final double discountAmount;
  final double total;
  final double amountTendered;
  final double change;
  final double orderDiscountPercent;
  final PaymentMethod paymentMethod;
  final int? customerId;
  final int redeemedPoints;
  final double loyaltyDiscount;

  factory CartState.initial() => CartState(
        items: const [],
        subtotal: 0,
        discountAmount: 0,
        total: 0,
        amountTendered: 0,
        change: 0,
        orderDiscountPercent: 0,
        paymentMethod: PaymentMethod.cash,
        customerId: null,
        redeemedPoints: 0,
        loyaltyDiscount: 0,
      );

  CartState copyWith({
    List<CartItem>? items,
    double? subtotal,
    double? discountAmount,
    double? total,
    double? amountTendered,
    double? change,
    double? orderDiscountPercent,
    PaymentMethod? paymentMethod,
    int? customerId,
    int? redeemedPoints,
    double? loyaltyDiscount,
  }) {
    return CartState(
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      total: total ?? this.total,
      amountTendered: amountTendered ?? this.amountTendered,
      change: change ?? this.change,
      orderDiscountPercent: orderDiscountPercent ?? this.orderDiscountPercent,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: customerId ?? this.customerId,
      redeemedPoints: redeemedPoints ?? this.redeemedPoints,
      loyaltyDiscount: loyaltyDiscount ?? this.loyaltyDiscount,
    );
  }
}

@riverpod
class CartNotifier extends _$CartNotifier {
  @override
  CartState build() => CartState.initial();

  void addItem(Product product) {
    final existingIndex = state.items.indexWhere((i) => i.productId == product.id);
    final List<CartItem> updated = List.from(state.items);
    if (existingIndex != -1) {
      final existing = updated[existingIndex];
      updated[existingIndex] = existing.copyWith(quantity: existing.quantity + 1);
    } else {
      updated.add(CartItem(
        productId: product.id,
        name: product.name,
        unitPrice: product.salePrice,
        quantity: 1,
      ));
    }
    state = _recalculate(state.copyWith(items: updated));
  }

  void removeItem(int productId) {
    final updated = state.items.where((i) => i.productId != productId).toList();
    state = _recalculate(state.copyWith(items: updated));
  }

  void updateQty(int productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    final List<CartItem> updated = state.items.map((i) {
      if (i.productId == productId) {
        return i.copyWith(quantity: quantity);
      }
      return i;
    }).toList();
    state = _recalculate(state.copyWith(items: updated));
  }

  void setLineDiscount(int productId, double percent) {
    final clamped = percent.clamp(0, 100);
    final List<CartItem> updated = state.items.map((i) {
      if (i.productId == productId) {
        return i.copyWith(lineDiscountPercent: clamped.toDouble());
      }
      return i;
    }).toList();
    state = _recalculate(state.copyWith(items: updated));
  }

  void setOrderDiscount(double percent) {
    final clamped = percent.clamp(0, 100).toDouble();
    state = _recalculate(state.copyWith(orderDiscountPercent: clamped));
  }

  void setPaymentMethod(PaymentMethod method) {
    state = _recalculate(state.copyWith(paymentMethod: method, amountTendered: method == PaymentMethod.credit ? 0 : state.amountTendered));
  }

  void setCustomer(int? customerId) {
    state = state.copyWith(customerId: customerId);
  }

  void setAmountTendered(double amount) {
    state = _recalculate(state.copyWith(amountTendered: max(0, amount)));
  }

  void clear() {
    state = CartState.initial();
  }

  void applyLoyalty({required int points, required double discount}) {
    state = _recalculate(
      state.copyWith(
        redeemedPoints: points,
        loyaltyDiscount: discount,
      ),
    );
  }

  Future<int> chargeAndPersist() async {
    if (state.items.isEmpty) {
      throw StateError('Cart is empty');
    }
    if (state.total <= 0) {
      throw StateError('Total must be greater than zero');
    }
    final isCredit = state.paymentMethod == PaymentMethod.credit;
    if (!isCredit && state.amountTendered + 1e-6 < state.total) {
      throw StateError('Insufficient amount tendered');
    }
    if (isCredit && state.customerId == null) {
      throw StateError('Select a customer for credit sale');
    }

    final auth = ref.read(authControllerProvider);
    final userId = auth.userId;
    if (userId == null) {
      throw StateError('No user in session');
    }

    final db = ref.read(databaseProvider);
    final inventory = ref.read(inventoryRepositoryProvider);

    final saleId = await db.transaction(() async {
      final saleRowId = await db.into(db.sales).insert(
            SalesCompanion(
              customerId: isCredit && state.customerId != null ? Value(state.customerId!) : const Value.absent(),
              totalAmount: Value(state.total),
              discount: Value(state.discountAmount + state.loyaltyDiscount),
              paymentMethod: Value(state.paymentMethod.name),
              paidAmount: Value(isCredit ? 0 : state.amountTendered),
              changeAmount: Value(isCredit ? 0 : state.change),
              userId: Value(userId),
              note: const Value.absent(),
            ),
          );

      for (final item in state.items) {
        await db.into(db.saleItems).insert(
              SaleItemsCompanion(
                saleId: Value(saleRowId),
                productId: Value(item.productId),
                quantity: Value(item.quantity),
                unitPrice: Value(item.unitPrice),
                discount: Value(item.lineDiscountAmount),
                lineTotal: Value(item.lineTotal),
              ),
            );
        await inventory.recordMovement(
          productId: item.productId,
          type: 'sale',
          qty: -item.quantity,
          note: 'Sale $saleRowId',
          userId: userId,
        );
      }
      if (isCredit && state.customerId != null) {
        final customersRepo = ref.read(customersRepositoryProvider);
        await customersRepo.applyCharge(customerId: state.customerId!, amount: state.total);
      }
      if (state.customerId != null && state.redeemedPoints > 0) {
        final loyaltyRepo = ref.read(loyaltyRepositoryProvider);
        final settings = await ref.read(shopSettingsControllerProvider.future);
        await loyaltyRepo.redeemPoints(
          customerId: state.customerId!,
          saleId: saleRowId,
          points: state.redeemedPoints,
          settings: LoyaltySettingsModel(
            pointsPerRupee: settings.pointsPerRupee,
            rupeePerPoint: settings.rupeePerPoint,
            minRedeemPoints: settings.minRedeemPoints,
            expiryDays: settings.expiryDays,
          ),
        );
      }
      if (state.customerId != null) {
        final loyaltyRepo = ref.read(loyaltyRepositoryProvider);
        final settings = await ref.read(shopSettingsControllerProvider.future);
        await loyaltyRepo.earnPoints(
          customerId: state.customerId!,
          saleId: saleRowId,
          saleTotal: state.total,
          settings: LoyaltySettingsModel(
            pointsPerRupee: settings.pointsPerRupee,
            rupeePerPoint: settings.rupeePerPoint,
            minRedeemPoints: settings.minRedeemPoints,
            expiryDays: settings.expiryDays,
          ),
        );
      }
      return saleRowId;
    });

    clear();
    return saleId;
  }

  CartState _recalculate(CartState draft) {
    final subtotal = draft.items.fold<double>(0, (sum, item) => sum + item.lineSubtotal);
    final lineDiscountTotal = draft.items.fold<double>(0, (sum, item) => sum + item.lineDiscountAmount);
    final afterLine = subtotal - lineDiscountTotal;
    final orderDiscountAmount = afterLine * (draft.orderDiscountPercent / 100);
    final discountAmount = lineDiscountTotal + orderDiscountAmount;
    final totalBeforeLoyalty = max(0, subtotal - discountAmount).toDouble();
    final totalAfterLoyalty = max(0, totalBeforeLoyalty - draft.loyaltyDiscount).toDouble();
    final change = max(0, draft.amountTendered - totalAfterLoyalty).toDouble();

    return draft.copyWith(
      subtotal: subtotal,
      discountAmount: discountAmount,
      total: totalAfterLoyalty,
      change: change,
    );
  }
}


