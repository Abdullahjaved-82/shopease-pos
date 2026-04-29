import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/core/repositories/invoice_repository.dart';

part 'overdue_invoices_provider.g.dart';

@riverpod
Stream<List<InvoiceListEntry>> overdueInvoices(OverdueInvoicesRef ref) {
  final repo = ref.watch(invoiceRepositoryProvider);
  return repo.watchInvoices(status: 'overdue');
}

@riverpod
Stream<OverdueInvoiceSummary> overdueInvoiceSummary(OverdueInvoiceSummaryRef ref) {
  final repo = ref.watch(invoiceRepositoryProvider);
  return repo.watchOverdueSummary();
}

