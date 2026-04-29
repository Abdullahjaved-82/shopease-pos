import 'dart:io';

import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pos_system/core/database/app_database.dart';

class ExportService {
  ExportService(this._db);

  final AppDatabase _db;

  Future<String> exportAll({required DateTime start, required DateTime end}) async {
    final excel = Excel.createExcel();

    await _writeSalesSheet(excel, start, end);
    await _writeProductsSheet(excel);
    await _writeCustomersSheet(excel);
    await _writeExpensesSheet(excel, start, end);
    await _writeMovementsSheet(excel, start, end);

    final bytes = excel.save()!;
    final downloads = await getDownloadsDirectory();
    final dir = downloads ?? await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'shopease_export_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<void> shareFile(String path) async {
    await Share.shareXFiles([XFile(path)]);
  }

  Future<void> _writeSalesSheet(Excel excel, DateTime start, DateTime end) async {
    final sheet = excel['Sales'];
    sheet.appendRow([
      TextCellValue('SaleId'),
      TextCellValue('Date'),
      TextCellValue('CustomerId'),
      TextCellValue('PaymentMethod'),
      TextCellValue('Total'),
      TextCellValue('ProductId'),
      TextCellValue('Qty'),
      TextCellValue('UnitPrice'),
      TextCellValue('LineTotal'),
    ]);

    final sales = await (_db.select(_db.sales)
          ..where((s) => s.createdAt.isBiggerOrEqualValue(start) & s.createdAt.isSmallerThanValue(end))
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
        .get();

    for (final sale in sales) {
      final items = await (_db.select(_db.saleItems)..where((i) => i.saleId.equals(sale.id))).get();
      if (items.isEmpty) {
        sheet.appendRow([
          IntCellValue(sale.id),
          TextCellValue(sale.createdAt.toIso8601String()),
          TextCellValue('${sale.customerId ?? ''}'),
          TextCellValue(sale.paymentMethod),
          DoubleCellValue(sale.totalAmount),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
        ]);
      } else {
        for (final item in items) {
          sheet.appendRow([
            IntCellValue(sale.id),
            TextCellValue(sale.createdAt.toIso8601String()),
            TextCellValue('${sale.customerId ?? ''}'),
            TextCellValue(sale.paymentMethod),
            DoubleCellValue(sale.totalAmount),
            IntCellValue(item.productId),
            IntCellValue(item.quantity),
            DoubleCellValue(item.unitPrice),
            DoubleCellValue(item.lineTotal),
          ]);
        }
      }
    }
  }

  Future<void> _writeProductsSheet(Excel excel) async {
    final sheet = excel['Products'];
    sheet.appendRow([
      TextCellValue('Id'),
      TextCellValue('Name'),
      TextCellValue('SKU'),
      TextCellValue('CategoryId'),
      TextCellValue('CostPrice'),
      TextCellValue('SalePrice'),
      TextCellValue('Stock'),
      TextCellValue('Unit'),
      TextCellValue('ReorderLevel'),
    ]);
    final rows = await _db.select(_db.products).get();
    for (final pRow in rows) {
      sheet.appendRow([
        IntCellValue(pRow.id),
        TextCellValue(pRow.name),
        TextCellValue(pRow.barcode ?? ''),
        TextCellValue('${pRow.categoryId ?? ''}'),
        DoubleCellValue(pRow.costPrice),
        DoubleCellValue(pRow.salePrice),
        IntCellValue(pRow.stockQuantity),
        TextCellValue(pRow.unit),
        IntCellValue(pRow.reorderLevel),
      ]);
    }
  }

  Future<void> _writeCustomersSheet(Excel excel) async {
    final sheet = excel['Customers'];
    sheet.appendRow([
      TextCellValue('Id'),
      TextCellValue('Name'),
      TextCellValue('Phone'),
      TextCellValue('CNIC'),
      TextCellValue('Address'),
      TextCellValue('CreditLimit'),
    ]);
    final rows = await _db.select(_db.customers).get();
    for (final c in rows) {
      sheet.appendRow([
        IntCellValue(c.id),
        TextCellValue(c.name),
        TextCellValue(c.phone ?? ''),
        TextCellValue(c.cnic ?? ''),
        TextCellValue(c.address ?? ''),
        DoubleCellValue(c.creditLimit),
      ]);
    }
  }

  Future<void> _writeExpensesSheet(Excel excel, DateTime start, DateTime end) async {
    final sheet = excel['Expenses'];
    sheet.appendRow([
      TextCellValue('Id'),
      TextCellValue('Title'),
      TextCellValue('Category'),
      TextCellValue('Amount'),
      TextCellValue('IncurredOn'),
      TextCellValue('Note'),
    ]);
    final rows = await (_db.select(_db.expenses)
          ..where((e) => e.incurredOn.isBiggerOrEqualValue(start) & e.incurredOn.isSmallerThanValue(end)))
        .get();
    for (final e in rows) {
      sheet.appendRow([
        IntCellValue(e.id),
        TextCellValue(e.title),
        TextCellValue(e.category ?? ''),
        DoubleCellValue(e.amount),
        TextCellValue(e.incurredOn.toIso8601String()),
        TextCellValue(e.note ?? ''),
      ]);
    }
  }

  Future<void> _writeMovementsSheet(Excel excel, DateTime start, DateTime end) async {
    final sheet = excel['InventoryMovements'];
    sheet.appendRow([
      TextCellValue('Id'),
      TextCellValue('ProductId'),
      TextCellValue('Type'),
      TextCellValue('Qty'),
      TextCellValue('CreatedAt'),
      TextCellValue('Note'),
    ]);
    final rows = await (_db.select(_db.stockMovements)
          ..where((m) => m.createdAt.isBiggerOrEqualValue(start) & m.createdAt.isSmallerThanValue(end)))
        .get();
    for (final m in rows) {
      sheet.appendRow([
        IntCellValue(m.id),
        IntCellValue(m.productId),
        TextCellValue(m.type),
        IntCellValue(m.qty),
        TextCellValue(m.createdAt.toIso8601String()),
        TextCellValue(m.note ?? ''),
      ]);
    }
  }
}


