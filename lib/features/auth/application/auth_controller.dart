import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/security/crypto_utils.dart';
import 'package:pos_system/features/auth/application/auth_state.dart';
import 'package:pos_system/features/auth/domain/user_role.dart';
import 'package:pos_system/core/repositories/users_repository.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._usersRepository) : super(AuthState.initial());

  final UsersRepository _usersRepository;

  Future<void> login({required UserRole role, required String pin}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final user = await _usersRepository.getUserByRole(role.asKey);
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'User not found',
        );
        return;
      }

      final hashedPin = CryptoUtils.hashPin(pin, user.salt);
      final isMatch = hashedPin == user.pinHash;

      if (isMatch) {
        state = state.copyWith(
          isLoading: false,
          userId: user.id,
          userName: user.name,
          role: role,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid PIN',
        );
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'System error: $error',
      );
    }
  }

  void logout() {
    state = AuthState.initial();
  }

  Future<void> resetDefaultPinsForDebug() async {
    if (!kDebugMode) {
      return;
    }
    await _usersRepository.resetDefaultPins();
  }
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return UsersRepository(db);
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repo = ref.watch(usersRepositoryProvider);
  return AuthController(repo);
});
