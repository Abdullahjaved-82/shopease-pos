import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/repositories/categories_repository.dart';
import 'package:pos_system/features/products/application/categories_notifier.dart';

class CategoryManagementPage extends ConsumerStatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  ConsumerState<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends ConsumerState<CategoryManagementPage> {
  final TextEditingController _newNameController = TextEditingController();
  final Map<int, TextEditingController> _editingControllers = {};
  int? _editingId;
  String _newColor = presetCategoryColors.first;
  final Map<int, String> _editingColors = {};

  @override
  void dispose() {
    _newNameController.dispose();
    for (final controller in _editingControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAddCard(context),
            const SizedBox(height: 16),
            Expanded(
              child: categoriesAsync.when(
                data: (items) => items.isEmpty
                    ? const Center(child: Text('No categories yet.'))
                    : ListView.separated(
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isEditing = _editingId == item.category.id;
                          return ListTile(
                            leading: _ColorDot(colorHex: _editingColors[item.category.id] ?? item.category.colorHex),
                            title: isEditing
                                ? TextField(
                                    controller: _editingControllers[item.category.id],
                                    autofocus: true,
                                    decoration: const InputDecoration(labelText: 'Category name'),
                                  )
                                : Text(item.category.name),
                            subtitle: Text('${item.productCount} products'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: isEditing
                                  ? [
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: _cancelEditing,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.check),
                                        onPressed: () => _saveEdit(item),
                                      ),
                                    ]
                                  : [
                                      IconButton(
                                        icon: const Icon(Icons.color_lens_outlined),
                                        onPressed: () => _startEditing(item, changeColorOnly: true),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _startEditing(item),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () => _confirmDelete(context, item),
                                      ),
                                    ],
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          );
                        },
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemCount: items.length,
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add category'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newNameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onSubmitted: (_) => _submitNew(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  onPressed: _submitNew,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presetCategoryColors
                  .map(
                    (hex) => _ColorSwatch(
                      hex: hex,
                      selected: _newColor == hex,
                      onTap: () => setState(() => _newColor = hex),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _startEditing(CategoryWithCount item, {bool changeColorOnly = false}) {
    setState(() {
      _editingId = item.category.id;
      _editingControllers.putIfAbsent(
        item.category.id,
        () => TextEditingController(text: item.category.name),
      );
      _editingColors[item.category.id] = item.category.colorHex;
    });
    if (changeColorOnly) {
      _showColorPicker(item.category.id);
    }
  }

  void _cancelEditing() {
    setState(() {
      _editingId = null;
    });
  }

  Future<void> _saveEdit(CategoryWithCount item) async {
    final controller = _editingControllers[item.category.id];
    if (controller == null) return;
    final name = controller.text.trim();
    final colorHex = _editingColors[item.category.id] ?? item.category.colorHex;
    if (name.isEmpty) return;
    await ref.read(categoriesNotifierProvider.notifier).renameCategory(
          id: item.category.id,
          name: name,
          colorHex: colorHex,
        );
    setState(() {
      _editingId = null;
    });
  }

  Future<void> _submitNew() async {
    final name = _newNameController.text.trim();
    if (name.isEmpty) return;
    await ref.read(categoriesNotifierProvider.notifier).addCategory(
          name: name,
          colorHex: _newColor,
        );
    setState(() {
      _newNameController.clear();
      _newColor = presetCategoryColors.first;
    });
  }

  Future<void> _confirmDelete(BuildContext context, CategoryWithCount item) async {
    final count = item.productCount;
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete category'),
            content: Text(
              count > 0
                  ? 'This category has $count products. Delete anyway?'
                  : 'Delete category "${item.category.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldDelete) {
      await ref.read(categoriesNotifierProvider.notifier).deleteCategory(item.category.id);
    }
  }

  void _showColorPicker(int categoryId) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: presetCategoryColors
              .map(
                (hex) => _ColorSwatch(
                  hex: hex,
                  selected: (_editingColors[categoryId] ?? '') == hex,
                  onTap: () {
                    setState(() => _editingColors[categoryId] = hex);
                    Navigator.of(context).pop();
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.hex, required this.selected, required this.onTap});

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(hex);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? Colors.black : Colors.grey.shade300, width: 2),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.colorHex});

  final String colorHex;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 12,
      backgroundColor: _hexToColor(colorHex),
    );
  }
}

Color _hexToColor(String hex) {
  final sanitized = hex.replaceFirst('#', '');
  final value = int.tryParse(sanitized, radix: 16) ?? 0x607D8B;
  return Color(0xFF000000 | value);
}

