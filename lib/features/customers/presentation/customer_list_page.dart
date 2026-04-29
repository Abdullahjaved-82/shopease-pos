import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/core/repositories/customers_repository.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';
import 'package:pos_system/features/auth/domain/user_role.dart';
import 'package:pos_system/features/shared/application/notification_service.dart';

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
  String _search = '';
  bool _onlyBalance = false;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(customersRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            tooltip: 'Notify all with balance',
            onPressed: _notifyAll,
          ),
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
                    decoration: const InputDecoration(labelText: 'Search'),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 12),
                Checkbox(
                  value: _onlyBalance,
                  onChanged: (v) => setState(() => _onlyBalance = v ?? false),
                ),
                const Text('Has balance'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<CustomerWithBalance>>(
                stream: repo.watchWithBalance(search: _search, onlyWithBalance: _onlyBalance),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Center(child: Text('No customers'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final balance = item.balance;
                      final balanceColor = balance > 0 ? Colors.red : Colors.green;
                      return ListTile(
                        title: Text(item.customer.name),
                        subtitle: Text(item.customer.phone ?? ''),
                        trailing: Text(balance.toStringAsFixed(2), style: TextStyle(color: balanceColor)),
                        onTap: () => context.go('/customers/${item.customer.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _notifyAll() async {
    final auth = ref.read(authControllerProvider);
    if (auth.role != UserRole.admin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin only')));
      return;
    }
    final repo = ref.read(customersRepositoryProvider);
    final list = await repo.watchWithBalance(onlyWithBalance: true).first;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No customers with balance')));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send reminders'),
        content: Text('Send reminders to ${list.length} customers?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Send')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(notificationServiceProvider).sendBulkBalanceReminders(list);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening WhatsApp for each customer...')));
    }
  }
}

