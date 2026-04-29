import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/repositories/sales_repository.dart';
import 'package:pos_system/core/repositories/users_repository.dart';

void main() {
  late AppDatabase db;
  late SalesRepository salesRepository;
  late UsersRepository usersRepository;
  late int userId;

  setUp(() async {
    db = AppDatabase.memory();
    salesRepository = SalesRepository(db);
    usersRepository = UsersRepository(db);
    await usersRepository.seedDefaultsIfEmpty();
    final admin = await usersRepository.getByRole('admin');
    userId = admin!.id;
  });

  tearDown(() async {
    await db.close();
  });

  test('insert and fetch sale', () async {
    final saleId = await salesRepository.insert(
      SalesCompanion.insert(
        totalAmount: 100.0,
        discount: const Value(0.0),
        paymentMethod: const Value('cash'),
        paidAmount: const Value(100.0),
        changeAmount: const Value(0.0),
        userId: userId,
      ),
    );

    final sale = await salesRepository.getById(saleId);
    expect(sale, isNotNull);
    expect(sale!.totalAmount, 100.0);
  });

  test('watchAll emits after insert', () async {
    final emissions = <List<Sale>>[];
    final sub = salesRepository.watchAll().listen(emissions.add);

    await salesRepository.insert(
      SalesCompanion.insert(
        totalAmount: 50.0,
        discount: const Value(5.0),
        paymentMethod: const Value('cash'),
        paidAmount: const Value(50.0),
        changeAmount: const Value(0.0),
        userId: userId,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(emissions.isNotEmpty, isTrue);
    expect(emissions.last.first.totalAmount, 50.0);
  });
}
