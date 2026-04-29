import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/core/database/app_database.dart';

class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({super.key, this.customerId});
  final int? customerId;

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _creditCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.customerId != null) {
      _load();
    }
  }

  Future<void> _load() async {
    final repo = ref.read(customersRepositoryProvider);
    final customer = await repo.getById(widget.customerId!);
    if (customer != null) {
      setState(() {
        _nameCtrl.text = customer.name;
        _phoneCtrl.text = customer.phone ?? '';
        _cnicCtrl.text = customer.cnic ?? '';
        _addressCtrl.text = customer.address ?? '';
        _creditCtrl.text = customer.creditLimit.toStringAsFixed(2);
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cnicCtrl.dispose();
    _addressCtrl.dispose();
    _creditCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.customerId == null ? 'New Customer' : 'Edit Customer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cnicCtrl,
              decoration: const InputDecoration(labelText: 'CNIC'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _creditCtrl,
              decoration: const InputDecoration(labelText: 'Credit limit'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.customerId == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final repo = ref.read(customersRepositoryProvider);
    final companion = CustomersCompanion(
      id: widget.customerId != null ? Value(widget.customerId!) : const Value.absent(),
      name: Value(_nameCtrl.text.trim()),
      phone: Value(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
      cnic: Value(_cnicCtrl.text.trim().isEmpty ? null : _cnicCtrl.text.trim()),
      address: Value(_addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim()),
      creditLimit: Value(double.tryParse(_creditCtrl.text) ?? 0),
    );
    if (widget.customerId == null) {
      await repo.insert(companion);
    } else {
      await repo.updateCustomer(companion);
    }
    if (mounted) {
      setState(() => _loading = false);
      context.go('/customers');
    }
  }
}

