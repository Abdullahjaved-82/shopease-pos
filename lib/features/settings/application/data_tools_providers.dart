import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/sync/sync_log_repository.dart';
import 'package:pos_system/core/sync/sync_service.dart';
import 'package:pos_system/features/settings/application/automation_service.dart';
import 'package:pos_system/features/settings/application/backup_service.dart';
import 'package:pos_system/features/settings/application/export_service.dart';
import 'package:pos_system/features/settings/application/import_service.dart';
import 'package:pos_system/features/settings/application/shop_settings_controller.dart';
import 'package:pos_system/features/settings/domain/shop_settings.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

final exportServiceProvider = Provider<ExportService>((ref) {
  final db = ref.watch(databaseProvider);
  return ExportService(db);
});

final importServiceProvider = Provider<ImportService>((ref) {
  final db = ref.watch(databaseProvider);
  return ImportService(db);
});

final automationServiceProvider = Provider<AutomationService>((ref) {
  final service = AutomationService(
    backupService: ref.watch(backupServiceProvider),
    exportService: ref.watch(exportServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final syncLogRepositoryProvider = Provider<SyncLogRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncLogRepository(db);
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final syncLog = ref.watch(syncLogRepositoryProvider);
  final service = SyncService(db: db, syncLogRepository: syncLog);
  ref.onDispose(service.dispose);
  return service;
});

Future<ShopSettings> readCurrentShopSettings(WidgetRef ref) async {
  final value = ref.read(shopSettingsControllerProvider);
  if (value.hasValue && value.valueOrNull != null) {
    return value.valueOrNull!;
  }
  return await ref.read(shopSettingsControllerProvider.future);
}

