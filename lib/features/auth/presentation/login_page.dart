import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_system/features/settings/application/shop_settings_controller.dart';
import 'package:pos_system/features/shared/presentation/widgets/shopease_brand_logo.dart';
import 'package:pos_system/features/auth/domain/user_role.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _pinController = TextEditingController();
  UserRole _selectedRole = UserRole.admin;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(authControllerProvider.notifier);
    await auth.login(role: _selectedRole, pin: _pinController.text.trim());
    final state = ref.read(authControllerProvider);
    if (state.isAuthenticated && mounted) {
      context.go('/sales');
    }
  }

  Future<void> _resetPinsForDebug() async {
    await ref.read(authControllerProvider.notifier).resetDefaultPinsForDebug();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PINs reset: Admin 1234, Cashier 0000')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final settings = ref.watch(shopSettingsControllerProvider).valueOrNull;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        ShopEaseBrandLogo(logoPath: settings?.logoPath, size: 84),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome to ShopEase',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Login to continue',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    initialValue: _selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Select role',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: UserRole.admin,
                        child: Text('Admin'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.cashier,
                        child: Text('Cashier'),
                      ),
                    ],
                    onChanged: (role) {
                      if (role != null) {
                        setState(() => _selectedRole = role);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      helperText: 'Use 4-digit PIN',
                    ),
                    obscureText: true,
                    maxLength: 4,
                  ),
                  if (authState.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      authState.errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: authState.isLoading ? null : _submit,
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continue'),
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: authState.isLoading ? null : _resetPinsForDebug,
                        child: const Text('Reset default PINs (debug)'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
