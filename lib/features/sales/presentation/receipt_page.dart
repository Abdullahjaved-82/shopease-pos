import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';
import 'package:pos_system/features/sales/application/receipt_service.dart';
import 'package:pos_system/features/settings/application/shop_settings_controller.dart';
import 'package:pos_system/features/shared/application/notification_service.dart';

class ReceiptPage extends ConsumerStatefulWidget {
  const ReceiptPage({super.key, required this.saleId});

  final int saleId;

  @override
  ConsumerState<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends ConsumerState<ReceiptPage> {
  Uint8List? _a4Bytes;
  Uint8List? _thermalBytes;
  Sale? _sale;
  Customer? _customer;
  List<String> _itemSummaries = const [];
  double _balance = 0;
  bool _loading = true;
  bool _autoPrompted = false;
  ReceiptPrintLayout _layout = ReceiptPrintLayout.thermal80;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    final salesRepo = ref.read(salesRepositoryProvider);
    final saleItemsRepo = ref.read(saleItemsRepositoryProvider);
    final productsRepo = ref.read(productsRepositoryProvider);
    final customersRepo = ref.read(customersRepositoryProvider);
    final settings = await ref.read(shopSettingsControllerProvider.future);
    final auth = ref.read(authControllerProvider);

    final sale = await salesRepo.getById(widget.saleId);
    if (sale == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    final rawItems = await saleItemsRepo.getForSale(widget.saleId);
    final products = <int, Product?>{};
    for (final item in rawItems) {
      products[item.productId] ??= await productsRepo.getById(item.productId);
    }

    Customer? customer;
    double balance = 0;
    if (sale.customerId != null) {
      customer = await customersRepo.getById(sale.customerId!);
      if (customer != null) {
        balance = await customersRepo.getBalance(customer.id);
      }
    }

    final receiptLines = rawItems
        .map(
          (i) => ReceiptLine(
            name: products[i.productId]?.name ?? 'Item #${i.productId}',
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            lineTotal: i.lineTotal,
          ),
        )
        .toList();

    final itemSummaries = receiptLines
        .map((i) => '${i.name} x${i.quantity} = ${i.lineTotal.toStringAsFixed(2)}')
        .toList();

    final service = ReceiptPdfService();
    final a4Bytes = await service.generateA4Pdf(
      sale: sale,
      items: receiptLines,
      settings: settings,
      cashierName: auth.userName,
    );
    final thermal = await service.generateThermalPdf80mm(
      sale: sale,
      items: receiptLines,
      settings: settings,
      cashierName: auth.userName,
    );

    if (!mounted) return;

    setState(() {
      _sale = sale;
      _customer = customer;
      _balance = balance;
      _itemSummaries = itemSummaries;
      _a4Bytes = a4Bytes;
      _thermalBytes = thermal;
      _loading = false;
    });

    if (customer != null && sale.totalAmount > 0 && !_autoPrompted) {
      _autoPrompted = true;
      await ref.read(notificationServiceProvider).sendReceipt(
            sale: sale,
            itemSummaries: itemSummaries,
            customer: customer,
            balance: balance,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Receipt #${widget.saleId}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sale == null
              ? const Center(child: Text('Sale not found'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.print),
                            label: const Text('Print'),
                            onPressed: _selectedBytes == null
                                ? null
                                : () => Printing.layoutPdf(onLayout: (_) async => _selectedBytes!),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                            onPressed: _selectedBytes == null ? null : _share,
                          ),
                          const SizedBox(width: 8),
                          SegmentedButton<ReceiptPrintLayout>(
                            segments: const [
                              ButtonSegment(value: ReceiptPrintLayout.thermal80, label: Text('Thermal 80mm')),
                              ButtonSegment(value: ReceiptPrintLayout.a4, label: Text('A4')),
                            ],
                            selected: <ReceiptPrintLayout>{_layout},
                            onSelectionChanged: (selection) {
                              if (selection.isEmpty) return;
                              setState(() => _layout = selection.first);
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.chat),
                            label: const Text('Send WhatsApp Receipt'),
                            onPressed: _sale == null
                                ? null
                                : () => ref.read(notificationServiceProvider).sendReceipt(
                                      sale: _sale!,
                                      itemSummaries: _itemSummaries,
                                      customer: _customer,
                                      balance: _balance,
                                    ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _selectedBytes == null
                          ? const Center(child: Text('Receipt preview unavailable'))
                          : PdfPreview(
                              canDebug: false,
                              canChangePageFormat: false,
                              canChangeOrientation: false,
                              maxPageWidth: 700,
                              build: (_) async => _selectedBytes!,
                            ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _share() async {
    if (_selectedBytes == null) return;
    final dir = await getTemporaryDirectory();
    final suffix = _layout == ReceiptPrintLayout.a4 ? 'a4' : '80mm';
    final file = File('${dir.path}/receipt_${widget.saleId}_$suffix.pdf');
    await file.writeAsBytes(_selectedBytes!, flush: true);
    await Share.shareXFiles([XFile(file.path)], subject: 'Receipt #${widget.saleId}');
  }

  Uint8List? get _selectedBytes {
    return _layout == ReceiptPrintLayout.a4 ? _a4Bytes : _thermalBytes;
  }
}

enum ReceiptPrintLayout { thermal80, a4 }
