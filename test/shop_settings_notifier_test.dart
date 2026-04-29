import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/features/settings/application/shop_settings_controller.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ShopSettingsNotifier save/load cycle', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(shopSettingsControllerProvider.notifier);
    final initial = await container.read(shopSettingsControllerProvider.future);
    expect(initial.name, 'ShopEase POS');

    final updated = initial.copyWith(name: 'My Shop', taxRate: 5.5, currency: 'USD', logoPath: '/tmp/logo.png');
    await notifier.save(updated);
    final reloaded = await container.read(shopSettingsControllerProvider.future);
    expect(reloaded.name, 'My Shop');
    expect(reloaded.taxRate, 5.5);
    expect(reloaded.currency, 'USD');
    expect(reloaded.logoPath, '/tmp/logo.png');
  });
}

