import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_system/features/settings/application/backup_service.dart';
import 'package:pos_system/features/settings/application/export_service.dart';
import 'package:pos_system/features/settings/domain/shop_settings.dart';

class AutomationService {
  AutomationService({
    required BackupService backupService,
    required ExportService exportService,
  })  : _backupService = backupService,
        _exportService = exportService;

  final BackupService _backupService;
  final ExportService _exportService;
  Timer? _timer;

  Future<void> initialize({required Future<ShopSettings> Function() getSettings}) async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) async {
      final settings = await getSettings();
      await _runAutoExportIfDue(settings);
    });
  }

  Future<void> onAppClose({required Future<ShopSettings> Function() getSettings}) async {
    final settings = await getSettings();
    if (!settings.autoBackupEnabled) return;

    final zipPath = await _backupService.createBackupZip(settings: settings);
    await _backupService.uploadBackup(zipPath, promptIfNeeded: false);
  }

  Future<void> _runAutoExportIfDue(ShopSettings settings) async {
    if (!settings.autoExportEnabled) return;
    final folder = settings.autoExportFolder;
    if (folder == null || folder.isEmpty) return;

    final now = DateTime.now();
    if (now.hour < 23) return;

    final prefs = await SharedPreferences.getInstance();
    final dayKey = '${now.year}-${now.month}-${now.day}';
    final last = prefs.getString('auto_export_last_day');
    if (last == dayKey) return;

    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final exportedPath = await _exportService.exportAll(start: start, end: end);

    final targetPath = p.join(folder, p.basename(exportedPath));
    await File(exportedPath).copy(targetPath);
    await prefs.setString('auto_export_last_day', dayKey);
  }

  void dispose() {
    _timer?.cancel();
  }
}


