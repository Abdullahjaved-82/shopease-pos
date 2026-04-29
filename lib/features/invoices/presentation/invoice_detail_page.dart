import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';
import 'package:pos_system/features/invoices/domain/document_models.dart';

class InvoiceDetailPage extends ConsumerStatefulWidget {
  const InvoiceDetailPage({super.key, required this.invoiceId});

  final int invoiceId;

  @override
  ConsumerState<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends ConsumerState<InvoiceDetailPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final invoiceRepo = ref.watch(invoiceRepositoryProvider);
    final paymentsRepo = ref.watch(invoicePaymentsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Detail'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _duplicate,
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Duplicate Invoice',
          ),
          IconButton(
            onPressed: _busy ? null : () => context.go('/invoices/${widget.invoiceId}/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: FutureBuilder<Invoice?>(
        future: invoiceRepo.getInvoiceById(widget.invoiceId),
        builder: (context, invoiceSnap) {
          if (!invoiceSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final invoice = invoiceSnap.data;
          if (invoice == null) {
            return const Center(child: Text('Invoice not found'));
          }

          return FutureBuilder<List<InvoiceItem>>(
            future: invoiceRepo.getItemsByInvoiceId(widget.invoiceId),
            builder: (context, itemsSnap) {
              final items = itemsSnap.data ?? const <InvoiceItem>[];
              return FutureBuilder<double>(
                future: paymentsRepo.getRemainingBalance(widget.invoiceId),
                builder: (context, remainingSnap) {
                  final remaining = remainingSnap.data ?? invoice.total;
                  final effectiveStatus = _computedStatus(invoice, remaining);
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(invoice.invoiceNumber, style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(width: 12),
                            _StatusChip(status: effectiveStatus),
                            const Spacer(),
                            Text('Remaining: ${remaining.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Type: ${DocumentType.fromDb(invoice.docType).title}'),
                        Text('Issue: ${DateFormat('dd MMM yyyy').format(invoice.issueDate)}'),
                        Text(
                          DocumentType.fromDb(invoice.docType) == DocumentType.quotation
                              ? 'Expiry: ${invoice.expiryDate == null ? '-' : DateFormat('dd MMM yyyy').format(invoice.expiryDate!)}'
                              : 'Due: ${invoice.dueDate == null ? '-' : DateFormat('dd MMM yyyy').format(invoice.dueDate!)}',
                        ),
                        const SizedBox(height: 12),
                        _buildActionBar(invoice, effectiveStatus, remaining),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: _itemsTable(items)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _summaryCard(invoice, remaining),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Payment History', style: Theme.of(context).textTheme.titleMedium),
                                              const SizedBox(height: 8),
                                              Expanded(
                                                child: StreamBuilder<List<InvoicePayment>>(
                                                  stream: paymentsRepo.watchByInvoice(widget.invoiceId),
                                                  builder: (context, snapshot) {
                                                    final list = snapshot.data ?? const <InvoicePayment>[];
                                                    if (list.isEmpty) return const Center(child: Text('No payments yet'));
                                                    return ListView.separated(
                                                      itemCount: list.length,
                                                      separatorBuilder: (_, _) => const Divider(height: 1),
                                                      itemBuilder: (context, index) {
                                                        final p = list[index];
                                                        return ListTile(
                                                          dense: true,
                                                          title: Text('${p.amount.toStringAsFixed(2)} (${p.method})'),
                                                          subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(p.paidAt)),
                                                          trailing: Text(p.note ?? ''),
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionBar(Invoice invoice, String status, double remaining) {
    final docType = DocumentType.fromDb(invoice.docType);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status == 'draft' && docType != DocumentType.proforma)
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await ref.read(invoiceRepositoryProvider).markAsSent(invoice.id);
                    if (mounted) setState(() => _busy = false);
                  },
            icon: const Icon(Icons.send_outlined),
            label: const Text('Mark as Sent'),
          ),
        if (docType == DocumentType.invoice && (status == 'sent' || status == 'overdue' || status == 'partial'))
          FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _recordPayment(invoice, remaining),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Record Payment'),
          ),
        if (docType == DocumentType.invoice)
          OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final auth = ref.read(authControllerProvider);
                  final saleId = await ref.read(invoiceRepositoryProvider).convertToSale(
                        invoice.id,
                        userId: auth.userId ?? 0,
                      );
                  if (!mounted) return;
                  setState(() => _busy = false);
                  if (saleId != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Converted to sale #$saleId')),
                    );
                  }
                },
            icon: const Icon(Icons.point_of_sale_outlined),
            label: const Text('Convert to Sale'),
          ),
        if (docType == DocumentType.quotation && status == 'accepted')
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final newId = await ref.read(invoiceRepositoryProvider).convertQuotationToInvoice(invoice.id);
                    if (!mounted) return;
                    setState(() => _busy = false);
                    if (newId > 0) context.go('/invoices/$newId');
                  },
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Convert to Invoice'),
          ),
        if (docType == DocumentType.proforma)
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final newId = await ref.read(invoiceRepositoryProvider).convertProformaToInvoice(invoice.id);
                    if (!mounted) return;
                    setState(() => _busy = false);
                    if (newId > 0) context.go('/invoices/$newId');
                  },
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Convert to Tax Invoice'),
          ),
        if (docType == DocumentType.quotation && status == 'sent')
          FilledButton.tonal(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await ref.read(invoiceRepositoryProvider).updateStatus(invoiceId: invoice.id, status: 'accepted');
                    if (mounted) setState(() => _busy = false);
                  },
            child: const Text('Mark Accepted'),
          ),
        if (docType == DocumentType.quotation && status == 'sent')
          FilledButton.tonal(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await ref.read(invoiceRepositoryProvider).updateStatus(invoiceId: invoice.id, status: 'rejected');
                    if (mounted) setState(() => _busy = false);
                  },
            child: const Text('Mark Rejected'),
          ),
      ],
    );
  }

  Widget _itemsTable(List<InvoiceItem> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    dense: true,
                    title: Text(item.description),
                    subtitle: Text('Qty ${item.qty.toStringAsFixed(2)} x ${item.unitPrice.toStringAsFixed(2)}'),
                    trailing: Text(item.lineTotal.toStringAsFixed(2)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(Invoice invoice, double remaining) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _sumRow('Subtotal', invoice.subtotal),
            _sumRow('Discount', invoice.discountAmount),
            _sumRow('Tax', invoice.taxAmount),
            const Divider(),
            _sumRow('Total', invoice.total, bold: true),
            _sumRow('Remaining', remaining, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _sumRow(String label, double value, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value.toStringAsFixed(2), style: style),
      ],
    );
  }

  String _computedStatus(Invoice invoice, double remaining) {
    final type = DocumentType.fromDb(invoice.docType);
    if (type == DocumentType.quotation) {
      if (invoice.status == 'accepted' || invoice.status == 'rejected') return invoice.status;
      final exp = invoice.expiryDate;
      if (exp != null) {
        final today = DateTime.now();
        final expDay = DateTime(exp.year, exp.month, exp.day);
        final nowDay = DateTime(today.year, today.month, today.day);
        if (expDay.isBefore(nowDay)) return 'expired';
      }
      return invoice.status == 'draft' ? 'draft' : 'sent';
    }

    if (remaining <= 0.0001) return 'paid';
    if (invoice.status == 'draft') return 'draft';
    if (remaining < invoice.total) return 'partial';
    final due = invoice.dueDate;
    if (due != null) {
      final today = DateTime.now();
      final dueDay = DateTime(due.year, due.month, due.day);
      final nowDay = DateTime(today.year, today.month, today.day);
      if (dueDay.isBefore(nowDay)) return 'overdue';
    }
    return 'sent';
  }

  Future<void> _recordPayment(Invoice invoice, double remaining) async {
    final amountCtrl = TextEditingController(text: remaining.toStringAsFixed(2));
    final noteCtrl = TextEditingController();
    final method = ValueNotifier<String>('cash');
    DateTime paidAt = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: StatefulBuilder(
          builder: (context, setLocalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: method.value,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank')),
                    DropdownMenuItem(value: 'easypaisa', child: Text('EasyPaisa')),
                    DropdownMenuItem(value: 'jazzcash', child: Text('JazzCash')),
                  ],
                  onChanged: (value) => method.value = value ?? 'cash',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('Paid At: ${DateFormat('dd MMM yyyy').format(paidAt)}')),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: paidAt,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setLocalState(() => paidAt = DateTime(picked.year, picked.month, picked.day, paidAt.hour, paidAt.minute));
                        }
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;
    final amount = double.tryParse(amountCtrl.text) ?? 0;
    if (amount <= 0) return;

    setState(() => _busy = true);
    await ref.read(invoicePaymentsRepositoryProvider).recordPayment(
          invoiceId: invoice.id,
          amount: amount,
          method: method.value,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
          paidAt: paidAt,
        );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _duplicate() async {
    setState(() => _busy = true);
    final newId = await ref.read(invoiceRepositoryProvider).duplicateInvoice(widget.invoiceId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (newId > 0) {
      context.go('/invoices/$newId/edit');
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

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
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}




