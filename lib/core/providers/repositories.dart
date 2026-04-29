import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/repositories/customers_repository.dart';
import 'package:pos_system/core/repositories/expenses_repository.dart';
import 'package:pos_system/core/repositories/products_repository.dart';
import 'package:pos_system/core/repositories/sale_items_repository.dart';
import 'package:pos_system/core/repositories/sales_repository.dart';
import 'package:pos_system/core/repositories/users_repository.dart';
import 'package:pos_system/core/repositories/categories_repository.dart';
import 'package:pos_system/core/repositories/inventory_repository.dart';
import 'package:pos_system/core/repositories/reports_repository.dart';
import 'package:pos_system/core/repositories/suppliers_repository.dart';
import 'package:pos_system/core/repositories/purchase_orders_repository.dart';
import 'package:pos_system/core/repositories/shifts_repository.dart';
import 'package:pos_system/core/repositories/loyalty_repository.dart';
import 'package:pos_system/core/repositories/invoice_repository.dart';
import 'package:pos_system/core/repositories/invoice_payments_repository.dart';
import 'package:pos_system/core/repositories/dashboard_repository.dart';

part 'repositories.g.dart';

@riverpod
ProductsRepository productsRepository(ProductsRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return ProductsRepository(db);
}

@riverpod
SalesRepository salesRepository(SalesRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return SalesRepository(db);
}

@riverpod
SaleItemsRepository saleItemsRepository(SaleItemsRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return SaleItemsRepository(db);
}

@riverpod
CustomersRepository customersRepository(CustomersRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return CustomersRepository(db);
}

@riverpod
ExpensesRepository expensesRepository(ExpensesRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return ExpensesRepository(db);
}

@riverpod
UsersRepository usersRepository(UsersRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return UsersRepository(db);
}

@riverpod
CategoriesRepository categoriesRepository(CategoriesRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return CategoriesRepository(db);
}

@riverpod
InventoryRepository inventoryRepository(InventoryRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return InventoryRepository(db);
}

@riverpod
ReportsRepository reportsRepository(ReportsRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return ReportsRepository(db);
}

@riverpod
SuppliersRepository suppliersRepository(SuppliersRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return SuppliersRepository(db);
}

@riverpod
PurchaseOrdersRepository purchaseOrdersRepository(PurchaseOrdersRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return PurchaseOrdersRepository(db);
}

@riverpod
InvoiceRepository invoiceRepository(InvoiceRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return InvoiceRepository(db);
}

@riverpod
InvoicePaymentsRepository invoicePaymentsRepository(InvoicePaymentsRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return InvoicePaymentsRepository(db);
}

@riverpod
DashboardRepository dashboardRepository(DashboardRepositoryRef ref) {
  final db = ref.watch(databaseProvider);
  return DashboardRepository(db);
}

final shiftsRepositoryProvider = Provider<ShiftsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ShiftsRepository(db);
});

final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return LoyaltyRepository(db);
});

