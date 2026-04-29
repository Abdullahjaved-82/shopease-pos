import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/features/purchasing/presentation/purchase_order_form_page.dart';
import 'package:pos_system/features/suppliers/presentation/supplier_form_page.dart';

class SupplierDetailPage extends ConsumerWidget {
  const SupplierDetailPage({super.key, required this.supplierId});

  final int supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersRepo = ref.watch(suppliersRepositoryProvider);
    final ordersRepo = ref.watch(purchaseOrdersRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SupplierFormPage(supplierId: supplierId)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_shopping_cart_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PurchaseOrderFormPage(supplierId: supplierId)),
            ),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: suppliersRepo.watchById(supplierId),
        builder: (context, snapshot) {
          final supplier = snapshot.data;
          if (supplier == null) {
            return const Center(child: Text('Supplier not found'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text(supplier.name, style: Theme.of(context).textTheme.titleLarge),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (supplier.phone != null && supplier.phone!.isNotEmpty) Text('Phone: ${supplier.phone}'),
                      if (supplier.email != null && supplier.email!.isNotEmpty) Text('Email: ${supplier.email}'),
                      if (supplier.address != null && supplier.address!.isNotEmpty) Text('Address: ${supplier.address}'),
                      Text('Balance: ${supplier.balance.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Purchase Orders', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              StreamBuilder(
                stream: ordersRepo.watchOrdersWithSupplier(supplierId: supplierId),
                builder: (context, snapshot) {
                  final orders = snapshot.data ?? [];
                  if (orders.isEmpty) {
                    return const Text('No orders yet');
                  }
                  return Column(
                    children: orders
                        .map(
                          (o) => Card(
                            child: ListTile(
                              title: Text('PO #${o.order.id} • ${o.order.status}'),
                              subtitle: Text(o.order.createdAt.toLocal().toString()),
                              trailing: Text(o.order.total.toStringAsFixed(2)),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('Payment History', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('No payments recorded.'),
            ],
          );
        },
      ),
    );
  }
}

