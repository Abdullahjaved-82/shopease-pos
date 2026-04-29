import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/core/repositories/invoice_repository.dart';
import 'package:pos_system/features/invoices/application/overdue_invoices_provider.dart';
import 'package:pos_system/features/invoices/domain/document_models.dart';

class InvoiceListPage extends ConsumerStatefulWidget {
  const InvoiceListPage({super.key});

  @override
  ConsumerState<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends ConsumerState<InvoiceListPage> {
  String _status = 'all';
  int? _customerId;
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final invoicesRepo = ref.watch(invoiceRepositoryProvider);
    final customersRepo = ref.watch(customersRepositoryProvider);

    final stream = invoicesRepo.watchInvoices(
      status: _status == 'all' ? null : _status,
      customerId: _customerId,
      startDate: _range?.start,
      endDate: _range?.end,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            onSelected: (value) {
              if (value == 'invoice') context.go('/invoices/new');
              if (value == 'quotation') context.go('/invoices/new/quotation');
              if (value == 'proforma') context.go('/invoices/new/proforma');
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'invoice', child: Text('New Invoice')),
              PopupMenuItem(value: 'quotation', child: Text('New Quotation')),
              PopupMenuItem(value: 'proforma', child: Text('New Pro Forma')),
            ],
          ),
          IconButton(
            onPressed: () => context.go('/invoices/recurring'),
            icon: const Icon(Icons.repeat),
            tooltip: 'Recurring',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _OverdueBanner(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'sent', child: Text('Sent')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                  ],
                  onChanged: (value) => setState(() => _status = value ?? 'all'),
                ),
                FutureBuilder(
                  future: customersRepo.getAll(),
                  builder: (context, snapshot) {
                    final customers = snapshot.data ?? const [];
                    return DropdownButton<int?>(
                      value: _customerId,
                      hint: const Text('All Customers'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('All Customers')),
                        ...customers.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (value) => setState(() => _customerId = value),
                    );
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 5),
                      initialDateRange: _range,
                    );
                    if (picked != null) {
                      setState(() => _range = picked);
                    }
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _range == null
                        ? 'Date Range'
                        : '${DateFormat('dd/MM').format(_range!.start)} - ${DateFormat('dd/MM').format(_range!.end)}',
                  ),
                ),
                if (_range != null)
                  TextButton(
                    onPressed: () => setState(() => _range = null),
                    child: const Text('Clear Date'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<InvoiceListEntry>>(
                stream: stream,
                builder: (context, snapshot) {
                  final list = snapshot.data ?? const [];
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (list.isEmpty) {
                    return const Center(child: Text('No invoices found'));
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = list[index];
                      final invoice = row.invoice;
                      return ListTile(
                        title: Text(invoice.invoiceNumber),
                        subtitle: Text(
                          '${DocumentType.fromDb(invoice.docType).title} - ${row.customerName ?? invoice.billToName ?? 'Walk-in'} - ${DateFormat('dd MMM yyyy').format(invoice.issueDate)}',
                        ),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          children: [
                            Text(invoice.total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                            _StatusBadge(status: row.computedStatus),
                            IconButton(
                              onPressed: () => context.go('/invoices/${invoice.id}'),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'paid' => Colors.green,
      'sent' => Colors.blue,
      'partial' => Colors.orange,
      'overdue' => Colors.red,
      'accepted' => Colors.green,
      'rejected' => Colors.red,
      'expired' => Colors.grey,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _OverdueBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = ref.watch(overdueInvoiceSummaryProvider);
    return overdue.when(
      data: (summary) {
        if (summary.count == 0) return const SizedBox.shrink();
        return Card(
          color: Colors.red.withValues(alpha: 0.08),
          child: ListTile(
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
            title: Text('${summary.count} invoices overdue - PKR ${summary.totalAmount.toStringAsFixed(2)} total'),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

