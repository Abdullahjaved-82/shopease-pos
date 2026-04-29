import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/repositories/dashboard_repository.dart';
import 'package:pos_system/core/repositories/invoice_repository.dart';
import 'package:pos_system/features/dashboard/application/dashboard_providers.dart';
import 'package:pos_system/features/dashboard/presentation/widgets/shop_header_widget.dart';
import 'package:pos_system/features/invoices/application/overdue_invoices_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  Timer? _desktopRefreshTimer;

  @override
  void initState() {
    super.initState();
    _desktopRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _refreshProviders();
    });
  }

  @override
  void dispose() {
    _desktopRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    _refreshProviders();
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  void _refreshProviders() {
    ref.invalidate(dashboardTodaySummaryProvider);
    ref.invalidate(dashboardWeeklySalesProvider);
    ref.invalidate(dashboardTopProductsProvider);
    ref.invalidate(dashboardRecentTransactionsProvider);
    ref.invalidate(dashboardLowStockProvider);
    ref.invalidate(overdueInvoiceSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardTodaySummaryProvider);
    final weeklyAsync = ref.watch(dashboardWeeklySalesProvider);
    final topAsync = ref.watch(dashboardTopProductsProvider);
    final recentAsync = ref.watch(dashboardRecentTransactionsProvider);
    final lowStockAsync = ref.watch(dashboardLowStockProvider);
    final overdueAsync = ref.watch(overdueInvoiceSummaryProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final content = ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const ShopHeaderWidget(),
            const SizedBox(height: 16),
            Row(
              children: [
                const Spacer(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(onPressed: () => context.go('/sales'), icon: const Icon(Icons.point_of_sale), label: const Text('New Sale')),
                    OutlinedButton.icon(onPressed: () => context.go('/invoices/new'), icon: const Icon(Icons.receipt_long), label: const Text('New Invoice')),
                    OutlinedButton.icon(onPressed: () => context.go('/products/new'), icon: const Icon(Icons.add_box_outlined), label: const Text('Add Product')),
                    OutlinedButton.icon(onPressed: () => context.go('/reports'), icon: const Icon(Icons.bar_chart), label: const Text('View Reports')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            summaryAsync.when(
              data: (s) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _AnimatedMetricCard(title: 'Today\'s Sales', icon: Icons.payments_outlined, target: s.todaySales, index: 0, isCurrency: true),
                  _AnimatedMetricCard(title: 'Today\'s Profit', icon: Icons.trending_up, target: s.todayProfit, index: 1, isCurrency: true),
                  _AnimatedMetricCard(title: 'Transactions Count', icon: Icons.receipt_long_outlined, target: s.transactionsCount.toDouble(), index: 2),
                  _AnimatedMetricCard(title: 'Items Sold', icon: Icons.shopping_basket_outlined, target: s.itemsSold.toDouble(), index: 3),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load summary: $e'),
            ),
            const SizedBox(height: 16),
            isMobile
                ? Column(
                    children: [
                      _weeklyCard(weeklyAsync),
                      const SizedBox(height: 12),
                      _topProductsCard(topAsync),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _weeklyCard(weeklyAsync)),
                      const SizedBox(width: 12),
                      Expanded(child: _topProductsCard(topAsync)),
                    ],
                  ),
            const SizedBox(height: 16),
            isMobile
                ? Column(
                    children: [
                      _recentTransactionsCard(recentAsync),
                      const SizedBox(height: 12),
                      _lowStockCard(lowStockAsync),
                      const SizedBox(height: 12),
                      _overdueCard(overdueAsync),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _recentTransactionsCard(recentAsync)),
                      const SizedBox(width: 12),
                      Expanded(child: _lowStockCard(lowStockAsync)),
                      const SizedBox(width: 12),
                      Expanded(child: _overdueCard(overdueAsync)),
                    ],
                  ),
          ],
        );

        return RefreshIndicator(onRefresh: _onRefresh, child: content);
      },
    );
  }
  Widget _weeklyCard(AsyncValue<List<WeeklySalesPoint>> weeklyAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 280,
          child: weeklyAsync.when(
            data: (points) {
              if (points.isEmpty) return const Center(child: Text('No weekly data'));
              final maxY = points.map((e) => e.revenue).fold<double>(0.0, (m, v) => v > m ? v : m);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Weekly Revenue (Last 7 days)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        maxY: maxY <= 0.0 ? 10.0 : maxY * 1.2,
                        barGroups: [
                          for (var i = 0; i < points.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [BarChartRodData(toY: points[i].revenue, width: 16.0)],
                            ),
                        ],
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                                return Text(DateFormat('E').format(points[idx].date));
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Weekly chart error: $e')),
          ),
        ),
      ),
    );
  }

  Widget _topProductsCard(AsyncValue<List<TopProductToday>> topAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 280,
          child: topAsync.when(
            data: (rows) {
              if (rows.isEmpty) return const Center(child: Text('No product sales today'));
              final maxY = rows.map((e) => e.qty).fold<int>(0, (m, v) => v > m ? v : m).toDouble();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Top 5 Products Today', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        maxY: maxY <= 0.0 ? 5.0 : maxY * 1.2,
                        barGroups: [
                          for (var i = 0; i < rows.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: rows[i].qty.toDouble(),
                                  width: 16.0,
                                  color: Colors.deepPurple,
                                ),
                              ],
                            ),
                        ],
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= rows.length) return const SizedBox.shrink();
                                final name = rows[idx].name;
                                return Text(name.length > 8 ? '${name.substring(0, 8)}…' : name);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Top products error: $e')),
          ),
        ),
      ),
    );
  }

  Widget _recentTransactionsCard(AsyncValue<List<Sale>> recentAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 320,
          child: recentAsync.when(
            data: (sales) {
              if (sales.isEmpty) return const Center(child: Text('No recent transactions'));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: sales.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final s = sales[index];
                        return ListTile(
                          dense: true,
                          title: Text('Sale #${s.id}'),
                          subtitle: Text(DateFormat('dd MMM, hh:mm a').format(s.createdAt as DateTime)),
                          trailing: Text('PKR ${(s.totalAmount as double).toStringAsFixed(2)}'),
                          onTap: () => context.go('/sales/receipt/${s.id}'),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Recent transactions error: $e')),
          ),
        ),
      ),
    );
  }

  Widget _lowStockCard(AsyncValue<List<Product>> lowStockAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 320,
          child: lowStockAsync.when(
            data: (products) {
              if (products.isEmpty) return const Center(child: Text('No low stock alerts'));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Low Stock Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = products[index];
                        return ListTile(
                          dense: true,
                          title: Text(p.name as String),
                          subtitle: Text('Reorder ${p.reorderLevel}'),
                          trailing: Text('${p.stockQuantity}', style: const TextStyle(color: Colors.red)),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Low stock error: $e')),
          ),
        ),
      ),
    );
  }

  Widget _overdueCard(AsyncValue<OverdueInvoiceSummary> overdueAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 320,
          child: overdueAsync.when(
            data: (summary) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Overdue Invoices', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('Count: ${summary.count}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Total: PKR ${summary.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => context.go('/invoices'),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Open Invoices'),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Overdue summary error: $e')),
          ),
        ),
      ),
    );
  }
}

class _AnimatedMetricCard extends StatefulWidget {
  const _AnimatedMetricCard({
    required this.title,
    required this.icon,
    required this.target,
    required this.index,
    this.isCurrency = false,
  });

  final String title;
  final IconData icon;
  final double target;
  final int index;
  final bool isCurrency;

  @override
  State<_AnimatedMetricCard> createState() => _AnimatedMetricCardState();
}

class _AnimatedMetricCardState extends State<_AnimatedMetricCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _valueAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _valueAnimation = Tween<double>(begin: 0.0, end: widget.target).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future<void>.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedMetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _valueAnimation = Tween<double>(begin: 0.0, end: widget.target).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SizedBox(
          width: 280,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(widget.icon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        AnimatedBuilder(
                          animation: _valueAnimation,
                          builder: (context, child) {
                            final v = _valueAnimation.value;
                            final text = widget.isCurrency ? 'PKR ${v.toStringAsFixed(2)}' : '${v.round()}';
                            return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

