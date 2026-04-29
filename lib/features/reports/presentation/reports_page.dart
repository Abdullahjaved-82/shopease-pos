import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/core/repositories/reports_repository.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';
import 'package:pos_system/features/auth/domain/user_role.dart';
import 'package:share_plus/share_plus.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateTimeRange? _range;
  bool _loading = true;
  RangeSummary? _summary;
  ExpenseSummary? _expenses;
  List<DailyRevenueRow> _daily = const [];
  List<TopProduct> _topProducts = const [];
  final _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    _range = DateTimeRange(start: start, end: start.add(const Duration(days: 1)));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(reportsRepositoryProvider);
    final start = _range!.start;
    final end = _range!.end;
    final summary = await repo.getRangeSummary(start, end);
    final expenses = await repo.getExpenseSummary(start, end);
    final daily = await repo.getDailyRevenueBetween(start, end);
    final top = await repo.getTopProducts(start, end, 5);
    setState(() {
      _summary = summary;
      _expenses = expenses;
      _daily = daily;
      _topProducts = top;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth.role != UserRole.admin) {
      return const Scaffold(body: Center(child: Text('Permission denied')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/reports/shifts'),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Shift summary'),
          ),
          TextButton.icon(
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Export PDF'),
          ),
          TextButton.icon(
            onPressed: _exportCsv,
            icon: const Icon(Icons.table_chart),
            label: const Text('Export CSV'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _RangePicker(
                    range: _range!,
                    onChanged: (r) => setState(() {
                      _range = r;
                      _load();
                    }),
                  ),
                  const SizedBox(height: 12),
                  _SummaryGrid(summary: _summary!, expenses: _expenses!),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              Expanded(
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: RepaintBoundary(
                                      key: _chartKey,
                                      child: _RevenueChart(data: _daily),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: _ExpensesList(expenses: _expenses!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: _TopProductsTable(products: _topProducts),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<Uint8List?> _captureChart() async {
    final boundary = _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _exportPdf() async {
    if (_summary == null || _expenses == null || _range == null) return;
    final chartBytes = await _captureChart();
    final pdf = pw.Document();
    final df = DateFormat('yyyy-MM-dd');
    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Report ${df.format(_range!.start)} - ${df.format(_range!.end)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Wrap(spacing: 12, runSpacing: 12, children: [
                _pdfCard('Revenue', _summary!.revenue),
                _pdfCard('Gross Profit', _summary!.grossProfit),
                _pdfCard('Expenses', _expenses!.total),
                _pdfCard('Net Profit', _summary!.grossProfit - _expenses!.total),
              ]),
              pw.SizedBox(height: 12),
              if (chartBytes != null) pw.Image(pw.MemoryImage(chartBytes), height: 240),
              pw.SizedBox(height: 12),
              pw.Text('Top Products', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Table.fromTextArray(
                headers: ['Name', 'Qty', 'Revenue', 'Profit'],
                data: _topProducts
                    .map((p) => [p.name, p.qty.toString(), p.revenue.toStringAsFixed(2), p.profit.toStringAsFixed(2)])
                    .toList(),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Expenses by category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _expenses!.byCategory.entries
                    .map((e) => pw.Text('${e.key}: ${e.value.toStringAsFixed(2)}'))
                    .toList(),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], subject: 'Report');
  }

  pw.Widget _pdfCard(String title, double value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: pdf.PdfColors.grey)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(value.toStringAsFixed(2)),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    if (_range == null) return;
    final repo = ref.read(reportsRepositoryProvider);
    final rows = await repo.getSalesRows(_range!.start, _range!.end);
    final buffer = StringBuffer('id,total,discount,payment,paid,change,createdAt\n');
    for (final r in rows) {
      buffer.writeln('${r['id']},${r['total_amount']},${r['discount']},${r['payment_method']},${r['paid_amount']},${r['change_amount']},${r['created_at']}');
    }
    final bytes = utf8.encode(buffer.toString());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], subject: 'Report CSV');
  }
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({required this.range, required this.onChanged});

  final DateTimeRange range;
  final ValueChanged<DateTimeRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DropdownButton<DateTimeRange>(
          value: null,
          hint: const Text('Quick range'),
          items: [
            DropdownMenuItem(
              value: _today(),
              child: const Text('Today'),
            ),
            DropdownMenuItem(
              value: _thisWeek(),
              child: const Text('This week'),
            ),
            DropdownMenuItem(
              value: _thisMonth(),
              child: const Text('This month'),
            ),
          ],
          onChanged: (r) {
            if (r != null) onChanged(r);
          },
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2023),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: range,
            );
            if (picked != null) onChanged(picked);
          },
          child: Text('${DateFormat('yyyy-MM-dd').format(range.start)} - ${DateFormat('yyyy-MM-dd').format(range.end)}'),
        ),
      ],
    );
  }

  static DateTimeRange _today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: start, end: start.add(const Duration(days: 1)));
  }

  static DateTimeRange _thisWeek() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final s = DateTime(start.year, start.month, start.day);
    return DateTimeRange(start: s, end: s.add(const Duration(days: 7)));
  }

  static DateTimeRange _thisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return DateTimeRange(start: start, end: DateTime(now.year, now.month + 1, 1));
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.expenses});

  final RangeSummary summary;
  final ExpenseSummary expenses;

  @override
  Widget build(BuildContext context) {
    final net = summary.grossProfit - expenses.total;
    return Row(
      children: [
        _card('Revenue', summary.revenue),
        _card('Gross Profit', summary.grossProfit),
        _card('Expenses', expenses.total),
        _card('Net Profit', net),
      ],
    );
  }

  Widget _card(String title, double value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.data});
  final List<DailyRevenueRow> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data'));
    }
    final spots = data
        .asMap()
        .entries
        .map((e) => BarChartRodData(toY: e.value.revenue, width: 14))
        .toList();
    return BarChart(
      BarChartData(
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox();
                final d = data[index].date;
                return Text(DateFormat('MM/dd').format(d), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        barGroups: spots
            .asMap()
            .entries
            .map(
              (e) => BarChartGroupData(x: e.key, barRods: [e.value]),
            )
            .toList(),
      ),
    );
  }
}

class _TopProductsTable extends StatelessWidget {
  const _TopProductsTable({required this.products});
  final List<TopProduct> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Top Products', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: products.isEmpty
              ? const Center(child: Text('No data'))
              : ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    return ListTile(
                      dense: true,
                      title: Text(p.name),
                      subtitle: Text('Qty: ${p.qty}'),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Rev: ${p.revenue.toStringAsFixed(2)}'),
                          Text('Profit: ${p.profit.toStringAsFixed(2)}'),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ExpensesList extends StatelessWidget {
  const _ExpensesList({required this.expenses});
  final ExpenseSummary expenses;

  @override
  Widget build(BuildContext context) {
    if (expenses.byCategory.isEmpty) {
      return const Center(child: Text('No expenses'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: expenses.byCategory.entries
                .map((e) => ListTile(title: Text(e.key), trailing: Text(e.value.toStringAsFixed(2))))
                .toList(),
          ),
        ),
      ],
    );
  }
}
