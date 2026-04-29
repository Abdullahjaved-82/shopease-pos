import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/features/settings/domain/shop_settings.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceiptLine {
  ReceiptLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
}

class ReceiptPdfService {
  Future<Uint8List> generateA4Pdf({
    required Sale sale,
    required List<ReceiptLine> items,
    required ShopSettings settings,
    String? cashierName,
    String? fbrInvoiceNumber,
  }) async {
    final doc = pw.Document();
    final totals = _computeTotals(sale: sale, items: items, settings: settings);
    final timestamp = DateFormat('dd-MMM-yyyy hh:mm a').format(sale.createdAt);
    final qr = await _buildQrImage('sale:${sale.id}|total:${sale.totalAmount.toStringAsFixed(2)}');
    final logo = await _loadLogo(settings.logoPath);
    final urduFont = await _loadUrduFont();

    final baseTheme = urduFont == null ? null : pw.ThemeData.withFont(base: urduFont, bold: urduFont);
    final green = PdfColor.fromInt(0xFF01411C);
    final goldSoft = PdfColor.fromInt(0xFFFFF8DC);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(26),
        theme: baseTheme,
        build: (context) => [
          _buildA4Header(
            settings: settings,
            sale: sale,
            timestamp: timestamp,
            cashierName: cashierName,
            fbrInvoiceNumber: fbrInvoiceNumber,
            logo: logo,
            urduFont: urduFont,
          ),
          pw.SizedBox(height: 12),
          _buildA4ItemsTable(items, green: green, goldSoft: goldSoft),
          pw.SizedBox(height: 10),
          _buildTotalsBlock(totals, settings),
          pw.SizedBox(height: 10),
          _buildPaymentBlock(sale),
          pw.SizedBox(height: 12),
          _buildFooter(settings: settings, qr: qr, timestamp: timestamp),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> generateThermalPdf80mm({
    required Sale sale,
    required List<ReceiptLine> items,
    required ShopSettings settings,
    String? cashierName,
    String? fbrInvoiceNumber,
  }) async {
    final doc = pw.Document();
    final totals = _computeTotals(sale: sale, items: items, settings: settings);
    final timestamp = DateFormat('dd-MMM-yyyy hh:mm a').format(sale.createdAt);
    final qr = await _buildQrImage('sale:${sale.id}|total:${sale.totalAmount.toStringAsFixed(2)}');
    final urduFont = await _loadUrduFont();
    final shopNameIsUrdu = _containsUrdu(settings.name);
    final mono = pw.Font.courier();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, 240 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        theme: urduFont == null ? null : pw.ThemeData.withFont(base: urduFont, bold: urduFont),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              settings.name,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: shopNameIsUrdu ? urduFont : null,
                fontSize: shopNameIsUrdu ? 17 : 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          if (settings.address.isNotEmpty)
            pw.Center(child: pw.Text(settings.address, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
          if (settings.phone.isNotEmpty)
            pw.Center(child: pw.Text(settings.phone, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text('Tax Invoice / ٹیکس انوائس', style: pw.TextStyle(font: urduFont, fontSize: 9, fontWeight: pw.FontWeight.bold))),
          if (settings.fbrEnabled)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
                child: pw.Center(child: pw.Text('FBR: ${fbrInvoiceNumber ?? 'S-${sale.id}'}', style: const pw.TextStyle(fontSize: 8))),
              ),
            ),
          if (cashierName != null) pw.Padding(padding: const pw.EdgeInsets.only(top: 3), child: pw.Text('Cashier: $cashierName', style: const pw.TextStyle(fontSize: 8))),
          pw.SizedBox(height: 3),
          _dividerLine(),
          pw.SizedBox(height: 2),
          _buildThermalItemsTable(items, mono),
          pw.SizedBox(height: 3),
          _totalsRows(totals, settings, mono),
          pw.SizedBox(height: 2),
          _dividerLine(),
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              'Total: ${_formatPkrCompact(totals.total)}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 6),
          _buildPaymentBlock(sale),
          pw.SizedBox(height: 6),
          _buildFooter(settings: settings, qr: qr, timestamp: timestamp),
        ],
      ),
    );

    return doc.save();
  }

  bool _containsUrdu(String value) => RegExp(r'[\u0600-\u06FF]').hasMatch(value);

  Future<pw.Font?> _loadUrduFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/NotoNastaliqUrdu-Regular.ttf');
      return pw.Font.ttf(data);
    } catch (_) {
      return null;
    }
  }

  Future<pw.MemoryImage?> _loadLogo(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return pw.MemoryImage(await file.readAsBytes());
  }

  Future<pw.MemoryImage?> _buildQrImage(String data) async {
    try {
      final painter = QrPainter(data: data, version: QrVersions.auto, gapless: true);
      final bytes = await painter.toImageData(180, format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  _ReceiptTotals _computeTotals({required Sale sale, required List<ReceiptLine> items, required ShopSettings settings}) {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final discount = sale.discount;
    final taxable = (subtotal - discount).clamp(0, double.maxFinite).toDouble();
    final tax = settings.taxRate > 0 ? (taxable * (settings.taxRate / 100)).toDouble() : 0.0;
    return _ReceiptTotals(
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      total: sale.totalAmount,
    );
  }

  String _formatPkr(double value) => 'PKR ${value.toStringAsFixed(2)}';

  String _formatPkrCompact(double value) {
    final whole = value.roundToDouble() == value;
    final formatted = whole ? NumberFormat('#,##0').format(value) : NumberFormat('#,##0.##').format(value);
    return 'PKR $formatted';
  }

  pw.Widget _dividerLine() => pw.Text('================================', style: const pw.TextStyle(fontSize: 8));

  pw.Widget _buildA4Header({
    required ShopSettings settings,
    required Sale sale,
    required String timestamp,
    required String? cashierName,
    required String? fbrInvoiceNumber,
    required pw.MemoryImage? logo,
    required pw.Font? urduFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(
                width: 56,
                height: 56,
                margin: const pw.EdgeInsets.only(right: 10),
                child: pw.Image(logo),
              ),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(settings.name, style: pw.TextStyle(font: _containsUrdu(settings.name) ? urduFont : null, fontSize: 24, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                  if (settings.address.isNotEmpty) pw.Text(settings.address, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
                  if (settings.phone.isNotEmpty) pw.Text(settings.phone, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 6),
                  pw.Text('Tax Invoice / ٹیکس انوائس', style: pw.TextStyle(font: urduFont, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        if (settings.fbrEnabled)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
            child: pw.Text('FBR: ${fbrInvoiceNumber ?? 'S-${sale.id}'}', textAlign: pw.TextAlign.center),
          ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Invoice #${sale.id}'),
            pw.Text(timestamp),
            if (cashierName != null) pw.Text('Cashier: $cashierName'),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildA4ItemsTable(List<ReceiptLine> items, {required PdfColor green, required PdfColor goldSoft}) {
    return pw.TableHelper.fromTextArray(
      headers: const ['Item', 'Qty', 'Price', 'Total'],
      data: items
          .map(
            (item) => [
              item.name,
              item.quantity.toString(),
              _formatPkrCompact(item.unitPrice),
              _formatPkrCompact(item.lineTotal),
            ],
          )
          .toList(),
      headerDecoration: pw.BoxDecoration(color: green),
      headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
      oddRowDecoration: pw.BoxDecoration(color: goldSoft),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.4),
        3: const pw.FlexColumnWidth(1.4),
      },
      border: pw.TableBorder.all(color: PdfColors.grey500),
      cellStyle: const pw.TextStyle(fontSize: 10),
    );
  }

  pw.Widget _buildThermalItemsTable(List<ReceiptLine> items, pw.Font mono) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(3.3),
        1: const pw.FlexColumnWidth(0.9),
        2: const pw.FlexColumnWidth(1.3),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          children: [
            _tableCell('Item', mono, align: pw.TextAlign.left, bold: true),
            _tableCell('Qty', mono, align: pw.TextAlign.right, bold: true),
            _tableCell('Price', mono, align: pw.TextAlign.right, bold: true),
            _tableCell('Total', mono, align: pw.TextAlign.right, bold: true),
          ],
        ),
        ...items.map(
          (item) => pw.TableRow(
            children: [
              _tableCell(item.name, mono, align: pw.TextAlign.left),
              _tableCell(item.quantity.toString(), mono, align: pw.TextAlign.right),
              _tableCell(_formatPkrCompact(item.unitPrice).replaceFirst('PKR ', ''), mono, align: pw.TextAlign.right),
              _tableCell(_formatPkrCompact(item.lineTotal).replaceFirst('PKR ', ''), mono, align: pw.TextAlign.right),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _tableCell(String text, pw.Font mono, {required pw.TextAlign align, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: mono, fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        softWrap: true,
      ),
    );
  }

  pw.Widget _buildTotalsBlock(_ReceiptTotals totals, ShopSettings settings) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        child: pw.Column(
          children: [
            _totalsRow('Subtotal', totals.subtotal),
            if (totals.discount > 0) _totalsRow('Discount', totals.discount),
            if (settings.taxRate > 0) _totalsRow('Tax (${settings.taxRate.toStringAsFixed(2)}%)', totals.tax),
            pw.Divider(),
            _totalsRow('Total', totals.total, isBold: true),
          ],
        ),
      ),
    );
  }

  pw.Widget _totalsRows(_ReceiptTotals totals, ShopSettings settings, pw.Font mono) {
    return pw.Column(
      children: [
        _monoTotalsRow('Subtotal', totals.subtotal, mono),
        if (totals.discount > 0) _monoTotalsRow('Discount', totals.discount, mono),
        if (settings.taxRate > 0) _monoTotalsRow('Tax', totals.tax, mono),
      ],
    );
  }

  pw.Widget _monoTotalsRow(String label, double value, pw.Font mono) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: mono, fontSize: 8)),
        pw.Text(_formatPkrCompact(value), style: pw.TextStyle(font: mono, fontSize: 8)),
      ],
    );
  }

  pw.Widget _buildPaymentBlock(Sale sale) {
    final paidText = _formatPkrCompact(sale.paidAmount);
    final changeText = _formatPkrCompact(sale.changeAmount);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('${_prettyPaymentMethod(sale.paymentMethod)} وصول کیا', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text('Amount Tendered: $paidText'),
        pw.Text('Change: $changeText'),
      ],
    );
  }

  String _prettyPaymentMethod(String method) {
    final normalized = method.trim().toLowerCase();
    if (normalized.isEmpty) return 'Cash';
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  pw.Widget _buildFooter({required ShopSettings settings, required pw.MemoryImage? qr, required String timestamp}) {
    return pw.Column(
      children: [
        pw.Text('Shukriya! Dobara tashreef layen', textAlign: pw.TextAlign.center),
        if (settings.receiptFooter.isNotEmpty) pw.Text(settings.receiptFooter, textAlign: pw.TextAlign.center),
        if (qr != null) pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6), child: pw.Image(qr, width: 70, height: 70)),
        pw.Text(timestamp, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _totalsRow(String label, double value, {bool isBold = false}) {
    final style = pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(_formatPkr(value), style: style),
      ],
    );
  }
}

class _ReceiptTotals {
  const _ReceiptTotals({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
  });

  final double subtotal;
  final double discount;
  final double tax;
  final double total;
}

