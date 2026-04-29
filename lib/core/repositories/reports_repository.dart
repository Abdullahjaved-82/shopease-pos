import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:pos_system/core/database/app_database.dart';

class DailySummary {
  DailySummary({
    required this.totalSales,
    required this.totalCost,
    required this.grossProfit,
    required this.totalDiscount,
    required this.txCount,
    required this.topProducts,
  });

  final double totalSales;
  final double totalCost;
  final double grossProfit;
  final double totalDiscount;
  final int txCount;
  final List<TopProduct> topProducts;
}

class TopProduct {
  TopProduct({required this.name, required this.qty, required this.revenue, required this.profit});
  final String name;
  final int qty;
  final double revenue;
  final double profit;
}

class DailyRevenueRow {
  DailyRevenueRow({required this.date, required this.revenue, required this.profit});
  final DateTime date;
  final double revenue;
  final double profit;
}

class ExpenseSummary {
  ExpenseSummary({required this.total, required this.byCategory});
  final double total;
  final Map<String, double> byCategory;
}

class RangeSummary {
  RangeSummary({required this.revenue, required this.cost, required this.discount});
  final double revenue;
  final double cost;
  final double discount;
  double get grossProfit => revenue - cost;
}

class ReportsRepository {
  ReportsRepository(this._db);
  final AppDatabase _db;

  Future<DailySummary> getDailySummary(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _db.customSelect(
      '''
      SELECT 
        SUM(s.total_amount) AS totalSales,
        SUM(si.quantity * p.cost_price) AS totalCost,
        SUM(s.discount) AS totalDiscount,
        COUNT(*) AS txCount
      FROM sales s
      LEFT JOIN sale_items si ON s.id = si.sale_id
      LEFT JOIN products p ON si.product_id = p.id
      WHERE s.created_at >= ? AND s.created_at < ?
      ''',
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
    ).getSingle();

    final totalSales = rows.data['totalSales'] as double? ?? 0;
    final totalCost = rows.data['totalCost'] as double? ?? 0;
    final totalDiscount = rows.data['totalDiscount'] as double? ?? 0;
    final txCount = rows.data['txCount'] as int? ?? 0;
    final grossProfit = totalSales - totalCost;

    final topProducts = await getTopProducts(start, end, 5);

    return DailySummary(
      totalSales: totalSales,
      totalCost: totalCost,
      grossProfit: grossProfit,
      totalDiscount: totalDiscount,
      txCount: txCount,
      topProducts: topProducts,
    );
  }

  Future<List<DailyRevenueRow>> getMonthlySummary(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final rows = await _db.customSelect(
      '''
      SELECT DATE(s.created_at) AS day, SUM(s.total_amount) AS revenue, SUM(s.total_amount - s.discount) - SUM(si.quantity * p.cost_price) AS profit
      FROM sales s
      LEFT JOIN sale_items si ON s.id = si.sale_id
      LEFT JOIN products p ON si.product_id = p.id
      WHERE s.created_at >= ? AND s.created_at < ?
      GROUP BY day
      ORDER BY day
      ''',
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
    ).get();

    return rows.map((row) {
      final dayStr = row.data['day'] as String;
      final date = DateFormat('yyyy-MM-dd').parse(dayStr);
      return DailyRevenueRow(
        date: date,
        revenue: row.data['revenue'] as double? ?? 0,
        profit: row.data['profit'] as double? ?? 0,
      );
    }).toList();
  }

  Future<List<TopProduct>> getTopProducts(DateTime start, DateTime end, int limit) async {
    final rows = await _db.customSelect(
      '''
      SELECT p.name AS name, SUM(si.quantity) AS qty, SUM(si.line_total) AS revenue, SUM(si.quantity * p.cost_price) AS cost
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      JOIN products p ON p.id = si.product_id
      WHERE s.created_at >= ? AND s.created_at < ?
      GROUP BY p.id
      ORDER BY qty DESC
      LIMIT ?
      ''',
      variables: [Variable<DateTime>(start), Variable<DateTime>(end), Variable<int>(limit)],
    ).get();

    return rows
        .map(
          (row) => TopProduct(
            name: row.data['name'] as String? ?? 'Unknown',
            qty: (row.data['qty'] as int?) ?? ((row.data['qty'] as double?)?.toInt() ?? 0),
            revenue: row.data['revenue'] as double? ?? 0,
            profit: (row.data['revenue'] as double? ?? 0) - (row.data['cost'] as double? ?? 0),
          ),
        )
        .toList();
  }

  Future<ExpenseSummary> getExpenseSummary(DateTime start, DateTime end) async {
    final rows = await _db.customSelect(
      '''
      SELECT COALESCE(category, 'Uncategorized') AS category, SUM(amount) AS total
      FROM expenses
      WHERE incurred_on >= ? AND incurred_on < ?
      GROUP BY category
      ''',
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
    ).get();

    final map = <String, double>{};
    double total = 0;
    for (final row in rows) {
      final cat = row.data['category'] as String? ?? 'Uncategorized';
      final value = row.data['total'] as double? ?? 0;
      map[cat] = value;
      total += value;
    }
    return ExpenseSummary(total: total, byCategory: map);
  }

  Future<RangeSummary> getRangeSummary(DateTime start, DateTime end) async {
    final row = await _db.customSelect(
      '''
      SELECT SUM(s.total_amount) AS revenue, SUM(si.quantity * p.cost_price) AS cost, SUM(s.discount) AS discount
      FROM sales s
      LEFT JOIN sale_items si ON s.id = si.sale_id
      LEFT JOIN products p ON si.product_id = p.id
      WHERE s.created_at >= ? AND s.created_at < ?
      ''',
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
    ).getSingle();
    final revenue = row.data['revenue'] as double? ?? 0;
    final cost = row.data['cost'] as double? ?? 0;
    final discount = row.data['discount'] as double? ?? 0;
    return RangeSummary(revenue: revenue, cost: cost, discount: discount);
  }

  Future<List<DailyRevenueRow>> getDailyRevenueBetween(DateTime start, DateTime end) async {
    final rows = await _db.customSelect(
      '''
      SELECT DATE(s.created_at) AS day, SUM(s.total_amount) AS revenue, SUM(s.total_amount - s.discount) - SUM(si.quantity * p.cost_price) AS profit
      FROM sales s
      LEFT JOIN sale_items si ON s.id = si.sale_id
      LEFT JOIN products p ON si.product_id = p.id
      WHERE s.created_at >= ? AND s.created_at < ?
      GROUP BY day
      ORDER BY day
      ''',
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
    ).get();

    return rows.map((row) {
      final dayStr = row.data['day'] as String;
      final date = DateFormat('yyyy-MM-dd').parse(dayStr);
      return DailyRevenueRow(
        date: date,
        revenue: row.data['revenue'] as double? ?? 0,
        profit: row.data['profit'] as double? ?? 0,
      );
    }).toList();
  }

  Future<List<Map<String, Object?>>> getSalesRows(DateTime start, DateTime end) {
    return _db.customSelect(
      '''
      SELECT s.id, s.total_amount, s.discount, s.payment_method, s.paid_amount, s.change_amount, s.created_at
      FROM sales s
      WHERE s.created_at >= ? AND s.created_at < ?
      ORDER BY s.created_at
      ''',
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
      readsFrom: { _db.sales },
    ).map((row) => row.data).get();
  }
}


