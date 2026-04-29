import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/features/products/application/product_state.dart';
import 'package:pos_system/features/products/application/products_notifier.dart';

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ref.read(productsNotifierProvider.notifier).loadMore(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels > threshold) {
      ref.read(productsNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsNotifierProvider).value ?? const ProductListState();
    final notifier = ref.read(productsNotifierProvider.notifier);
    final categoriesRepo = ref.watch(categoriesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/products/categories'),
            icon: const Icon(Icons.category_outlined),
            label: const Text('Manage Categories'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/products/new'),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search by name or barcode',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: notifier.setSearch,
                  ),
                ),
                const SizedBox(width: 8),
                StreamBuilder<List<Category>>(
                  stream: categoriesRepo.watchAll(),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    return DropdownButton<int?>(
                      value: state.categoryId,
                      hint: const Text('Category'),
                      onChanged: notifier.setCategory,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All')),
                        ...items.map(
                          (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton<ProductSort>(
                  value: state.sort,
                  onChanged: (sort) {
                    if (sort != null) notifier.setSort(sort);
                  },
                  items: const [
                    DropdownMenuItem(value: ProductSort.nameAsc, child: Text('Name ↑')),
                    DropdownMenuItem(value: ProductSort.nameDesc, child: Text('Name ↓')),
                    DropdownMenuItem(value: ProductSort.priceAsc, child: Text('Price ↑')),
                    DropdownMenuItem(value: ProductSort.priceDesc, child: Text('Price ↓')),
                    DropdownMenuItem(value: ProductSort.stockAsc, child: Text('Stock ↑')),
                    DropdownMenuItem(value: ProductSort.stockDesc, child: Text('Stock ↓')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  return isWide
                      ? _DesktopTable(state: state, controller: _scrollController)
                      : _MobileList(state: state, controller: _scrollController);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopTable extends ConsumerWidget {
  const _DesktopTable({required this.state, required this.controller});

  final ProductListState state;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      controller: controller,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Barcode')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Unit')),
          DataColumn(label: Text('Stock')),
          DataColumn(label: Text('Sale Price')),
        ],
        rows: state.products
            .map(
              (p) => DataRow(
                onSelectChanged: (_) => context.go('/products/${p.id}'),
                cells: [
                  DataCell(Text(p.name)),
                  DataCell(Text(p.barcode ?? '-')),
                  DataCell(Text(p.categoryId?.toString() ?? '-')),
                  DataCell(Text(p.unit)),
                  DataCell(Row(
                    children: [
                      Text(p.stockQuantity.toString()),
                      if (p.stockQuantity < p.reorderLevel)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.brightness_1, color: Colors.red, size: 10),
                        )
                    ],
                  )),
                  DataCell(Text(p.salePrice.toStringAsFixed(2))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MobileList extends ConsumerWidget {
  const _MobileList({required this.state, required this.controller});

  final ProductListState state;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      controller: controller,
      itemCount: state.products.length,
      itemBuilder: (context, index) {
        final product = state.products[index];
        return Card(
          child: ListTile(
            title: Text(product.name),
            subtitle: Text('Stock: ${product.stockQuantity}  Price: ${product.salePrice}'),
            trailing: product.stockQuantity < product.reorderLevel
                ? const Icon(Icons.circle, size: 10, color: Colors.red)
                : null,
            onTap: () => context.go('/products/${product.id}'),
          ),
        );
      },
    );
  }
}

