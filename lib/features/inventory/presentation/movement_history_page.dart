import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:share_plus/share_plus.dart';

class MovementHistoryPage extends ConsumerStatefulWidget {
  const MovementHistoryPage({super.key});

  @override
  ConsumerState<MovementHistoryPage> createState() => _MovementHistoryPageState();
}

class _MovementHistoryPageState extends ConsumerState<MovementHistoryPage> {
  int? _productId;
  String? _type;
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final inventoryRepo = ref.watch(inventoryRepositoryProvider);
    final productsRepo = ref.watch(productsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Movement History')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<List<Product>>(
                    stream: productsRepo.watchAll(),
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? [];
                      return DropdownButtonFormField<int?>(
                        initialValue: _productId,
                        hint: const Text('Product (All)'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All')),
                          ...items.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                        ],
                        onChanged: (id) => setState(() => _productId = id),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: _type,
                  hint: const Text('Type'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 'sale', child: Text('Sale')),
                    DropdownMenuItem(value: 'purchase', child: Text('Purchase')),
                    DropdownMenuItem(value: 'adjustment', child: Text('Adjustment')),
                  ],
                  onChanged: (v) => setState(() => _type = v),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: _range,
                    );
                    if (picked != null) setState(() => _range = picked);
                  },
                  child: Text(_range == null ? 'Date range' : '${_range!.start.toIso8601String().substring(0, 10)} - ${_range!.end.toIso8601String().substring(0, 10)}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<StockMovement>>(
                stream: inventoryRepo.watchMovements(
                  productId: _productId,
                  typePrefix: _type,
                  start: _range?.start,
                  end: _range?.end,
                ),
                builder: (context, snapshot) {
                  final movements = snapshot.data ?? [];
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          itemCount: movements.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final m = movements[index];
                            return ListTile(
                              title: Text('Product ${m.productId} - ${m.type}'),
                              subtitle: Text('${m.qty} @ ${m.createdAt}'),
                              trailing: Text(m.note ?? ''),
                            );
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download),
                          label: const Text('Export CSV'),
                          onPressed: movements.isEmpty ? null : () => _exportCsv(movements),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(List<StockMovement> moves) async {
    final buffer = StringBuffer('id,productId,type,qty,note,createdAt,userId\n');
    for (final m in moves) {
      buffer.writeln('${m.id},${m.productId},${m.type},${m.qty},"${m.note ?? ''}",${m.createdAt.toIso8601String()},${m.userId}');
    }
    final bytes = utf8.encode(buffer.toString());
    final xFile = XFile.fromData(bytes, mimeType: 'text/csv', name: 'movements.csv');
    await Share.shareXFiles([xFile]);
  }
}



