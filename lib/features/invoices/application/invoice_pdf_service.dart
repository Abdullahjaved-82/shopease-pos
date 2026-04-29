import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/features/invoices/application/currency_service.dart';
import 'package:pos_system/features/invoices/application/invoice_l10n.dart';
import 'package:pos_system/features/invoices/domain/document_models.dart';
import 'package:pos_system/features/settings/domain/shop_settings.dart';
import 'package:qr_flutter/qr_flutter.dart';

enum InvoiceTemplate {
  classic,
  modern,
  pakistani;

  String get dbValue => name;

  static InvoiceTemplate fromDb(String value) {
    return InvoiceTemplate.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => InvoiceTemplate.modern,
    );
  }
}

class InvoicePdfService {
  Future<Uint8List> generateInvoicePdf({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required ShopSettings settings,
    String? customerName,
    String? customerAddress,
    String? customerPhone,
  }) async {
    final template = InvoiceTemplate.fromDb(invoice.template);
    final locale = invoice.invoiceLanguage.isEmpty ? settings.defaultInvoiceLanguage : invoice.invoiceLanguage;
    final l10n = InvoiceL10n.of(locale);
    final currency = CurrencyService.byCode(invoice.currencyCode);
    final accent = _parseAccent(settings.accentColorHex);
    final qrImage = await _buildQrImage(
      '${invoice.invoiceNumber}|${invoice.total.toStringAsFixed(2)}|${invoice.dueDate?.toIso8601String() ?? ''}|${settings.phone}',
    );

    final doc = pw.Document();
    final logoImage = await _loadLogo(settings.logoPath);
    final urduFont = await _loadUrduFont();

    final theme = urduFont == null || !l10n.isUrdu
        ? null
        : pw.ThemeData.withFont(base: urduFont, bold: urduFont, italic: urduFont);

    final payload = _InvoicePdfPayload(
      invoice: invoice,
      items: items,
      settings: settings,
      customerName: customerName,
      customerAddress: customerAddress,
      customerPhone: customerPhone,
      l10n: l10n,
      currencyCode: currency.code,
      currencySymbol: currency.symbol,
      exchangeRateToPkr: invoice.exchangeRateToPkr <= 0 ? 1 : invoice.exchangeRateToPkr,
      accent: accent,
      logoImage: logoImage,
      qrImage: qrImage,
    );

    final builder = switch (template) {
      InvoiceTemplate.classic => _ClassicTemplateBuilder(),
      InvoiceTemplate.modern => _ModernTemplateBuilder(),
      InvoiceTemplate.pakistani => _PakistaniTemplateBuilder(),
    };

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => builder.build(payload),
      ),
    );

    return doc.save();
  }

  Future<pw.MemoryImage?> _loadLogo(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return pw.MemoryImage(await file.readAsBytes());
  }

  Future<pw.Font?> _loadUrduFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/NotoNastaliqUrdu-Regular.ttf');
      return pw.Font.ttf(data);
    } catch (_) {
      return null;
    }
  }

  Future<pw.MemoryImage?> _buildQrImage(String data) async {
    try {
      final painter = QrPainter(
        data: data,
        version: QrVersions.auto,
        gapless: true,
      );
      final byteData = await painter.toImageData(220, format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  PdfColor _parseAccent(String hex) {
    final clean = hex.replaceAll('#', '').toUpperCase();
    final withAlpha = clean.length == 6 ? 'FF$clean' : clean;
    final value = int.tryParse(withAlpha, radix: 16) ?? 0xFF1565C0;
    return PdfColor.fromInt(value);
  }
}

abstract class _TemplateBuilder {
  List<pw.Widget> build(_InvoicePdfPayload p);

  String m(double value, _InvoicePdfPayload p) => '${p.currencySymbol} ${value.toStringAsFixed(2)}';

  pw.Widget commonFooter(_InvoicePdfPayload p) {
    final pkr = p.invoice.total * p.exchangeRateToPkr;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('${p.l10n.t('pkrEquivalent')}: Rs ${pkr.toStringAsFixed(2)}'),
        if (p.qrImage != null) pw.Image(p.qrImage!, width: 70, height: 70),
      ],
    );
  }

  pw.Widget billTo(_InvoicePdfPayload p, {PdfColor? border}) {
    final b = border ?? PdfColors.grey500;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: b)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(p.l10n.t('billTo'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(p.invoice.billToName ?? p.customerName ?? '-'),
          if ((p.invoice.billToAddress ?? p.customerAddress ?? '').isNotEmpty) pw.Text(p.invoice.billToAddress ?? p.customerAddress ?? ''),
          if ((p.invoice.billToPhone ?? p.customerPhone ?? '').isNotEmpty) pw.Text(p.invoice.billToPhone ?? p.customerPhone ?? ''),
        ],
      ),
    );
  }
}

class _ClassicTemplateBuilder extends _TemplateBuilder {
  @override
  List<pw.Widget> build(_InvoicePdfPayload p) {
    return [
      _watermark(p),
      _header(p, colored: false),
      pw.SizedBox(height: 12),
      billTo(p),
      pw.SizedBox(height: 12),
      _items(p, rtl: false, striped: false),
      pw.SizedBox(height: 10),
      _totals(p, boxed: false),
      pw.SizedBox(height: 10),
      commonFooter(p),
    ];
  }
}

class _ModernTemplateBuilder extends _TemplateBuilder {
  @override
  List<pw.Widget> build(_InvoicePdfPayload p) {
    return [
      _watermark(p),
      _header(p, colored: true),
      pw.SizedBox(height: 14),
      billTo(p, border: p.accent),
      pw.SizedBox(height: 14),
      _items(p, rtl: false, striped: true),
      pw.SizedBox(height: 12),
      _totals(p, boxed: true),
      pw.SizedBox(height: 12),
      commonFooter(p),
    ];
  }
}

class _PakistaniTemplateBuilder extends _TemplateBuilder {
  @override
  List<pw.Widget> build(_InvoicePdfPayload p) {
    return [
      _watermark(p),
      pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(p, colored: true),
            pw.SizedBox(height: 12),
            billTo(p, border: p.accent),
            pw.SizedBox(height: 12),
            _items(p, rtl: true, striped: true),
            pw.SizedBox(height: 10),
            _totals(p, boxed: true),
            pw.SizedBox(height: 10),
            commonFooter(p),
          ],
        ),
      ),
    ];
  }
}

pw.Widget _header(_InvoicePdfPayload p, {required bool colored}) {
  final bg = colored ? p.accent : PdfColors.white;
  final fg = colored ? PdfColors.white : PdfColors.black;

  final docType = DocumentType.fromDb(p.invoice.docType);
  final heading = switch (docType) {
    DocumentType.invoice => p.l10n.t('invoice').toUpperCase(),
    DocumentType.quotation => p.l10n.t('quotation').toUpperCase(),
    DocumentType.proforma => p.l10n.t('proforma').toUpperCase(),
  };

  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    color: bg,
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            if (p.logoImage != null)
              pw.Container(
                width: 44,
                height: 44,
                margin: const pw.EdgeInsets.only(right: 8),
                child: pw.Image(p.logoImage!),
              ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(p.settings.name, style: pw.TextStyle(color: fg, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                if (p.settings.address.isNotEmpty) pw.Text(p.settings.address, style: pw.TextStyle(color: fg, fontSize: 9)),
                if (p.settings.phone.isNotEmpty) pw.Text(p.settings.phone, style: pw.TextStyle(color: fg, fontSize: 9)),
              ],
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(heading, style: pw.TextStyle(color: fg, fontWeight: pw.FontWeight.bold)),
            pw.Text('${p.l10n.t('invoiceNo')}: ${p.invoice.invoiceNumber}', style: pw.TextStyle(color: fg, fontSize: 9)),
            pw.Text('${p.l10n.t('date')}: ${DateFormat('dd MMM yyyy').format(p.invoice.issueDate)}', style: pw.TextStyle(color: fg, fontSize: 9)),
            if (p.invoice.dueDate != null)
              pw.Text('${p.l10n.t('dueDate')}: ${DateFormat('dd MMM yyyy').format(p.invoice.dueDate!)}', style: pw.TextStyle(color: fg, fontSize: 9)),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _watermark(_InvoicePdfPayload p) {
  final docType = DocumentType.fromDb(p.invoice.docType);
  final mark = switch (docType) {
    DocumentType.quotation => 'QUOTE',
    DocumentType.proforma => 'PRO FORMA',
    DocumentType.invoice => '',
  };
  if (mark.isEmpty) return pw.SizedBox.shrink();

  return pw.Center(
    child: pw.Transform.rotate(
      angle: -0.6,
      child: pw.Opacity(
        opacity: 0.10,
        child: pw.Text(
          mark,
          style: pw.TextStyle(fontSize: 72, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500),
        ),
      ),
    ),
  );
}

pw.Widget _items(_InvoicePdfPayload p, {required bool rtl, required bool striped}) {
  final headers = rtl
      ? [p.l10n.t('lineTotal'), p.l10n.t('unitPrice'), p.l10n.t('qty'), p.l10n.t('description')]
      : [p.l10n.t('description'), p.l10n.t('qty'), p.l10n.t('unitPrice'), p.l10n.t('lineTotal')];

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400),
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: p.accent),
        children: headers
            .map(
              (h) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold), textAlign: rtl ? pw.TextAlign.right : pw.TextAlign.left),
              ),
            )
            .toList(),
      ),
      ...p.items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        final cells = rtl
            ? [
                '${p.currencySymbol} ${item.lineTotal.toStringAsFixed(2)}',
                '${p.currencySymbol} ${item.unitPrice.toStringAsFixed(2)}',
                item.qty.toStringAsFixed(item.qty % 1 == 0 ? 0 : 2),
                item.description,
              ]
            : [
                item.description,
                item.qty.toStringAsFixed(item.qty % 1 == 0 ? 0 : 2),
                '${p.currencySymbol} ${item.unitPrice.toStringAsFixed(2)}',
                '${p.currencySymbol} ${item.lineTotal.toStringAsFixed(2)}',
              ];
        return pw.TableRow(
          decoration: striped && i.isEven ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
          children: cells
              .map(
                (c) => pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(c, textAlign: rtl ? pw.TextAlign.right : pw.TextAlign.left),
                ),
              )
              .toList(),
        );
      }),
    ],
  );
}

pw.Widget _totals(_InvoicePdfPayload p, {required bool boxed}) {
  final content = pw.Column(
    children: [
      _row('${p.l10n.t('subtotal')}:', '${p.currencySymbol} ${p.invoice.subtotal.toStringAsFixed(2)}'),
      _row('${p.l10n.t('discount')}:', '${p.currencySymbol} ${p.invoice.discountAmount.toStringAsFixed(2)}'),
      _row('${p.l10n.t('tax')}:', '${p.currencySymbol} ${p.invoice.taxAmount.toStringAsFixed(2)}'),
      pw.Divider(),
      _row('${p.l10n.t('total')}:', '${p.currencySymbol} ${p.invoice.total.toStringAsFixed(2)}', bold: true),
    ],
  );

  if (!boxed) return content;
  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Container(
      width: 220,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: p.accent, width: 1.5)),
      child: content,
    ),
  );
}

pw.Widget _row(String l, String v, {bool bold = false}) {
  final style = pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [pw.Text(l, style: style), pw.Text(v, style: style)],
  );
}

class _InvoicePdfPayload {
  const _InvoicePdfPayload({
    required this.invoice,
    required this.items,
    required this.settings,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.l10n,
    required this.currencyCode,
    required this.currencySymbol,
    required this.exchangeRateToPkr,
    required this.accent,
    required this.logoImage,
    required this.qrImage,
  });

  final Invoice invoice;
  final List<InvoiceItem> items;
  final ShopSettings settings;
  final String? customerName;
  final String? customerAddress;
  final String? customerPhone;
  final InvoiceL10n l10n;
  final String currencyCode;
  final String currencySymbol;
  final double exchangeRateToPkr;
  final PdfColor accent;
  final pw.MemoryImage? logoImage;
  final pw.MemoryImage? qrImage;
}



