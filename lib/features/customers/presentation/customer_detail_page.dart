import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';
import 'package:pos_system/features/auth/domain/user_role.dart';
import 'package:pos_system/features/shared/application/notification_service.dart';

class CustomerDetailPage extends ConsumerStatefulWidget {
  const CustomerDetailPage({super.key, required this.id});
  final int id;

  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final repo = ref.read(customersRepositoryProvider);
    final bal = await repo.getBalance(widget.id);
    if (mounted) setState(() => _balance = bal);
  }

  @override
  Widget build(BuildContext context) {
    final customersRepo = ref.watch(customersRepositoryProvider);
    final salesRepo = ref.watch(salesRepositoryProvider);
    final auth = ref.watch(authControllerProvider);
    final isAdmin = auth.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.go('/customers/${widget.id}/edit'),
          ),
        ],
      ),
      body: FutureBuilder<Customer?>(
        future: customersRepo.getById(widget.id),
        builder: (context, snapshot) {
          final customer = snapshot.data;
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (customer == null) {
            return const Center(child: Text('Customer not found'));
          }
          final balanceColor = _balance > 0 ? Colors.red : Colors.green;
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(customer.phone ?? ''),
                Text(customer.address ?? ''),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Balance: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(_balance.toStringAsFixed(2), style: TextStyle(color: balanceColor, fontSize: 18)),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.payments),
                      label: const Text('Record Payment'),
                      onPressed: () => _recordPayment(context, customer),
                    ),
                  ],
                ),
                if (isAdmin && (customer.phone ?? '').isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Send Balance Reminder'),
                    onPressed: () => ref.read(notificationServiceProvider).sendBalanceReminder(customer: customer, balance: _balance),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _HistoryCard(
                          title: 'Sales',
                          child: StreamBuilder<List<Sale>>(
                            stream: salesRepo.watchAll(),
                            builder: (context, snap) {
                              final list = (snap.data ?? []).where((s) => s.customerId == widget.id).toList();
                              return _salesList(list);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HistoryCard(
                          title: 'Payments',
                          child: StreamBuilder<List<CustomerPayment>>(
                            stream: customersRepo.getPaymentHistory(widget.id),
                            builder: (context, snap) {
                              final list = snap.data ?? [];
                              return _paymentList(list);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HistoryCard(
                          title: 'Loyalty Points',
                          child: _LoyaltyCard(customerId: widget.id),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _salesList(List<Sale> sales) {
    if (sales.isEmpty) return const Center(child: Text('No sales'));
    final df = DateFormat('MM/dd');
    return ListView.separated(
      itemCount: sales.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final s = sales[index];
        return ListTile(
          title: Text('Sale #${s.id}'),
          subtitle: Text(df.format(s.createdAt)),
          trailing: Text(s.totalAmount.toStringAsFixed(2)),
        );
      },
    );
  }

  Widget _paymentList(List<CustomerPayment> payments) {
    if (payments.isEmpty) return const Center(child: Text('No payments'));
    final df = DateFormat('MM/dd');
    return ListView.separated(
      itemCount: payments.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = payments[index];
        return ListTile(
          title: Text(p.amount.toStringAsFixed(2)),
          subtitle: Text(df.format(p.createdAt)),
          trailing: Text(p.note ?? ''),
        );
      },
    );
  }

  Future<void> _recordPayment(BuildContext context, Customer customer) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final auth = ref.read(authControllerProvider);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (result == true) {
      final amount = double.tryParse(amountCtrl.text) ?? 0;
      if (amount > 0) {
        await ref.read(customersRepositoryProvider).recordPayment(
              customerId: customer.id,
              amount: amount,
              note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              userId: auth.userId ?? 0,
            );
        await _loadBalance();
      }
    }
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _LoyaltyCard extends ConsumerStatefulWidget {
  const _LoyaltyCard({required this.customerId});
  final int customerId;

  @override
  ConsumerState<_LoyaltyCard> createState() => _LoyaltyCardState();
}

class _LoyaltyCardState extends ConsumerState<_LoyaltyCard> {
  int _balance = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(loyaltyRepositoryProvider);
    final bal = await repo.getBalance(widget.customerId);
    if (mounted) setState(() => _balance = bal);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text('Balance: $_balance pts', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<LoyaltyTransaction>>(
            stream: ref.read(loyaltyRepositoryProvider).getHistory(widget.customerId),
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return const Center(child: Text('No loyalty activity'));
              }
              final df = DateFormat('MM/dd HH:mm');
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final tx = list[index];
                  final isEarn = tx.points > 0;
                  return ListTile(
                    leading: Icon(isEarn ? Icons.add_circle : Icons.remove_circle, color: isEarn ? Colors.green : Colors.red),
                    title: Text('${tx.type} ${tx.points} pts'),
                    subtitle: Text(df.format(tx.createdAt)),
                    trailing: Text(tx.note ?? ''),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

