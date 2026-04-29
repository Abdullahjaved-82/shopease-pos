import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/providers/repositories.dart';

class RecurringInvoiceService {
  RecurringInvoiceService(this._ref);

  final Ref _ref;

  Future<void> runOnStartup() async {
    await _ref.read(invoiceRepositoryProvider).runRecurringInvoicesNow();
  }
}

final recurringInvoiceServiceProvider = Provider<RecurringInvoiceService>((ref) {
  return RecurringInvoiceService(ref);
});

