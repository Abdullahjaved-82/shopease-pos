import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/features/suppliers/presentation/supplier_detail_page.dart';
import 'package:pos_system/features/suppliers/presentation/supplier_form_page.dart';

class SuppliersListPage extends ConsumerStatefulWidget {
  const SuppliersListPage({super.key});

  @override
  ConsumerState<SuppliersListPage> createState() => _SuppliersListPageState();
}

class _SuppliersListPageState extends ConsumerState<SuppliersListPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(suppliersRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupplierFormPage()));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Search suppliers'),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder(
                stream: repo.watchAll(search: _search),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Center(child: Text('No suppliers'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final supplier = items[index];
                      final balanceColor = supplier.balance > 0 ? Colors.red : Colors.green;
                      return ListTile(
                        title: Text(supplier.name),
                        subtitle: Text(supplier.phone ?? ''),
                        trailing: Text(supplier.balance.toStringAsFixed(2), style: TextStyle(color: balanceColor)),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => SupplierDetailPage(supplierId: supplier.id)),
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

