import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/core/repositories/dashboard_repository.dart';

final dashboardTodaySummaryProvider = StreamProvider<DashboardTodaySummary>((ref) {
  return ref.watch(dashboardRepositoryProvider).getTodaySummary();
});

final dashboardWeeklySalesProvider = StreamProvider<List<WeeklySalesPoint>>((ref) {
  return ref.watch(dashboardRepositoryProvider).getWeeklySales();
});

final dashboardTopProductsProvider = StreamProvider<List<TopProductToday>>((ref) {
  return ref.watch(dashboardRepositoryProvider).getTopProductsToday(5);
});

final dashboardRecentTransactionsProvider = StreamProvider<List<Sale>>((ref) {
  return ref.watch(dashboardRepositoryProvider).getRecentTransactions(limit: 10);
});

final dashboardLowStockProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(dashboardRepositoryProvider).getLowStockAlerts();
});

