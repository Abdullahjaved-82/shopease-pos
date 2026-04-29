import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';

class AdjustmentPage extends ConsumerStatefulWidget {
  const AdjustmentPage({super.key});

  @override
  ConsumerState<AdjustmentPage> createState() => _AdjustmentPageState();
}

class _AdjustmentPageState extends ConsumerState<AdjustmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  String _reason = 'damage';
  int? _productId;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsRepo = ref.watch(productsRepositoryProvider);
    final inventoryRepo = ref.watch(inventoryRepositoryProvider);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            StreamBuilder<List<Product>>(
              stream: productsRepo.watchAll(),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                return DropdownButtonFormField<int>(
                  initialValue: _productId,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: items.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (id) => setState(() => _productId = id),
                  validator: (v) => v == null ? 'Choose product' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _qtyCtrl,
                    decoration: const InputDecoration(labelText: 'Quantity (+/-)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v ?? '') == null) ? 'Enter number' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _reason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    items: const [
                      DropdownMenuItem(value: 'damage', child: Text('Damage')),
                      DropdownMenuItem(value: 'count', child: Text('Count Adjustment')),
                      DropdownMenuItem(value: 'return', child: Text('Return')),
                    ],
                    onChanged: (v) => setState(() => _reason = v ?? 'damage'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      if (_productId == null) return;
                      final qty = int.tryParse(_qtyCtrl.text) ?? 0;
                      await inventoryRepo.recordMovement(
                        productId: _productId!,
                        type: 'adjustment:$_reason',
                        qty: qty,
                        note: _reason,
                        userId: auth.userId ?? 0,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adjustment saved')));
                        _qtyCtrl.clear();
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

