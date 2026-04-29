import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/core/repositories/purchase_orders_repository.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';

class PurchaseOrderFormPage extends ConsumerStatefulWidget {
  const PurchaseOrderFormPage({super.key, this.supplierId});

  final int? supplierId;

  @override
  ConsumerState<PurchaseOrderFormPage> createState() => _PurchaseOrderFormPageState();
}

class _PurchaseOrderFormPageState extends ConsumerState<PurchaseOrderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _noteCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  int? _supplierId;
  int? _productId;
  final List<PurchaseOrderItemInput> _items = [];

  @override
  void initState() {
    super.initState();
    _supplierId = widget.supplierId;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersRepo = ref.watch(suppliersRepositoryProvider);
    final productsRepo = ref.watch(productsRepositoryProvider);
    final poRepo = ref.watch(purchaseOrdersRepositoryProvider);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Order')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder(
          stream: suppliersRepo.watchAll(),
          builder: (context, suppliersSnap) {
            final suppliers = suppliersSnap.data ?? [];
            return Form(
              key: _formKey,
              child: ListView(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _supplierId,
                    items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                    onChanged: widget.supplierId != null ? null : (v) => setState(() => _supplierId = v),
                    decoration: const InputDecoration(labelText: 'Supplier'),
                    validator: (v) => v == null ? 'Choose supplier' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(labelText: 'Note'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Text('Items', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  StreamBuilder(
                    stream: productsRepo.watchAll(),
                    builder: (context, productSnap) {
                      final products = productSnap.data ?? [];
                      final productMap = {for (final p in products) p.id: p};
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _productId,
                                  decoration: const InputDecoration(labelText: 'Product'),
                                  items: products
                                      .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                                      .toList(),
                                  onChanged: (v) => setState(() => _productId = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _qtyCtrl,
                                  decoration: const InputDecoration(labelText: 'Qty'),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _costCtrl,
                                  decoration: const InputDecoration(labelText: 'Cost'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  final qty = int.tryParse(_qtyCtrl.text) ?? 0;
                                  final cost = double.tryParse(_costCtrl.text) ?? 0;
                                  if (_productId == null || qty <= 0) return;
                                  setState(() {
                                    _items.add(PurchaseOrderItemInput(productId: _productId!, qty: qty, costPrice: cost));
                                    _productId = null;
                                    _qtyCtrl.text = '1';
                                    _costCtrl.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_items.isEmpty)
                            const Align(alignment: Alignment.centerLeft, child: Text('No items added'))
                          else
                            Column(
                              children: _items.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final item = entry.value;
                                final product = productMap[item.productId];
                                final label = product?.name ?? 'Product ${item.productId}';
                                return ListTile(
                                  title: Text(label),
                                  subtitle: Text('Qty: ${item.qty} @ ${item.costPrice.toStringAsFixed(2)}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => setState(() => _items.removeAt(idx)),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;
                            if (_items.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item')));
                              return;
                            }
                            final orderId = await poRepo.createOrder(
                              supplierId: _supplierId!,
                              items: _items,
                              note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                              status: 'draft',
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved')));
                              Navigator.of(context).pop(orderId);
                            }
                          },
                          child: const Text('Save Draft'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;
                            if (_items.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item')));
                              return;
                            }
                            final orderId = await poRepo.createOrder(
                              supplierId: _supplierId!,
                              items: _items,
                              note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                              status: 'sent',
                            );
                            await poRepo.markReceived(orderId: orderId, userId: auth.userId ?? 0);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Received and stock updated')));
                              Navigator.of(context).pop(orderId);
                            }
                          },
                          child: const Text('Receive Now'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

