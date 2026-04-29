import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pos_system/core/repositories/users_repository.dart';

part 'app_database.g.dart';

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get barcode => text().nullable()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  IntColumn get reorderLevel => integer().withDefault(const Constant(0))();
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  RealColumn get salePrice => real().withDefault(const Constant(0.0))();
  IntColumn get stockQuantity => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Shifts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();
  RealColumn get openingCash => real()();
  RealColumn get closingCash => real().nullable()();
  RealColumn get expectedCash => real().nullable()();
  RealColumn get difference => real().nullable()();
  TextColumn get note => text().nullable()();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get colorHex => text().withDefault(const Constant('#607D8B'))();
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  RealColumn get totalAmount => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  RealColumn get changeAmount => real().withDefault(const Constant(0.0))();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  RealColumn get unitPrice => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get lineTotal => real().withDefault(const Constant(0.0))();
}

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get type => text()();
  IntColumn get qty => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get userId => integer().references(Users, #id)();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get cnic => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  RealColumn get creditLimit => real().withDefault(const Constant(0.0))();
  RealColumn get openingBalance => real().withDefault(const Constant(0.0))();
  RealColumn get currentBalance => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class CustomerPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  RealColumn get amount => real()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get userId => integer().references(Users, #id)();
}

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PurchaseOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PurchaseOrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(PurchaseOrders, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get qty => integer()();
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
}

class LoyaltyTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get points => integer()();
  TextColumn get type => text()();
  IntColumn get saleId => integer().nullable().references(Sales, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get category => text().nullable()();
  RealColumn get amount => real()();
  DateTimeColumn get incurredOn => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
}

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get role => text().withDefault(const Constant('cashier'))();
  TextColumn get salt => text()();
  TextColumn get pinHash => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class CashMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shiftId => integer().references(Shifts, #id)();
  TextColumn get type => text()();
  RealColumn get amount => real()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text().unique()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get linkedSaleId => integer().nullable().references(Sales, #id)();
  TextColumn get docType => text().withDefault(const Constant('invoice'))();
  TextColumn get billToName => text().nullable()();
  TextColumn get billToAddress => text().nullable()();
  TextColumn get billToPhone => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get template => text().withDefault(const Constant('modern'))();
  TextColumn get invoiceLanguage => text().withDefault(const Constant('en'))();
  TextColumn get currencyCode => text().withDefault(const Constant('PKR'))();
  RealColumn get exchangeRateToPkr => real().withDefault(const Constant(1.0))();
  DateTimeColumn get sentAt => dateTime().nullable()();
  DateTimeColumn get issueDate => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  TextColumn get terms => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class InvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(Invoices, #id)();
  TextColumn get description => text()();
  RealColumn get qty => real().withDefault(const Constant(1.0))();
  RealColumn get unitPrice => real().withDefault(const Constant(0.0))();
  RealColumn get lineTotal => real().withDefault(const Constant(0.0))();
}

class InvoicePayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(Invoices, #id)();
  RealColumn get amount => real()();
  TextColumn get method => text()();
  DateTimeColumn get paidAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
}

class RecurringInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get templateInvoiceId => integer().references(Invoices, #id)();
  TextColumn get frequency => text()();
  DateTimeColumn get nextRunDate => dateTime()();
  DateTimeColumn get lastRunDate => dateTime().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().withDefault(const Constant('0'))();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Products,
    Categories,
    Sales,
    SaleItems,
    Customers,
    Expenses,
    Users,
    StockMovements,
    CustomerPayments,
    Suppliers,
    PurchaseOrders,
    PurchaseOrderItems,
    LoyaltyTransactions,
    Shifts,
    CashMovements,
    Invoices,
    InvoiceItems,
    InvoicePayments,
    RecurringInvoices,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  factory AppDatabase.memory() => AppDatabase(executor: NativeDatabase.memory());

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
          await _seedDefaults();
        },
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(categories, categories.colorHex);
          }
          if (from < 3) {
            await migrator.createTable(stockMovements);
          }
          if (from < 4) {
            await migrator.addColumn(customers, customers.cnic);
            await migrator.addColumn(customers, customers.creditLimit);
            await migrator.createTable(customerPayments);
          }
          if (from < 5) {
            await migrator.createTable(suppliers);
            await migrator.createTable(purchaseOrders);
            await migrator.createTable(purchaseOrderItems);
          }
          if (from < 6) {
            await migrator.createTable(shifts);
            await migrator.createTable(cashMovements);
          }
          if (from < 7) {
            await migrator.createTable(loyaltyTransactions);
          }
          if (from < 8) {
            try { await migrator.createTable(invoices); } catch(_) {}
            try { await migrator.createTable(invoiceItems); } catch(_) {}
          }
          if (from < 9) {
            try { await migrator.addColumn(invoices, invoices.linkedSaleId); } catch(_) {}
            try { await migrator.addColumn(invoices, invoices.sentAt); } catch(_) {}
            try { await migrator.createTable(invoicePayments); } catch(_) {}
          }
          if (from < 10) {
            try { await migrator.addColumn(invoices, invoices.template); } catch(_) {}
            try { await migrator.addColumn(invoices, invoices.invoiceLanguage); } catch(_) {}
            try { await migrator.addColumn(invoices, invoices.currencyCode); } catch(_) {}
            try { await migrator.addColumn(invoices, invoices.exchangeRateToPkr); } catch(_) {}
          }
          if (from < 11) {
            try { await migrator.addColumn(invoices, invoices.docType); } catch(_) {}
            try { await migrator.addColumn(invoices, invoices.expiryDate); } catch(_) {}
            try { await migrator.createTable(recurringInvoices); } catch(_) {}
            try { await migrator.createTable(appSettings); } catch(_) {}
          }
          if (from < 12) {
             try { await migrator.addColumn(users, users.isActive); } catch(_) {}
             try { await migrator.addColumn(users, users.updatedAt); } catch(_) {}
             try { await migrator.addColumn(customers, customers.email); } catch(_) {}
          }
        },
      );

  Future<void> _seedDefaults() async {
    final repository = UsersRepository(this);
    await repository.seedDefaultsIfEmpty();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(docsDir.path, 'shopease_pos.sqlite'));
    return NativeDatabase.createInBackground(dbFile);
  });
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
