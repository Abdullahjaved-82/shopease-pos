import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/features/invoices/domain/document_models.dart';

class InvoiceListEntry {
  const InvoiceListEntry({
    required this.invoice,
    this.customerName,
    required this.totalPaid,
    required this.remaining,
    required this.computedStatus,
  });

  final Invoice invoice;
  final String? customerName;
  final double totalPaid;
  final double remaining;
  final String computedStatus;
}

class OverdueInvoiceSummary {
  const OverdueInvoiceSummary({required this.count, required this.totalAmount});

  final int count;
  final double totalAmount;
}

class InvoiceRepository {
  InvoiceRepository(this._db);

  final AppDatabase _db;

  Stream<List<InvoiceListEntry>> watchInvoices({
    String? status,
    int? customerId,
    DateTime? startDate,
    DateTime? endDate,
    DocumentType? docType,
  }) {
    final query = _db.select(_db.invoices).join([
      leftOuterJoin(_db.customers, _db.customers.id.equalsExp(_db.invoices.customerId)),
      leftOuterJoin(_db.invoicePayments, _db.invoicePayments.invoiceId.equalsExp(_db.invoices.id)),
    ]);

    if (customerId != null) {
      query.where(_db.invoices.customerId.equals(customerId));
    }
    if (docType != null) {
      query.where(_db.invoices.docType.equals(docType.dbValue));
    }
    if (startDate != null) {
      query.where(_db.invoices.issueDate.isBiggerOrEqualValue(_atStartOfDay(startDate)));
    }
    if (endDate != null) {
      query.where(_db.invoices.issueDate.isSmallerOrEqualValue(_atEndOfDay(endDate)));
    }

    query.orderBy([
      OrderingTerm(expression: _db.invoices.issueDate, mode: OrderingMode.desc),
      OrderingTerm(expression: _db.invoices.id, mode: OrderingMode.desc),
    ]);

    return query.watch().map((rows) {
      final grouped = <int, _InvoiceBucket>{};
      for (final row in rows) {
        final invoice = row.readTable(_db.invoices);
        final customerName = row.readTableOrNull(_db.customers)?.name;
        final payment = row.readTableOrNull(_db.invoicePayments);

        final bucket = grouped.putIfAbsent(
          invoice.id,
          () => _InvoiceBucket(invoice: invoice, customerName: customerName),
        );
        bucket.totalPaid += payment?.amount ?? 0.0;
      }

      var list = grouped.values.map((bucket) {
        final remaining = math.max(0.0, bucket.invoice.total - bucket.totalPaid).toDouble();
        final computed = _statusFor(bucket.invoice, remaining);
        return InvoiceListEntry(
          invoice: bucket.invoice,
          customerName: bucket.customerName,
          totalPaid: bucket.totalPaid,
          remaining: remaining,
          computedStatus: computed,
        );
      }).toList();

      if (status != null && status.isNotEmpty && status != 'all') {
        list = list.where((entry) => entry.computedStatus == status).toList();
      }

      return list;
    });
  }

  Stream<OverdueInvoiceSummary> watchOverdueSummary() {
    return watchInvoices(status: 'overdue', docType: DocumentType.invoice).map(
      (list) => OverdueInvoiceSummary(
        count: list.length,
        totalAmount: list.fold<double>(0, (sum, item) => sum + item.remaining),
      ),
    );
  }

  Future<Invoice?> getInvoiceById(int id) {
    return (_db.select(_db.invoices)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<InvoiceItem>> getItemsByInvoiceId(int invoiceId) {
    return (_db.select(_db.invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).get();
  }

  Future<String> getNextDocumentNumber(DocumentType type) async {
    final key = 'seq_${type.prefix}';
    final current = await (_db.select(_db.appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
    final seq = int.tryParse(current?.value ?? '0') ?? 0;
    final next = seq + 1;

    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(
            key: Value(key),
            value: Value(next.toString()),
          ),
        );

    return '${type.prefix}-${next.toString().padLeft(4, '0')}';
  }

  Future<int> createInvoice({
    required InvoicesCompanion invoice,
    required List<InvoiceItemsCompanion> items,
  }) {
    return _db.transaction(() async {
      final invoiceId = await _db.into(_db.invoices).insert(invoice);
      if (items.isNotEmpty) {
        final mapped = items.map((item) => item.copyWith(invoiceId: Value(invoiceId))).toList();
        await _db.batch((batch) => batch.insertAll(_db.invoiceItems, mapped));
      }
      return invoiceId;
    });
  }

  Future<void> updateInvoice({
    required InvoicesCompanion invoice,
    required List<InvoiceItemsCompanion> items,
  }) async {
    await _db.transaction(() async {
      await _db.update(_db.invoices).replace(invoice);
      final id = invoice.id.value;
      await (_db.delete(_db.invoiceItems)..where((t) => t.invoiceId.equals(id))).go();
      if (items.isNotEmpty) {
        final mapped = items.map((item) => item.copyWith(invoiceId: Value(id))).toList();
        await _db.batch((batch) => batch.insertAll(_db.invoiceItems, mapped));
      }
    });
  }

  Future<int> updateStatus({required int invoiceId, required String status}) {
    return (_db.update(_db.invoices)..where((t) => t.id.equals(invoiceId))).write(
      InvoicesCompanion(status: Value(status)),
    );
  }

  Future<void> markAsSent(int invoiceId) async {
    await (_db.update(_db.invoices)..where((t) => t.id.equals(invoiceId))).write(
      InvoicesCompanion(status: const Value('sent'), sentAt: Value(DateTime.now())),
    );
  }

  Future<int> duplicateInvoice(int invoiceId) async {
    return _db.transaction(() async {
      final invoice = await getInvoiceById(invoiceId);
      if (invoice == null) return 0;
      final items = await getItemsByInvoiceId(invoiceId);
      final type = DocumentType.fromDb(invoice.docType);
      final newNumber = await getNextDocumentNumber(type);

      final newId = await _db.into(_db.invoices).insert(
            InvoicesCompanion.insert(
              invoiceNumber: newNumber,
              customerId: Value(invoice.customerId),
              linkedSaleId: const Value.absent(),
              docType: Value(invoice.docType),
              billToName: Value(invoice.billToName),
              billToAddress: Value(invoice.billToAddress),
              billToPhone: Value(invoice.billToPhone),
              status: const Value('draft'),
              template: Value(invoice.template),
              invoiceLanguage: Value(invoice.invoiceLanguage),
              currencyCode: Value(invoice.currencyCode),
              exchangeRateToPkr: Value(invoice.exchangeRateToPkr),
              sentAt: const Value.absent(),
              issueDate: DateTime.now(),
              dueDate: Value(invoice.dueDate),
              expiryDate: Value(invoice.expiryDate),
              subtotal: Value(invoice.subtotal),
              discountAmount: Value(invoice.discountAmount),
              taxAmount: Value(invoice.taxAmount),
              total: Value(invoice.total),
              notes: Value(invoice.notes),
              terms: Value(invoice.terms),
            ),
          );

      if (items.isNotEmpty) {
        final copied = items
            .map(
              (item) => InvoiceItemsCompanion.insert(
                invoiceId: newId,
                description: item.description,
                qty: Value(item.qty),
                unitPrice: Value(item.unitPrice),
                lineTotal: Value(item.lineTotal),
              ),
            )
            .toList();
        await _db.batch((batch) => batch.insertAll(_db.invoiceItems, copied));
      }
      return newId;
    });
  }

  Future<int> convertQuotationToInvoice(int quotationId) async {
    final q = await getInvoiceById(quotationId);
    if (q == null || q.docType != DocumentType.quotation.dbValue) return 0;
    final id = await duplicateInvoice(quotationId);
    if (id <= 0) return 0;
    final newNo = await getNextDocumentNumber(DocumentType.invoice);
    await (_db.update(_db.invoices)..where((t) => t.id.equals(id))).write(
      InvoicesCompanion(
        invoiceNumber: Value(newNo),
        docType: Value(DocumentType.invoice.dbValue),
        dueDate: Value(q.expiryDate),
        expiryDate: const Value.absent(),
        status: const Value('draft'),
      ),
    );
    return id;
  }

  Future<int> convertProformaToInvoice(int proformaId) async {
    final p = await getInvoiceById(proformaId);
    if (p == null || p.docType != DocumentType.proforma.dbValue) return 0;
    final id = await duplicateInvoice(proformaId);
    if (id <= 0) return 0;
    final newNo = await getNextDocumentNumber(DocumentType.invoice);
    await (_db.update(_db.invoices)..where((t) => t.id.equals(id))).write(
      InvoicesCompanion(
        invoiceNumber: Value(newNo),
        docType: Value(DocumentType.invoice.dbValue),
        status: const Value('draft'),
      ),
    );
    return id;
  }

  Future<int?> convertToSale(int invoiceId, {required int userId}) async {
    return _db.transaction(() async {
      final invoice = await getInvoiceById(invoiceId);
      if (invoice == null || invoice.docType != DocumentType.invoice.dbValue) return null;
      if (invoice.linkedSaleId != null) return invoice.linkedSaleId;

      final items = await getItemsByInvoiceId(invoiceId);
      final saleId = await _db.into(_db.sales).insert(
            SalesCompanion.insert(
              customerId: Value(invoice.customerId),
              totalAmount: invoice.total,
              discount: Value(invoice.discountAmount),
              paymentMethod: Value('invoice'),
              paidAmount: Value(0),
              changeAmount: Value(0),
              userId: userId,
              note: Value('Converted from ${invoice.invoiceNumber}'),
            ),
          );

      for (final item in items) {
        final product = await (_db.select(_db.products)..where((p) => p.name.equals(item.description))..limit(1)).getSingleOrNull();
        if (product == null) continue;
        await _db.into(_db.saleItems).insert(
              SaleItemsCompanion.insert(
                saleId: saleId,
                productId: product.id,
                quantity: Value(item.qty <= 1 ? 1 : item.qty.round()),
                unitPrice: item.unitPrice,
                discount: Value(0),
                lineTotal: Value(item.lineTotal),
              ),
            );
      }

      await (_db.update(_db.invoices)..where((t) => t.id.equals(invoiceId))).write(InvoicesCompanion(linkedSaleId: Value(saleId)));
      return saleId;
    });
  }

  Stream<List<RecurringInvoice>> watchRecurring() {
    final q = _db.select(_db.recurringInvoices)..orderBy([(t) => OrderingTerm(expression: t.nextRunDate)]);
    return q.watch();
  }

  Future<void> upsertRecurring({
    required int templateInvoiceId,
    required RecurringFrequency frequency,
    required DateTime startDate,
    bool active = true,
  }) async {
    final existing = await (_db.select(_db.recurringInvoices)..where((t) => t.templateInvoiceId.equals(templateInvoiceId))).getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.recurringInvoices).insert(
            RecurringInvoicesCompanion.insert(
              templateInvoiceId: templateInvoiceId,
              frequency: frequency.dbValue,
              nextRunDate: startDate,
              active: Value(active),
            ),
          );
    } else {
      await (_db.update(_db.recurringInvoices)..where((t) => t.id.equals(existing.id))).write(
        RecurringInvoicesCompanion(
          frequency: Value(frequency.dbValue),
          nextRunDate: Value(startDate),
          active: Value(active),
        ),
      );
    }
  }

  Future<void> setRecurringActive(int recurringId, bool active) {
    return (_db.update(_db.recurringInvoices)..where((t) => t.id.equals(recurringId))).write(RecurringInvoicesCompanion(active: Value(active)));
  }

  Future<void> runRecurringInvoicesNow() async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final due = await (_db.select(_db.recurringInvoices)..where((r) => r.active.equals(true) & r.nextRunDate.isSmallerOrEqualValue(day))).get();

    for (final r in due) {
      final newId = await duplicateInvoice(r.templateInvoiceId);
      if (newId > 0) {
        await (_db.update(_db.invoices)..where((t) => t.id.equals(newId))).write(
          InvoicesCompanion(
            issueDate: Value(day),
            status: const Value('draft'),
          ),
        );
      }
      final next = _advanceDate(r.nextRunDate, RecurringFrequency.fromDb(r.frequency));
      await (_db.update(_db.recurringInvoices)..where((t) => t.id.equals(r.id))).write(
        RecurringInvoicesCompanion(
          lastRunDate: Value(day),
          nextRunDate: Value(next),
        ),
      );
    }
  }

  Future<int> deleteInvoice(int invoiceId) {
    return _db.transaction(() async {
      await (_db.delete(_db.recurringInvoices)..where((t) => t.templateInvoiceId.equals(invoiceId))).go();
      await (_db.delete(_db.invoicePayments)..where((t) => t.invoiceId.equals(invoiceId))).go();
      await (_db.delete(_db.invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).go();
      return (_db.delete(_db.invoices)..where((t) => t.id.equals(invoiceId))).go();
    });
  }

  String _statusFor(Invoice invoice, double remaining) {
    final type = DocumentType.fromDb(invoice.docType);
    if (type == DocumentType.quotation) {
      if (invoice.status == 'accepted' || invoice.status == 'rejected') return invoice.status;
      final exp = invoice.expiryDate;
      if (exp != null) {
        final today = DateTime.now();
        final nowDay = DateTime(today.year, today.month, today.day);
        final expDay = DateTime(exp.year, exp.month, exp.day);
        if (expDay.isBefore(nowDay)) return 'expired';
      }
      return invoice.status == 'draft' ? 'draft' : 'sent';
    }

    if (remaining <= 0.0001) return 'paid';
    if (invoice.status == 'draft') return 'draft';

    final due = invoice.dueDate;
    if (due != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(due.year, due.month, due.day);
      if (dueDay.isBefore(today)) return 'overdue';
    }

    if (invoice.status == 'paid') return 'paid';
    if (remaining < invoice.total) return 'partial';
    return 'sent';
  }

  DateTime _advanceDate(DateTime from, RecurringFrequency frequency) {
    return switch (frequency) {
      RecurringFrequency.weekly => from.add(const Duration(days: 7)),
      RecurringFrequency.monthly => DateTime(from.year, from.month + 1, from.day),
      RecurringFrequency.quarterly => DateTime(from.year, from.month + 3, from.day),
    };
  }

  DateTime _atStartOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime _atEndOfDay(DateTime date) => DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}

class _InvoiceBucket {
  _InvoiceBucket({required this.invoice, required this.customerName});

  final Invoice invoice;
  final String? customerName;
  double totalPaid = 0;
}

