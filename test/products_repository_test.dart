import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/repositories/products_repository.dart';

void main() {
  late AppDatabase db;
  late ProductsRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = ProductsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('insert and fetch product', () async {
    final id = await repository.insert(
      ProductsCompanion.insert(
        name: 'Item A',
        salePrice: const Value(10.0),
        costPrice: const Value(5.0),
      ),
    );

    final fetched = await repository.getById(id);
    expect(fetched, isNotNull);
    expect(fetched!.name, 'Item A');
  });

  test('watchAll emits updates', () async {
    final productsStream = repository.watchAll();
    final emissions = <List<Product>>[];
    final sub = productsStream.listen(emissions.add);

    await repository.insert(
      ProductsCompanion.insert(
        name: 'Item B',
        salePrice: const Value(12.5),
        costPrice: const Value(6.0),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(emissions.isNotEmpty, isTrue);
    expect(emissions.last.first.name, 'Item B');
  });
}
