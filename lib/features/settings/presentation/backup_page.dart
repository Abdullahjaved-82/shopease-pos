import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_system/features/settings/application/backup_service.dart';
import 'package:pos_system/features/settings/application/data_tools_providers.dart';
import 'package:pos_system/features/settings/application/shop_settings_controller.dart';
import 'package:pos_system/features/settings/domain/shop_settings.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final backupService = ref.watch(backupServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Backup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _backupNow(backupService),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Backup Now'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () async => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<CloudBackupFile>>(
                future: backupService.listBackups(),
                builder: (context, snapshot) {
                  final files = snapshot.data ?? const [];
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (files.isEmpty) {
                    return const Center(child: Text('No cloud backups found.'));
                  }
                  return ListView.separated(
                    itemCount: files.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final f = files[index];
                      return ListTile(
                        title: Text(f.name),
                        subtitle: Text(
                          '${f.modifiedAt == null ? '-' : DateFormat('dd MMM yyyy, hh:mm a').format(f.modifiedAt!)} • ${(f.size / 1024).toStringAsFixed(1)} KB',
                        ),
                        trailing: FilledButton(
                          onPressed: _busy ? null : () => _restoreBackup(backupService, f),
                          child: const Text('Restore'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backupNow(BackupService service) async {
    setState(() => _busy = true);
    try {
      final settings = ref.read(shopSettingsControllerProvider).valueOrNull ?? ShopSettings.defaults();
      final zipPath = await service.createBackupZip(settings: settings);
      final id = await service.uploadBackup(zipPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(id == null ? 'Backup failed' : 'Backup uploaded successfully')),
      );
      setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup(BackupService service, CloudBackupFile file) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restore backup?'),
            content: const Text('This will replace local data. Continue?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      final zipPath = await service.downloadBackup(file.id);
      if (zipPath == null) throw Exception('Failed to download backup');
      await service.restoreBackup(zipPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore complete. Restart app for full reload.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

