import 'package:drift/drift.dart';
import 'package:pos_system/core/database/app_database.dart';

class ShiftCashSummary {
  ShiftCashSummary({
    required this.shift,
    required this.cashSales,
    required this.salesByPayment,
    required this.cashIn,
    required this.cashOut,
    required this.movements,
  });

  final Shift shift;
  final double cashSales;
  final Map<String, double> salesByPayment;
  final double cashIn;
  final double cashOut;
  final List<CashMovement> movements;

  double get expectedCash => shift.openingCash + cashSales + cashIn - cashOut;
  double? get difference => shift.closingCash == null ? null : shift.closingCash! - expectedCash;
}

class ShiftsRepository {
  ShiftsRepository(this._db);

  final AppDatabase _db;

  Future<Shift?> getCurrentShift({required int userId}) async {
    final query = _db.select(_db.shifts)
      ..where((s) => s.userId.equals(userId) & s.closedAt.isNull())
      ..orderBy([(s) => OrderingTerm.desc(s.openedAt)]);
    return query.getSingleOrNull();
  }

  Stream<Shift?> watchCurrentShift({required int userId}) {
    final query = _db.select(_db.shifts)
      ..where((s) => s.userId.equals(userId) & s.closedAt.isNull())
      ..orderBy([(s) => OrderingTerm.desc(s.openedAt)]);
    return query.watch().map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<Shift> openShift({required int userId, required double openingCash}) async {
    final existing = await getCurrentShift(userId: userId);
    if (existing != null) {
      throw StateError('Shift already open');
    }
    final id = await _db.into(_db.shifts).insert(
          ShiftsCompanion.insert(
            userId: userId,
            openingCash: openingCash,
            expectedCash: Value(openingCash),
          ),
        );
    return (_db.select(_db.shifts)..where((s) => s.id.equals(id))).getSingle();
  }

  Future<Shift> closeShift({required int shiftId, required double closingCash, String? note}) async {
    return _db.transaction(() async {
      final summary = await getCashSummary(shiftId: shiftId);
      final now = DateTime.now();
      final difference = closingCash - summary.expectedCash;
      await (_db.update(_db.shifts)..where((s) => s.id.equals(shiftId))).write(
        ShiftsCompanion(
          closedAt: Value(now),
          closingCash: Value(closingCash),
          expectedCash: Value(summary.expectedCash),
          difference: Value(difference),
          note: Value(note),
        ),
      );
      return (_db.select(_db.shifts)..where((s) => s.id.equals(shiftId))).getSingle();
    });
  }

  Future<CashMovement> addCashMovement({
    required int shiftId,
    required String type,
    required double amount,
    required String reason,
  }) async {
    final id = await _db.into(_db.cashMovements).insert(
          CashMovementsCompanion.insert(
            shiftId: shiftId,
            type: type,
            amount: amount,
            reason: Value(reason),
          ),
        );
    return (_db.select(_db.cashMovements)..where((m) => m.id.equals(id))).getSingle();
  }

  Stream<List<CashMovement>> watchMovements(int shiftId) {
    final query = _db.select(_db.cashMovements)
      ..where((m) => m.shiftId.equals(shiftId))
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]);
    return query.watch();
  }

  Stream<List<Shift>> watchRecent({int limit = 25}) {
    final query = _db.select(_db.shifts)
      ..orderBy([(s) => OrderingTerm.desc(s.openedAt)])
      ..limit(limit);
    return query.watch();
  }

  Future<ShiftCashSummary> getCashSummary({required int shiftId}) async {
    final shift = await (_db.select(_db.shifts)..where((s) => s.id.equals(shiftId))).getSingle();
    final movements = await (_db.select(_db.cashMovements)..where((m) => m.shiftId.equals(shiftId))).get();
    final cashIn = movements.where((m) => m.type == 'in').fold<double>(0, (sum, m) => sum + m.amount);
    final cashOut = movements.where((m) => m.type == 'out').fold<double>(0, (sum, m) => sum + m.amount);
    final salesByPayment = await _salesByPayment(shift);
    final cashSales = salesByPayment['cash'] ?? 0;

    return ShiftCashSummary(
      shift: shift,
      cashSales: cashSales,
      salesByPayment: salesByPayment,
      cashIn: cashIn,
      cashOut: cashOut,
      movements: movements,
    );
  }

  Future<Map<String, double>> _salesByPayment(Shift shift) async {
    final start = shift.openedAt;
    final end = shift.closedAt ?? DateTime.now();
    final rows = await _db.customSelect(
      '''
      SELECT payment_method AS method, SUM(paid_amount - change_amount) AS collected
      FROM sales
      WHERE user_id = ? AND created_at >= ? AND created_at <= ?
      GROUP BY payment_method
      ''',
      variables: [
        Variable<int>(shift.userId),
        Variable<DateTime>(start),
        Variable<DateTime>(end),
      ],
      readsFrom: {_db.sales},
    ).get();

    final Map<String, double> totals = {};
    for (final row in rows) {
      final method = row.data['method'] as String? ?? 'cash';
      totals[method] = (row.data['collected'] as double?) ?? 0;
    }
    return totals;
  }
}

