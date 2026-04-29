import 'package:flutter/material.dart';
import 'package:pos_system/features/inventory/presentation/stock_in_page.dart';
import 'package:pos_system/features/inventory/presentation/adjustment_page.dart';
import 'package:pos_system/features/inventory/presentation/movement_history_page.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.add_box_outlined),
            title: const Text('Stock In'),
            subtitle: const Text('Record purchase or supplier intake'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StockInPage())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune_outlined),
            title: const Text('Adjustment'),
            subtitle: const Text('Manual +/- for counts, damage, returns'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdjustmentPage())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Movement History'),
            subtitle: const Text('View and export stock movements'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MovementHistoryPage())),
          ),
        ],
      ),
    );
  }
}
