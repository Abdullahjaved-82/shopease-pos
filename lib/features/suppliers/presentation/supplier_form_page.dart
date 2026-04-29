import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';

class SupplierFormPage extends ConsumerStatefulWidget {
  const SupplierFormPage({super.key, this.supplierId});

  final int? supplierId;

  @override
  ConsumerState<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends ConsumerState<SupplierFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.supplierId == null) return;
    final repo = ref.read(suppliersRepositoryProvider);
    final supplier = await repo.getById(widget.supplierId!);
    if (supplier != null) {
      _nameCtrl.text = supplier.name;
      _phoneCtrl.text = supplier.phone ?? '';
      _emailCtrl.text = supplier.email ?? '';
      _addressCtrl.text = supplier.address ?? '';
      _balanceCtrl.text = supplier.balance.toStringAsFixed(2);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(suppliersRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.supplierId == null ? 'New Supplier' : 'Edit Supplier')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _balanceCtrl,
                decoration: const InputDecoration(labelText: 'Opening balance'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _loading = true);
                        final balance = double.tryParse(_balanceCtrl.text) ?? 0;
                        if (widget.supplierId == null) {
                          await repo.insert(
                            SuppliersCompanion.insert(
                              name: _nameCtrl.text.trim(),
                              phone: Value(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
                              email: Value(_emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim()),
                              address: Value(_addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim()),
                              balance: Value(balance),
                            ),
                          );
                        } else {
                          await repo.updateSupplier(
                            SuppliersCompanion(
                              id: Value(widget.supplierId!),
                              name: Value(_nameCtrl.text.trim()),
                              phone: Value(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
                              email: Value(_emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim()),
                              address: Value(_addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim()),
                              balance: Value(balance),
                            ),
                          );
                        }
                        if (mounted) Navigator.of(context).pop();
                      },
                child: Text(widget.supplierId == null ? 'Create' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
