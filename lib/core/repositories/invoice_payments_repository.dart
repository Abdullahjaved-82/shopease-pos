import 'package:drift/drift.dart';
import 'package:pos_system/core/database/app_database.dart';

class InvoicePaymentsRepository {
  InvoicePaymentsRepository(this._db);

  final AppDatabase _db;

  Stream<List<InvoicePayment>> watchByInvoice(int invoiceId) {
    final query = _db.select(_db.invoicePayments)..where((t) => t.invoiceId.equals(invoiceId));
    query.orderBy([(t) => OrderingTerm(expression: t.paidAt, mode: OrderingMode.desc)]);
    return query.watch();
  }

  Future<double> getRemainingBalance(int invoiceId) async {
    final invoice = await (_db.select(_db.invoices)..where((t) => t.id.equals(invoiceId))).getSingleOrNull();
    if (invoice == null) return 0;

    final sumExp = _db.invoicePayments.amount.sum();
    final paid = await (_db.selectOnly(_db.invoicePayments)
          ..where(_db.invoicePayments.invoiceId.equals(invoiceId))
          ..addColumns([sumExp]))
        .map((row) => row.read(sumExp) ?? 0)
        .getSingle();

    final remaining = invoice.total - paid;
    return remaining < 0 ? 0 : remaining;
  }

  Future<void> recordPayment({
    required int invoiceId,
    required double amount,
    required String method,
    String? note,
    DateTime? paidAt,
  }) async {
    if (amount <= 0) return;

    await _db.transaction(() async {
      await _db.into(_db.invoicePayments).insert(
            InvoicePaymentsCompanion.insert(
              invoiceId: invoiceId,
              amount: amount,
              method: method,
              paidAt: Value(paidAt ?? DateTime.now()),
              note: Value(note),
            ),
          );

      final remaining = await getRemainingBalance(invoiceId);
      final nextStatus = remaining <= 0.0001 ? 'paid' : 'partial';
      await (_db.update(_db.invoices)..where((t) => t.id.equals(invoiceId))).write(
        InvoicesCompanion(status: Value(nextStatus)),
      );
    });
  }
}

