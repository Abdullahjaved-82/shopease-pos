import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' show Value;
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pos_system/core/database/app_database.dart';

class ProductImportRow {
  const ProductImportRow({
    required this.name,
    required this.sku,
    required this.category,
    required this.costPrice,
    required this.salePrice,
    required this.stock,
    required this.unit,
    required this.reorderLevel,
    this.skipReason,
  });

  final String name;
  final String sku;
  final String category;
  final double costPrice;
  final double salePrice;
  final int stock;
  final String unit;
  final int reorderLevel;
  final String? skipReason;

  bool get isValid => skipReason == null;
}

class ProductImportSummary {
  const ProductImportSummary({
    required this.added,
    required this.updated,
    required this.skipped,
    required this.skippedReasons,
  });

  final int added;
  final int updated;
  final int skipped;
  final List<String> skippedReasons;
}

class ImportService {
  ImportService(this._db);

  final AppDatabase _db;

  Future<String> createTemplateCsv() async {
    final downloads = await getDownloadsDirectory();
    final dir = downloads ?? await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'products_import_template.csv');

    final rows = [
      ['name', 'sku', 'category', 'costPrice', 'salePrice', 'stock', 'unit', 'reorderLevel'],
      ['Milk 1L', 'MILK001', 'Dairy', '180', '220', '40', 'pcs', '10'],
      ['Sugar 1kg', 'SUGAR001', 'Grocery', '130', '150', '80', 'kg', '15'],
    ];

    final csv = const ListToCsvConverter().convert(rows);
    await File(path).writeAsString(csv, flush: true);
    return path;
  }

  Future<List<ProductImportRow>> parseFile(String filePath) async {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.csv') {
      return _parseCsv(await File(filePath).readAsString());
    }
    if (ext == '.xlsx') {
      return _parseXlsx(await File(filePath).readAsBytes());
    }
    throw Exception('Unsupported file type: $ext');
  }

  Future<ProductImportSummary> importRows(List<ProductImportRow> rows) async {
    final categories = await _db.select(_db.categories).get();
    final categoryByName = <String, Category>{
      for (final c in categories) c.name.trim().toLowerCase(): c,
    };

    final existing = await _db.select(_db.products).get();
    final productBySku = <String, Product>{
      for (final p in existing)
        if ((p.barcode ?? '').trim().isNotEmpty) p.barcode!.trim().toLowerCase(): p,
    };

    int added = 0;
    int updated = 0;
    int skipped = 0;
    final skippedReasons = <String>[];

    await _db.transaction(() async {
      for (final row in rows) {
        if (!row.isValid) {
          skipped++;
          skippedReasons.add('${row.name.isEmpty ? row.sku : row.name}: ${row.skipReason}');
          continue;
        }

        int? categoryId;
        final categoryName = row.category.trim().toLowerCase();
        if (categoryName.isNotEmpty) {
          final existingCategory = categoryByName[categoryName];
          if (existingCategory != null) {
            categoryId = existingCategory.id;
          } else {
            final newId = await _db.into(_db.categories).insert(
                  CategoriesCompanion.insert(name: row.category.trim(), colorHex: const Value('#607D8B')),
                );
            categoryByName[categoryName] = Category(id: newId, name: row.category.trim(), colorHex: '#607D8B');
            categoryId = newId;
          }
        }

        final key = row.sku.trim().toLowerCase();
        final current = key.isEmpty ? null : productBySku[key];

        if (current == null) {
          final id = await _db.into(_db.products).insert(
                ProductsCompanion.insert(
                  name: row.name,
                  barcode: row.sku.isEmpty ? const Value.absent() : Value(row.sku),
                  categoryId: Value(categoryId),
                  unit: Value(row.unit),
                  reorderLevel: Value(row.reorderLevel),
                  costPrice: Value(row.costPrice),
                  salePrice: Value(row.salePrice),
                  stockQuantity: Value(row.stock),
                ),
              );
          if (key.isNotEmpty) {
            productBySku[key] = Product(
              id: id,
              name: row.name,
              barcode: row.sku,
              categoryId: categoryId,
              unit: row.unit,
              reorderLevel: row.reorderLevel,
              costPrice: row.costPrice,
              salePrice: row.salePrice,
              stockQuantity: row.stock,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }
          added++;
        } else {
          await (_db.update(_db.products)..where((p) => p.id.equals(current.id))).write(
            ProductsCompanion(
              name: Value(row.name),
              barcode: row.sku.isEmpty ? const Value.absent() : Value(row.sku),
              categoryId: Value(categoryId),
              unit: Value(row.unit),
              reorderLevel: Value(row.reorderLevel),
              costPrice: Value(row.costPrice),
              salePrice: Value(row.salePrice),
              stockQuantity: Value(row.stock),
              updatedAt: Value(DateTime.now()),
            ),
          );
          updated++;
        }
      }
    });

    return ProductImportSummary(
      added: added,
      updated: updated,
      skipped: skipped,
      skippedReasons: skippedReasons,
    );
  }

  List<ProductImportRow> _parseCsv(String raw) {
    final rows = const CsvToListConverter(eol: '\n').convert(raw);
    if (rows.isEmpty) return const [];
    final headers = rows.first.map((e) => '$e'.trim().toLowerCase()).toList();
    return _parseRows(
      rows.skip(1).map((r) => r.map((e) => '$e').toList()).toList(),
      headers,
    );
  }

  List<ProductImportRow> _parseXlsx(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return const [];
    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) return const [];

    final headers = sheet.rows.first.map((e) => e?.value?.toString().trim().toLowerCase() ?? '').toList();
    final rows = sheet.rows
        .skip(1)
        .map((r) => r.map((e) => e?.value?.toString() ?? '').toList())
        .toList();

    return _parseRows(rows, headers);
  }

  List<ProductImportRow> _parseRows(List<List<String>> rows, List<String> headers) {
    int idx(String name) => headers.indexOf(name);

    final iName = idx('name');
    final iSku = idx('sku');
    final iCategory = idx('category');
    final iCost = idx('costprice');
    final iSale = idx('saleprice');
    final iStock = idx('stock');
    final iUnit = idx('unit');
    final iReorder = idx('reorderlevel');

    String v(List<String> row, int i) => (i >= 0 && i < row.length) ? row[i].trim() : '';

    return rows.map((row) {
      final name = v(row, iName);
      final sku = v(row, iSku);
      final category = v(row, iCategory);
      final cost = double.tryParse(v(row, iCost));
      final sale = double.tryParse(v(row, iSale));
      final stock = int.tryParse(v(row, iStock));
      final unit = v(row, iUnit).isEmpty ? 'pcs' : v(row, iUnit);
      final reorder = int.tryParse(v(row, iReorder)) ?? 0;

      String? reason;
      if (name.isEmpty) {
        reason = 'Missing name';
      } else if (sale == null || sale <= 0) {
        reason = 'Invalid salePrice';
      } else if (cost == null || cost < 0) {
        reason = 'Invalid costPrice';
      } else if (stock == null || stock < 0) {
        reason = 'Invalid stock';
      }

      return ProductImportRow(
        name: name,
        sku: sku,
        category: category,
        costPrice: cost ?? 0,
        salePrice: sale ?? 0,
        stock: stock ?? 0,
        unit: unit,
        reorderLevel: reorder,
        skipReason: reason,
      );
    }).toList();
  }
}

