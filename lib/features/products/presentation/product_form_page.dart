
import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/core/repositories/categories_repository.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.productId});

  final int? productId;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _saleCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _reorderCtrl = TextEditingController();
  int? _categoryId;
  String _unit = 'pcs';
  String? _imagePath;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _loadProduct();
    }
  }

  Future<void> _loadProduct() async {
    final repo = ref.read(productsRepositoryProvider);
    final product = await repo.getById(widget.productId!);
    if (product != null && mounted) {
      setState(() {
        _nameCtrl.text = product.name;
        _barcodeCtrl.text = product.barcode ?? '';
        _costCtrl.text = product.costPrice.toString();
        _saleCtrl.text = product.salePrice.toString();
        _stockCtrl.text = product.stockQuantity.toString();
        _reorderCtrl.text = product.reorderLevel.toString();
        _categoryId = product.categoryId;
        _unit = product.unit;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _costCtrl.dispose();
    _saleCtrl.dispose();
    _stockCtrl.dispose();
    _reorderCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _imagePath = result.files.single.path);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final repo = ref.read(productsRepositoryProvider);
    final companion = ProductsCompanion(
      id: widget.productId != null ? Value(widget.productId!) : const Value.absent(),
      name: Value(_nameCtrl.text.trim()),
      barcode: Value(_barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim()),
      categoryId: Value(_categoryId),
      unit: Value(_unit),
      costPrice: Value(double.tryParse(_costCtrl.text) ?? 0),
      salePrice: Value(double.tryParse(_saleCtrl.text) ?? 0),
      stockQuantity: Value(int.tryParse(_stockCtrl.text) ?? 0),
      reorderLevel: Value(int.tryParse(_reorderCtrl.text) ?? 0),
    );
    if (widget.productId == null) {
      await repo.insert(companion);
    } else {
      await repo.updateProduct(companion);
    }
    if (mounted) {
      setState(() => _loading = false);
      context.go('/products');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesRepo = ref.watch(categoriesRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId == null ? 'Add Product' : 'Edit Product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcodeCtrl,
              decoration: const InputDecoration(labelText: 'SKU / Barcode'),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<List<Category>>(
                    stream: categoriesRepo.watchAll(),
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? [];
                      return DropdownButtonFormField<int?>(
                        initialValue: _categoryId,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('None')),
                          ...items.map(
                            (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                          ),
                        ],
                        onChanged: (id) => setState(() => _categoryId = id),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Create category',
                  onPressed: () => _showAddCategoryDialog(categoriesRepo),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _unit,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: const [
                DropdownMenuItem(value: 'pcs', child: Text('Pieces')),
                DropdownMenuItem(value: 'kg', child: Text('Kilogram')),
                DropdownMenuItem(value: 'ltr', child: Text('Liter')),
              ],
              onChanged: (value) => setState(() => _unit = value ?? 'pcs'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cost Price'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _saleCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sale Price'),
                    validator: (val) {
                      final parsed = double.tryParse(val ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Sale price must be > 0';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock Quantity'),
                    validator: (val) {
                      final parsed = int.tryParse(val ?? '');
                      if (parsed == null || parsed < 0) {
                        return 'Stock cannot be negative';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _reorderCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Reorder Level'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Pick Image'),
                ),
                const SizedBox(width: 12),
                if (_imagePath != null) Expanded(child: Text(_imagePath!, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.productId == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddCategoryDialog(CategoriesRepository repo) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final existing = await repo.getByName(result);
      if (existing != null) {
        setState(() => _categoryId = existing.id);
        return;
      }
      final id = await repo.insert(CategoriesCompanion.insert(name: result));
      setState(() => _categoryId = id);
    }
  }
}
