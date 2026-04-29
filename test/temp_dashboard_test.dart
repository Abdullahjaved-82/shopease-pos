import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:pos_system/app/app.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';
import 'package:pos_system/features/auth/application/auth_state.dart';
import 'package:pos_system/features/auth/domain/user_role.dart';

void main() {
  testWidgets('dashboard app smoke test', (tester) async {
	tester.view.physicalSize = const Size(1600, 1000);
	tester.view.devicePixelRatio = 1.0;
	addTearDown(tester.view.reset);

	await tester.pumpWidget(
	  ProviderScope(
		overrides: [authControllerProvider.overrideWith((ref) => MockAuth())],
		child: const ShopEaseApp(),
	  ),
	);

	// Avoid pumpAndSettle here because app-level timers/animations keep ticking.
	await tester.pump(const Duration(milliseconds: 250));
	expect(find.byType(ShopEaseApp), findsOneWidget);
  });
}

class MockAuth extends StateNotifier<AuthState> implements AuthController {
  MockAuth()
	  : super(
		  AuthState(
			isLoading: false,
			userId: 1,
			userName: 'Admin',
			role: UserRole.admin,
			errorMessage: null,
		  ),
		);

  @override
  Future<void> login({required UserRole role, required String pin}) async {}

  @override
  void logout() {}

  @override
  Future<void> resetDefaultPinsForDebug() async {}
}
