import 'dart:async';

import 'package:drift/drift.dart';
import 'package:pos_system/core/database/app_database.dart';

class DashboardTodaySummary {
  const DashboardTodaySummary({
    required this.todaySales,
    required this.todayProfit,
    required this.transactionsCount,
    required this.itemsSold,
  });

  final double todaySales;
  final double todayProfit;
  final int transactionsCount;
  final int itemsSold;
}

class WeeklySalesPoint {
  const WeeklySalesPoint({required this.date, required this.revenue});

  final DateTime date;
  final double revenue;
}

class TopProductToday {
  const TopProductToday({required this.name, required this.qty});

  final String name;
  final int qty;
}

class DashboardRepository {
  DashboardRepository(this._db);

  final AppDatabase _db;

  Stream<DashboardTodaySummary> getTodaySummary() async* {
    yield await _fetchTodaySummary();
    yield* Stream.periodic(const Duration(seconds: 30)).asyncMap((_) => _fetchTodaySummary());
  }

  Stream<List<WeeklySalesPoint>> getWeeklySales() async* {
    yield await _fetchWeeklySales();
    yield* Stream.periodic(const Duration(seconds: 30)).asyncMap((_) => _fetchWeeklySales());
  }

  Stream<List<TopProductToday>> getTopProductsToday(int limit) async* {
    yield await _fetchTopProductsToday(limit);
    yield* Stream.periodic(const Duration(seconds: 30)).asyncMap((_) => _fetchTopProductsToday(limit));
  }

  Stream<List<Sale>> getRecentTransactions({int limit = 10}) {
    final query = _db.select(_db.sales)
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])
      ..limit(limit);
    return query.watch();
  }

  Stream<List<Product>> getLowStockAlerts() {
    final query = _db.select(_db.products)
      ..where((p) => p.stockQuantity.isSmallerThan(p.reorderLevel))
      ..orderBy([(p) => OrderingTerm.asc(p.stockQuantity)]);
    return query.watch();
  }

  Future<DashboardTodaySummary> _fetchTodaySummary() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final row = await _db.customSelect(
      '''
      SELECT
        COALESCE(SUM(s.total_amount), 0) AS sales,
        COALESCE(SUM(si.line_total - (si.quantity * p.cost_price)), 0) AS profit,
        COUNT(DISTINCT s.id) AS tx_count,
        COALESCE(SUM(si.quantity), 0) AS items_sold
      FROM sales s
      LEFT JOIN sale_items si ON si.sale_id = s.id
      LEFT JOIN products p ON p.id = si.product_id
      WHERE s.created_at >= ? AND s.created_at < ?
      ''',
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
      readsFrom: {_db.sales, _db.saleItems, _db.products},
    ).getSingle();

    return DashboardTodaySummary(
      todaySales: _asDouble(row.data['sales']),
      todayProfit: _asDouble(row.data['profit']),
      transactionsCount: _asInt(row.data['tx_count']),
      itemsSold: _asInt(row.data['items_sold']),
    );
  }

  Future<List<WeeklySalesPoint>> _fetchWeeklySales() async {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 7));

    final rows = await _db.customSelect(
      '''
      SELECT DATE(s.created_at) AS day, COALESCE(SUM(s.total_amount), 0) AS revenue
      FROM sales s
      WHERE s.created_at >= ? AND s.created_at < ?
      GROUP BY day
      ORDER BY day ASC
      ''',
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
      readsFrom: {_db.sales},
    ).get();

    final byDay = <String, double>{
      for (final row in rows) (row.data['day'] as String): _asDouble(row.data['revenue']),
    };

    return List.generate(7, (i) {
      final date = DateTime(start.year, start.month, start.day + i);
      final key = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return WeeklySalesPoint(date: date, revenue: byDay[key] ?? 0.0);
    });
  }

  Future<List<TopProductToday>> _fetchTopProductsToday(int limit) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final rows = await _db.customSelect(
      '''
      SELECT p.name AS name, COALESCE(SUM(si.quantity), 0) AS qty
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      JOIN products p ON p.id = si.product_id
      WHERE s.created_at >= ? AND s.created_at < ?
      GROUP BY p.id
      ORDER BY qty DESC
      LIMIT ?
      ''',
      variables: [Variable<DateTime>(start), Variable<DateTime>(end), Variable<int>(limit)],
      readsFrom: {_db.sales, _db.saleItems, _db.products},
    ).get();

    return rows
        .map(
          (row) => TopProductToday(
            name: (row.data['name'] as String?) ?? 'Unknown',
            qty: _asInt(row.data['qty']),
          ),
        )
        .toList();
  }

  double _asDouble(Object? v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  int _asInt(Object? v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

