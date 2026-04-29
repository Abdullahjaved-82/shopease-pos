import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/router/app_router.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/features/invoices/application/invoice_overdue_notification_service.dart';
import 'package:pos_system/features/invoices/application/recurring_invoice_service.dart';
import 'package:pos_system/features/settings/application/app_prefs_notifier.dart';
import 'package:pos_system/features/settings/application/data_tools_providers.dart';
import 'package:pos_system/features/settings/application/shop_settings_controller.dart';
import 'package:pos_system/features/shared/presentation/widgets/branding_splash_overlay.dart';
import 'package:pos_system/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class ShopEaseApp extends ConsumerStatefulWidget {
  const ShopEaseApp({super.key});

  @override
  ConsumerState<ShopEaseApp> createState() => _ShopEaseAppState();
}

class _ShopEaseAppState extends ConsumerState<ShopEaseApp> with WidgetsBindingObserver {
  Timer? _splashTimer;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(invoiceOverdueNotificationServiceProvider).initialize());
    Future.microtask(() => ref.read(recurringInvoiceServiceProvider).runOnStartup());
    Future.microtask(
      () => ref.read(automationServiceProvider).initialize(
            getSettings: () => readCurrentShopSettings(ref),
          ),
    );
    _splashTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      ref.read(automationServiceProvider).onAppClose(
            getSettings: () => readCurrentShopSettings(ref),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final activeTheme = ref.watch(appThemeProvider);
    final appPrefs = ref.watch(appPrefsNotifierProvider);
    final shopSettings = ref.watch(shopSettingsControllerProvider).valueOrNull;
    final themeMode = appPrefs.value?.themeMode ?? ThemeMode.system;

    return MaterialApp.router(
      title: 'ShopEase',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      // Uses appThemeProvider for concrete colors while still allowing ThemeMode switching.
      builder: (context, child) => Theme(
        data: activeTheme,
        child: Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (_showSplash)
              BrandingSplashOverlay(
                logoPath: shopSettings?.logoPath,
                shopName: shopSettings?.name.trim().isNotEmpty == true
                    ? shopSettings!.name
                    : 'ShopEase',
              ),
          ],
        ),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ur'),
      ],
    );
  }
}
