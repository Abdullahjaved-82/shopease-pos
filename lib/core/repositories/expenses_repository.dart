import 'package:pos_system/core/database/app_database.dart';

class ExpensesRepository {
  ExpensesRepository(this._db);

  final AppDatabase _db;

  Stream<List<Expense>> watchAll() => _db.select(_db.expenses).watch();

  Future<List<Expense>> getAll() => _db.select(_db.expenses).get();

  Future<Expense?> getById(int id) => (_db.select(_db.expenses)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<int> insert(ExpensesCompanion companion) => _db.into(_db.expenses).insert(companion);

  Future<bool> updateExpense(ExpensesCompanion companion) async {
    return _db.update(_db.expenses).replace(companion);
  }

  Future<int> deleteById(int id) => (_db.delete(_db.expenses)..where((e) => e.id.equals(id))).go();
}

