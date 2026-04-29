import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/features/invoices/domain/document_models.dart';

class RecurringInvoicesListPage extends ConsumerWidget {
  const RecurringInvoicesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(invoiceRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Invoices')),
      body: StreamBuilder(
        stream: repo.watchRecurring(),
        builder: (context, snapshot) {
          final list = snapshot.data ?? const [];
          if (list.isEmpty) {
            return const Center(child: Text('No recurring invoices configured'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = list[index];
              final freq = RecurringFrequency.fromDb(r.frequency);
              return SwitchListTile(
                value: r.active,
                title: Text('Template #${r.templateInvoiceId} - ${freq.name}'),
                subtitle: Text('Next run: ${DateFormat('dd MMM yyyy').format(r.nextRunDate)}'),
                onChanged: (v) => repo.setRecurringActive(r.id, v),
              );
            },
          );
        },
      ),
    );
  }
}

