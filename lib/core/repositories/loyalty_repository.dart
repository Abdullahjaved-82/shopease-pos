import 'package:drift/drift.dart';
import 'package:pos_system/core/database/app_database.dart';

class LoyaltySettingsModel {
  const LoyaltySettingsModel({
    required this.pointsPerRupee,
    required this.rupeePerPoint,
    required this.minRedeemPoints,
    required this.expiryDays,
  });

  final double pointsPerRupee;
  final double rupeePerPoint;
  final int minRedeemPoints;
  final int expiryDays;
}

class LoyaltyRepository {
  LoyaltyRepository(this._db);

  final AppDatabase _db;

  Future<int> getBalance(int customerId) async {
    final row = await _db.customSelect(
      'SELECT COALESCE(SUM(points), 0) AS balance FROM loyalty_transactions WHERE customer_id = ?;',
      variables: [Variable<int>(customerId)],
      readsFrom: {_db.loyaltyTransactions},
    ).getSingle();
    return (row.data['balance'] as int?) ?? ((row.data['balance'] as double?)?.toInt() ?? 0);
  }

  Stream<List<LoyaltyTransaction>> getHistory(int customerId) {
    final query = _db.select(_db.loyaltyTransactions)
      ..where((t) => t.customerId.equals(customerId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch();
  }

  Future<int> earnPoints({required int customerId, required int saleId, required double saleTotal, required LoyaltySettingsModel settings}) async {
    final points = (saleTotal * settings.pointsPerRupee).floor();
    if (points <= 0) return 0;
    await _insertTransaction(
      customerId: customerId,
      points: points,
      type: 'earn',
      saleId: saleId,
      note: 'Sale $saleId',
    );
    return points;
  }

  Future<double> redeemPoints({
    required int customerId,
    required int saleId,
    required int points,
    required LoyaltySettingsModel settings,
  }) async {
    if (points <= 0) return 0;
    await _insertTransaction(
      customerId: customerId,
      points: -points,
      type: 'redeem',
      saleId: saleId,
      note: 'Sale $saleId',
    );
    return points * settings.rupeePerPoint;
  }

  Future<void> adjustPoints({required int customerId, required int points, String? note}) {
    return _insertTransaction(customerId: customerId, points: points, type: 'adjust', saleId: null, note: note);
  }

  Future<void> _insertTransaction({
    required int customerId,
    required int points,
    required String type,
    int? saleId,
    String? note,
  }) async {
    await _db.into(_db.loyaltyTransactions).insert(
          LoyaltyTransactionsCompanion.insert(
            customerId: customerId,
            points: points,
            type: type,
            saleId: Value(saleId),
            note: Value(note),
          ),
        );
  }
}

