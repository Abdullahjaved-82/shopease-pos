import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_system/core/providers/repositories.dart';

class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(productsRepositoryProvider);
    final categoriesRepo = ref.watch(categoriesRepositoryProvider);

    return FutureBuilder(
      future: repo.getById(id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final product = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            title: Text(product.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => context.go('/products/${product.id}/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  await repo.deleteById(product.id);
                  if (context.mounted) {
                    context.go('/products');
                  }
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Barcode: ${product.barcode ?? '-'}'),
                const SizedBox(height: 8),
                FutureBuilder(
                  future: product.categoryId != null
                      ? categoriesRepo.getById(product.categoryId!)
                      : Future.value(null),
                  builder: (context, catSnap) {
                    final categoryName = catSnap.data?.name ?? '-';
                    return Text('Category: $categoryName');
                  },
                ),
                const SizedBox(height: 8),
                Text('Unit: ${product.unit}'),
                const SizedBox(height: 8),
                Text('Stock: ${product.stockQuantity}'),
                const SizedBox(height: 8),
                Text('Reorder level: ${product.reorderLevel}'),
                const SizedBox(height: 8),
                Text('Cost: ${product.costPrice.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                Text('Sale: ${product.salePrice.toStringAsFixed(2)}'),
              ],
            ),
          ),
        );
      },
    );
  }
}

