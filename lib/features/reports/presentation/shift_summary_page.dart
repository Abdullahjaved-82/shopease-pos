import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/core/repositories/shifts_repository.dart';

class ShiftSummaryPage extends ConsumerStatefulWidget {
  const ShiftSummaryPage({super.key});

  @override
  ConsumerState<ShiftSummaryPage> createState() => _ShiftSummaryPageState();
}

class _ShiftSummaryPageState extends ConsumerState<ShiftSummaryPage> {
  Shift? _selected;
  ShiftCashSummary? _summary;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final repo = ref.watch(shiftsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Summary'),
        actions: [
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print),
            onPressed: _summary == null
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Print coming soon')),
                    );
                  },
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: StreamBuilder<List<Shift>>(
              stream: repo.watchRecent(limit: 50),
              builder: (context, snapshot) {
                final shifts = snapshot.data ?? [];
                if (shifts.isEmpty) {
                  return const Center(child: Text('No shifts yet'));
                }
                return ListView.builder(
                  itemCount: shifts.length,
                  itemBuilder: (context, index) {
                    final shift = shifts[index];
                    final isSelected = shift.id == _selected?.id;
                    return ListTile(
                      selected: isSelected,
                      title: Text('Shift #${shift.id}'),
                      subtitle: Text('Opened: ${df.format(shift.openedAt)}'),
                      trailing: shift.closedAt == null
                          ? const Chip(label: Text('Open'))
                          : Text('Closed: ${df.format(shift.closedAt!)}'),
                      onTap: () => _loadSummary(shift),
                    );
                  },
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _summary == null
                    ? const Center(child: Text('Select a shift'))
                    : _ShiftSummaryView(summary: _summary!),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSummary(Shift shift) async {
    setState(() {
      _selected = shift;
      _loading = true;
    });
    final repo = ref.read(shiftsRepositoryProvider);
    final summary = await repo.getCashSummary(shiftId: shift.id);
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }
}

class _ShiftSummaryView extends StatelessWidget {
  const _ShiftSummaryView({required this.summary});

  final ShiftCashSummary summary;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(name: 'PKR');
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shift #${summary.shift.id}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _stat('Opening cash', currency.format(summary.shift.openingCash)),
              _stat('Cash sales', currency.format(summary.cashSales)),
              _stat('Cash in', currency.format(summary.cashIn)),
              _stat('Cash out', currency.format(summary.cashOut)),
              _stat('Expected cash', currency.format(summary.expectedCash)),
              _stat('Closing cash', summary.shift.closingCash == null ? 'Open' : currency.format(summary.shift.closingCash)),
              _stat('Difference', summary.difference == null ? '-' : currency.format(summary.difference!)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Sales by payment', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: summary.salesByPayment.entries
                .map((e) => Chip(label: Text('${e.key}: ${currency.format(e.value)}')))
                .toList(),
          ),
          const SizedBox(height: 16),
          Text('Cash movements', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: summary.movements.isEmpty
                ? const Center(child: Text('No movements'))
                : ListView.builder(
                    itemCount: summary.movements.length,
                    itemBuilder: (context, index) {
                      final m = summary.movements[index];
                      return ListTile(
                        leading: Icon(m.type == 'in' ? Icons.call_received : Icons.call_made),
                        title: Text('${m.type.toUpperCase()} ${currency.format(m.amount)}'),
                        subtitle: Text(m.reason ?? ''),
                        trailing: Text(DateFormat('HH:mm').format(m.createdAt)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

