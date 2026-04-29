import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pos_system/features/auth/domain/user_role.dart';

part 'auth_state.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const AuthState._();

  const factory AuthState({
    int? userId,
    String? userName,
    UserRole? role,
    @Default(false) bool isLoading,
    String? errorMessage,
  }) = _AuthState;

  factory AuthState.initial() => const AuthState();

  bool get isAuthenticated => userId != null && role != null;
}
