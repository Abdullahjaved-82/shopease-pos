import 'package:drift/drift.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/repositories/repository_base.dart';
import 'package:pos_system/core/sync/sync_log_repository.dart';

class CustomerWithBalance {
  CustomerWithBalance({required this.customer, required this.balance});
  final Customer customer;
  final double balance;
}

class CustomersRepository extends RepositoryBase {
  CustomersRepository(this._db)
      : super(
          SyncLogRepository(_db),
          'local',
        );

  final AppDatabase _db;

  Stream<List<Customer>> watchAll() => _db.select(_db.customers).watch();

  Future<List<Customer>> getAll() => _db.select(_db.customers).get();

  Future<Customer?> getById(int id) => (_db.select(_db.customers)..where((c) => c.id.equals(id))).getSingleOrNull();

  Stream<List<CustomerWithBalance>> watchWithBalance({String? search, bool onlyWithBalance = false}) {
    final query = _db.customSelect(
      '''
      SELECT c.*, 
        COALESCE((SELECT SUM(s.total_amount) FROM sales s WHERE s.customer_id = c.id AND s.payment_method = 'credit'), 0)
        - COALESCE((SELECT SUM(p.amount) FROM customer_payments p WHERE p.customer_id = c.id), 0) AS balance
      FROM customers c
      ''',
      readsFrom: {_db.customers, _db.sales, _db.customerPayments},
    );
    return query.watch().map((rows) {
      final mapped = rows.map((row) {
        final customer = _db.customers.map(row.data);
        final balance = row.data['balance'] as double? ?? 0;
        return CustomerWithBalance(customer: customer, balance: balance);
      }).where((cb) {
        final matchesSearch = search == null || search.isEmpty || cb.customer.name.toLowerCase().contains(search.toLowerCase());
        final matchesBalance = !onlyWithBalance || cb.balance > 0.01;
        return matchesSearch && matchesBalance;
      }).toList();
      mapped.sort((a, b) => b.balance.compareTo(a.balance));
      return mapped;
    });
  }

  Future<int> insert(CustomersCompanion companion) async {
    final id = await _db.into(_db.customers).insert(companion);
    final row = await getById(id);
    if (row != null) {
      await logInsert(tableName: 'customers', recordId: id, data: _toSyncData(row));
    }
    return id;
  }

  Future<bool> updateCustomer(CustomersCompanion companion) async {
    final ok = await _db.update(_db.customers).replace(companion);
    final id = companion.id.value;
    if (ok) {
      final row = await getById(id);
      if (row != null) {
        await logUpdate(tableName: 'customers', recordId: id, data: _toSyncData(row));
      }
    }
    return ok;
  }

  Future<int> deleteById(int id) async {
    final count = await (_db.delete(_db.customers)..where((c) => c.id.equals(id))).go();
    if (count > 0) {
      await logDelete(tableName: 'customers', recordId: id);
    }
    return count;
  }

  Future<double> getBalance(int customerId) async {
    final credit = await (_db.customSelect(
      'SELECT SUM(total_amount) AS total FROM sales WHERE customer_id = ? AND payment_method = ?;',
      variables: [Variable<int>(customerId), const Variable<String>('credit')],
      readsFrom: {_db.sales},
    ).map((row) => row.data['total'] as double? ?? 0).getSingle());

    final payments = await (_db.customSelect(
      'SELECT SUM(amount) AS total FROM customer_payments WHERE customer_id = ?;',
      variables: [Variable<int>(customerId)],
      readsFrom: {_db.customerPayments},
    ).map((row) => row.data['total'] as double? ?? 0).getSingle());

    return credit - payments;
  }

  Future<int> recordPayment({required int customerId, required double amount, String? note, required int userId}) async {
    final id = await _db.into(_db.customerPayments).insert(
          CustomerPaymentsCompanion.insert(
            customerId: customerId,
            amount: amount,
            note: Value(note),
            userId: userId,
          ),
        );
    final current = await getById(customerId);
    final next = (current?.currentBalance ?? 0) - amount;
    await (_db.update(_db.customers)..where((c) => c.id.equals(customerId))).write(
      CustomersCompanion(currentBalance: Value(next)),
    );
    final row = await getById(customerId);
    if (row != null) {
      await logUpdate(tableName: 'customers', recordId: customerId, data: _toSyncData(row));
    }
    return id;
  }

  Stream<List<CustomerPayment>> getPaymentHistory(int customerId) {
    return (_db.select(_db.customerPayments)
          ..where((p) => p.customerId.equals(customerId))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  Future<void> applyCharge({required int customerId, required double amount}) async {
    final current = await getById(customerId);
    final next = (current?.currentBalance ?? 0) + amount;
    await (_db.update(_db.customers)..where((c) => c.id.equals(customerId))).write(
      CustomersCompanion(currentBalance: Value(next)),
    );
    final row = await getById(customerId);
    if (row != null) {
      await logUpdate(tableName: 'customers', recordId: customerId, data: _toSyncData(row));
    }
  }

  Map<String, dynamic> _toSyncData(Customer row) => {
        'id': row.id,
        'name': row.name,
        'phone': row.phone,
        'cnic': row.cnic,
        'email': row.email,
        'address': row.address,
        'creditLimit': row.creditLimit,
        'openingBalance': row.openingBalance,
        'currentBalance': row.currentBalance,
        'createdAt': row.createdAt.toUtc().toIso8601String(),
        '_updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
}

