import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';

class StockInPage extends ConsumerStatefulWidget {
  const StockInPage({super.key});

  @override
  ConsumerState<StockInPage> createState() => _StockInPageState();
}

class _StockInPageState extends ConsumerState<StockInPage> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int? _productId;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsRepo = ref.watch(productsRepositoryProvider);
    final inventoryRepo = ref.watch(inventoryRepositoryProvider);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock In')),
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
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter qty' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _costCtrl,
                    decoration: const InputDecoration(labelText: 'Cost price'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(labelText: 'Supplier / Note'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      if (_productId == null) return;
                      final qty = int.parse(_qtyCtrl.text);
                      final cost = double.tryParse(_costCtrl.text);
                      final userId = auth.userId ?? 0;
                      await inventoryRepo.recordMovement(
                        productId: _productId!,
                        type: 'purchase',
                        qty: qty,
                        note: _noteCtrl.text.trim(),
                        userId: userId,
                        newCostPrice: cost,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock recorded')));
                        _qtyCtrl.clear();
                        _costCtrl.clear();
                        _noteCtrl.clear();
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


