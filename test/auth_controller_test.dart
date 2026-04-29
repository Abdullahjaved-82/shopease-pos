import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/router/app_router.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';
import 'package:pos_system/features/auth/application/auth_state.dart';
import 'package:pos_system/features/auth/domain/user_role.dart';
import 'package:pos_system/features/auth/infrastructure/users_repository.dart';

void main() {
  late AppDatabase db;
  late UsersRepository repository;
  late AuthController controller;

  setUp(() async {
    db = AppDatabase.memory();
    repository = UsersRepository(db);
    await repository.seedDefaultUsers();
    controller = AuthController(repository);
  });

  tearDown(() async {
    await db.close();
  });

  test('rejects wrong PIN', () async {
    await controller.login(role: UserRole.admin, pin: '9999');

    expect(controller.state.isAuthenticated, isFalse);
    expect(controller.state.errorMessage, 'Invalid PIN');
  });

  test('authenticates admin with correct PIN', () async {
    await controller.login(role: UserRole.admin, pin: '1234');

    expect(controller.state.isAuthenticated, isTrue);
    expect(controller.state.userName, 'Admin');
    expect(controller.state.role, UserRole.admin);
  });

  test('cashier redirected from restricted routes', () {
    final cashierState = const AuthState(
      userId: 2,
      userName: 'Cashier',
      role: UserRole.cashier,
    );

    expect(resolveRedirect(cashierState, '/reports'), '/sales');
    expect(resolveRedirect(cashierState, '/customers'), isNull);
  });
}

