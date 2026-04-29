import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart' as repos;
import 'package:pos_system/core/repositories/users_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:pos_system/features/auth/application/auth_controller.dart';
import 'package:pos_system/features/auth/domain/user_role.dart';
import 'package:pos_system/features/invoices/application/invoice_pdf_service.dart';
import 'package:pos_system/features/settings/application/data_tools_providers.dart';
import 'package:pos_system/features/settings/application/app_prefs_notifier.dart';
import 'package:pos_system/features/settings/application/shop_settings_controller.dart';
import 'package:pos_system/features/settings/domain/shop_settings.dart';
import 'package:pos_system/core/security/crypto_utils.dart';

class ShopSettingsPage extends ConsumerStatefulWidget {
  const ShopSettingsPage({super.key});

  @override
  ConsumerState<ShopSettingsPage> createState() => _ShopSettingsPageState();
}

class _ShopSettingsPageState extends ConsumerState<ShopSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'PKR');
  final _pointsPerRupeeCtrl = TextEditingController();
  final _rupeePerPointCtrl = TextEditingController();
  final _minRedeemCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _receiptTemplateCtrl = TextEditingController();
  final _balanceTemplateCtrl = TextEditingController();
  final _autoExportFolderCtrl = TextEditingController();
  String _defaultInvoiceTemplate = 'modern';
  String _defaultInvoiceLanguage = 'en';
  bool _invoiceDefaultsInitialized = false;
  bool _autoBackupEnabled = false;
  String _autoBackupFrequency = 'daily';
  bool _autoExportEnabled = false;
  bool _automationInitialized = false;
  String? _logoPath;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _taxCtrl.dispose();
    _footerCtrl.dispose();
    _currencyCtrl.dispose();
    _pointsPerRupeeCtrl.dispose();
    _rupeePerPointCtrl.dispose();
    _minRedeemCtrl.dispose();
    _expiryCtrl.dispose();
    _receiptTemplateCtrl.dispose();
    _balanceTemplateCtrl.dispose();
    _autoExportFolderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth.role != UserRole.admin) {
      return const Scaffold(body: Center(child: Text('Admin only')));
    }

    final settingsAsync = ref.watch(shopSettingsControllerProvider);
    final prefsAsync = ref.watch(appPrefsNotifierProvider);
    final usersRepo = ref.watch(repos.usersRepositoryProvider);
    final exportService = ref.watch(exportServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Admin')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (settings) {
          _nameCtrl.text = settings.name;
          _addressCtrl.text = settings.address;
          _phoneCtrl.text = settings.phone;
          _taxCtrl.text = settings.taxRate.toStringAsFixed(2);
          _footerCtrl.text = settings.receiptFooter;
          _currencyCtrl.text = settings.currency;
          _pointsPerRupeeCtrl.text = settings.pointsPerRupee.toString();
          _rupeePerPointCtrl.text = settings.rupeePerPoint.toString();
          _minRedeemCtrl.text = settings.minRedeemPoints.toString();
          _expiryCtrl.text = settings.expiryDays.toString();
          _receiptTemplateCtrl.text = settings.receiptTemplate;
          _balanceTemplateCtrl.text = settings.balanceReminderTemplate;
          if (!_invoiceDefaultsInitialized) {
            _defaultInvoiceTemplate = settings.defaultInvoiceTemplate;
            _defaultInvoiceLanguage = settings.defaultInvoiceLanguage;
            _invoiceDefaultsInitialized = true;
          }
          if (!_automationInitialized) {
            _autoBackupEnabled = settings.autoBackupEnabled;
            _autoBackupFrequency = settings.autoBackupFrequency;
            _autoExportEnabled = settings.autoExportEnabled;
            _autoExportFolderCtrl.text = settings.autoExportFolder ?? '';
            _automationInitialized = true;
          }
          _logoPath ??= settings.logoPath;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shop Info', style: Theme.of(context).textTheme.titleMedium),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(labelText: 'Shop name'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
                          TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                          TextFormField(controller: _currencyCtrl, decoration: const InputDecoration(labelText: 'Currency')),
                          TextFormField(
                            controller: _taxCtrl,
                            decoration: const InputDecoration(labelText: 'Tax rate (%)'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              final parsed = double.tryParse(v ?? '');
                              if (parsed == null || parsed < 0) return 'Enter a valid rate';
                              return null;
                            },
                          ),
                          TextFormField(controller: _footerCtrl, decoration: const InputDecoration(labelText: 'Receipt footer'), maxLines: 2),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.image),
                                label: const Text('Pick logo'),
                                onPressed: () async {
                                  final picked = await FilePicker.platform.pickFiles(type: FileType.image);
                                  if (picked != null && picked.files.single.path != null) {
                                    setState(() => _logoPath = picked.files.single.path);
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_logoPath ?? 'No logo selected', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: () => _save(settings),
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _AppearanceCard(prefsAsync: prefsAsync, onTheme: (m) => ref.read(appPrefsNotifierProvider.notifier).setThemeMode(m), onLocale: (l) => ref.read(appPrefsNotifierProvider.notifier).setLocale(l), onFont: (s) => ref.read(appPrefsNotifierProvider.notifier).setFontScale(s)),
                const SizedBox(height: 16),
                _UserManagement(usersRepo: usersRepo),
                const SizedBox(height: 16),
                _BackupRestore(db: ref.read(databaseProvider)),
                const SizedBox(height: 16),
                _DangerZone(db: ref.read(databaseProvider), usersRepo: usersRepo),
                const SizedBox(height: 16),
                _LoyaltySettingsCard(
                  pointsPerRupeeCtrl: _pointsPerRupeeCtrl,
                  rupeePerPointCtrl: _rupeePerPointCtrl,
                  minRedeemCtrl: _minRedeemCtrl,
                  expiryCtrl: _expiryCtrl,
                ),
                const SizedBox(height: 16),
                _NotificationSettingsCard(
                  receiptTemplateCtrl: _receiptTemplateCtrl,
                  balanceTemplateCtrl: _balanceTemplateCtrl,
                ),
                const SizedBox(height: 16),
                _InvoiceSettingsCard(
                  defaultTemplate: _defaultInvoiceTemplate,
                  defaultLanguage: _defaultInvoiceLanguage,
                  onTemplateChanged: (v) => setState(() => _defaultInvoiceTemplate = v),
                  onLanguageChanged: (v) => setState(() => _defaultInvoiceLanguage = v),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Data Backup & Export', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => context.go('/settings/backup'),
                              icon: const Icon(Icons.cloud_sync_outlined),
                              label: const Text('Google Drive Backup'),
                            ),
                            FilledButton.icon(
                              onPressed: () => context.go('/settings/import-products'),
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Import Products CSV/Excel'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final range = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  initialDateRange: DateTimeRange(
                                    start: DateTime.now().subtract(const Duration(days: 30)),
                                    end: DateTime.now(),
                                  ),
                                );
                                if (range == null) return;
                                final path = await exportService.exportAll(
                                  start: DateTime(range.start.year, range.start.month, range.start.day),
                                  end: DateTime(range.end.year, range.end.month, range.end.day).add(const Duration(days: 1)),
                                );
                                await exportService.shareFile(path);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export saved: $path')));
                              },
                              icon: const Icon(Icons.table_view_outlined),
                              label: const Text('Export CSV/Excel'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          value: _autoBackupEnabled,
                          onChanged: (v) => setState(() => _autoBackupEnabled = v),
                          title: const Text('Auto cloud backup'),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _autoBackupFrequency,
                          decoration: const InputDecoration(labelText: 'Auto-backup frequency'),
                          items: const [
                            DropdownMenuItem(value: 'daily', child: Text('Daily')),
                            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          ],
                          onChanged: (v) => setState(() => _autoBackupFrequency = v ?? 'daily'),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          value: _autoExportEnabled,
                          onChanged: (v) => setState(() => _autoExportEnabled = v),
                          title: const Text('Scheduled auto-export (EOD)'),
                        ),
                        TextFormField(
                          controller: _autoExportFolderCtrl,
                          decoration: const InputDecoration(labelText: 'Auto-export folder path'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _AboutDevelopersCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save(ShopSettings current) async {
    if (!_formKey.currentState!.validate()) return;
    final updated = current.copyWith(
      name: _nameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      taxRate: double.tryParse(_taxCtrl.text) ?? 0,
      receiptFooter: _footerCtrl.text.trim(),
      currency: _currencyCtrl.text.trim().isEmpty ? 'PKR' : _currencyCtrl.text.trim(),
      logoPath: _logoPath,
      pointsPerRupee: double.tryParse(_pointsPerRupeeCtrl.text) ?? current.pointsPerRupee,
      rupeePerPoint: double.tryParse(_rupeePerPointCtrl.text) ?? current.rupeePerPoint,
      minRedeemPoints: int.tryParse(_minRedeemCtrl.text) ?? current.minRedeemPoints,
      expiryDays: int.tryParse(_expiryCtrl.text) ?? current.expiryDays,
      receiptTemplate: _receiptTemplateCtrl.text.isEmpty ? current.receiptTemplate : _receiptTemplateCtrl.text,
      balanceReminderTemplate: _balanceTemplateCtrl.text.isEmpty ? current.balanceReminderTemplate : _balanceTemplateCtrl.text,
      defaultInvoiceTemplate: _defaultInvoiceTemplate,
      defaultInvoiceLanguage: _defaultInvoiceLanguage,
      autoBackupEnabled: _autoBackupEnabled,
      autoBackupFrequency: _autoBackupFrequency,
      autoExportEnabled: _autoExportEnabled,
      autoExportFolder: _autoExportFolderCtrl.text.trim().isEmpty ? null : _autoExportFolderCtrl.text.trim(),
    );
    await ref.read(shopSettingsControllerProvider.notifier).save(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({required this.prefsAsync, required this.onTheme, required this.onLocale, required this.onFont});
  final AsyncValue<AppPrefs> prefsAsync;
  final ValueChanged<ThemeMode> onTheme;
  final ValueChanged<String?> onLocale;
  final ValueChanged<double> onFont;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: prefsAsync.when(
          data: (prefs) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
              DropdownButton<ThemeMode>(
                value: prefs.themeMode,
                onChanged: (m) => m != null ? onTheme(m) : null,
                items: ThemeMode.values.map((m) => DropdownMenuItem(value: m, child: Text(m.name))).toList(),
              ),
              DropdownButton<String?>(
                value: prefs.localeCode,
                hint: const Text('Language'),
                onChanged: onLocale,
                items: const [
                  DropdownMenuItem(value: null, child: Text('System')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ur', child: Text('Urdu')),
                ],
              ),
              Slider(
                value: prefs.fontScale,
                onChanged: onFont,
                min: 0.9,
                max: 1.3,
                divisions: 4,
                label: 'Font ${prefs.fontScale.toStringAsFixed(1)}x',
              ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Prefs error: $e'),
        ),
      ),
    );
  }
}

class _UserManagement extends StatefulWidget {
  const _UserManagement({required this.usersRepo});
  final UsersRepository usersRepo;

  @override
  State<_UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<_UserManagement> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User Management', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            StreamBuilder<List<User>>(
              stream: widget.usersRepo.watchAll(),
              builder: (context, snapshot) {
                final users = snapshot.data ?? [];
                return Column(
                  children: [
                    ...users.map((u) => ListTile(
                          title: Text(u.name),
                          subtitle: Text(u.role),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.lock_reset),
                                tooltip: 'Reset PIN',
                                onPressed: () => _showUserDialog(user: u),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () async {
                                  await widget.usersRepo.deleteById(u.id);
                                  if (mounted) setState(() {});
                                },
                              ),
                            ],
                          ),
                        )),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add User'),
                        onPressed: () => _showUserDialog(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUserDialog({User? user}) async {
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final pinCtrl = TextEditingController();
    String role = user?.role ?? 'cashier';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user == null ? 'Add User' : 'Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            DropdownButton<String>(
              value: role,
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
              ],
              onChanged: (v) => setState(() => role = v ?? 'cashier'),
            ),
            TextField(controller: pinCtrl, decoration: const InputDecoration(labelText: 'PIN (leave blank to keep)'), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (result == true) {
      final salt = CryptoUtils.generateSalt();
      final pinHash = pinCtrl.text.isEmpty && user != null ? user.pinHash : CryptoUtils.hashPin(pinCtrl.text, salt);
      if (user == null) {
        await widget.usersRepo.insert(
          UsersCompanion.insert(name: nameCtrl.text.trim(), role: Value(role), salt: salt, pinHash: pinHash),
        );
      } else {
        await widget.usersRepo.updateUser(
          UsersCompanion(
            id: Value(user.id),
            name: Value(nameCtrl.text.trim()),
            role: Value(role),
            salt: Value(pinCtrl.text.isEmpty ? user.salt : salt),
            pinHash: Value(pinHash),
          ),
        );
      }
      if (mounted) setState(() {});
    }
  }
}

class _BackupRestore extends StatefulWidget {
  const _BackupRestore({required this.db});
  final AppDatabase db;
  @override
  State<_BackupRestore> createState() => _BackupRestoreState();
}

class _BackupRestoreState extends State<_BackupRestore> {
  String? _lastBackup;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backup & Restore', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Export DB'),
                  onPressed: _exportDb,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Import DB'),
                  onPressed: _importDb,
                ),
                const Spacer(),
                if (_lastBackup != null) Text('Last backup: $_lastBackup'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _dbPath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return '${docsDir.path}/shopease_pos.sqlite';
  }

  Future<void> _exportDb() async {
    final source = await _dbPath();
    final downloads = await getDownloadsDirectory();
    if (downloads == null) return;
    final target = '${downloads.path}/shopease_pos_backup.sqlite';
    await File(source).copy(target);
    setState(() => _lastBackup = DateTime.now().toIso8601String());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $target')));
    }
  }

  Future<void> _importDb() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    if (picked == null || picked.files.single.path == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace database?'),
        content: const Text('This will overwrite current data.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Replace'))],
      ),
    );
    if (confirm != true) return;
    await widget.db.close();
    final target = await _dbPath();
    await File(picked.files.single.path!).copy(target);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database replaced. Restart app.')));
    }
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.db, required this.usersRepo});
  final AppDatabase db;
  final UsersRepository usersRepo;

  Future<void> _clearSales(BuildContext context) async {
    final confirm = await _pinDialog(context, usersRepo);
    if (!confirm) return;
    await db.transaction(() async {
      await db.delete(db.saleItems).go();
      await db.delete(db.sales).go();
      await db.delete(db.stockMovements).go();
      await db.delete(db.customerPayments).go();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sales data cleared')));
  }

  Future<void> _factoryReset(BuildContext context) async {
    final confirm = await _pinDialog(context, usersRepo);
    if (!confirm) return;
    final docsDir = await getApplicationDocumentsDirectory();
    final dbFile = File('${docsDir.path}/shopease_pos.sqlite');
    await db.close();
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Factory reset. Restart app.')));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Danger Zone', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => _clearSales(context),
              child: const Text('Clear all sales data'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => _factoryReset(context),
              child: const Text('Factory Reset'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _pinDialog(BuildContext context, UsersRepository repo) async {
    final pinCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin PIN required'),
        content: TextField(controller: pinCtrl, decoration: const InputDecoration(labelText: 'PIN'), obscureText: true),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm'))],
      ),
    );
    if (result == true) {
      final admin = await repo.getByRole('admin');
      if (admin == null) return false;
      final hash = CryptoUtils.hashPin(pinCtrl.text, admin.salt);
      return hash == admin.pinHash;
    }
    return false;
  }
}

class _LoyaltySettingsCard extends StatelessWidget {
  const _LoyaltySettingsCard({
    required this.pointsPerRupeeCtrl,
    required this.rupeePerPointCtrl,
    required this.minRedeemCtrl,
    required this.expiryCtrl,
  });

  final TextEditingController pointsPerRupeeCtrl;
  final TextEditingController rupeePerPointCtrl;
  final TextEditingController minRedeemCtrl;
  final TextEditingController expiryCtrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loyalty Settings', style: Theme.of(context).textTheme.titleMedium),
            TextFormField(
              controller: pointsPerRupeeCtrl,
              decoration: const InputDecoration(labelText: 'Points per rupee (e.g. 0.1 = 1 point per 10 PKR)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextFormField(
              controller: rupeePerPointCtrl,
              decoration: const InputDecoration(labelText: 'Rupee value per point (e.g. 0.5)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextFormField(
              controller: minRedeemCtrl,
              decoration: const InputDecoration(labelText: 'Minimum redeemable points'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: expiryCtrl,
              decoration: const InputDecoration(labelText: 'Expiry days (0 = never)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSettingsCard extends StatelessWidget {
  const _NotificationSettingsCard({required this.receiptTemplateCtrl, required this.balanceTemplateCtrl});

  final TextEditingController receiptTemplateCtrl;
  final TextEditingController balanceTemplateCtrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: receiptTemplateCtrl,
              decoration: const InputDecoration(
                labelText: 'WhatsApp receipt template',
                helperText: 'Placeholders: {shop}, {name}, {saleId}, {date}, {items}, {total}, {balance}',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: balanceTemplateCtrl,
              decoration: const InputDecoration(
                labelText: 'Balance reminder template',
                helperText: 'Placeholders: {shop}, {name}, {balance}',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceSettingsCard extends StatelessWidget {
  const _InvoiceSettingsCard({
    required this.defaultTemplate,
    required this.defaultLanguage,
    required this.onTemplateChanged,
    required this.onLanguageChanged,
  });

  final String defaultTemplate;
  final String defaultLanguage;
  final ValueChanged<String> onTemplateChanged;
  final ValueChanged<String> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: defaultTemplate,
              decoration: const InputDecoration(labelText: 'Default template'),
              items: InvoiceTemplate.values
                  .map((t) => DropdownMenuItem(value: t.dbValue, child: Text(t.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onTemplateChanged(v);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: defaultLanguage,
              decoration: const InputDecoration(labelText: 'Default PDF language'),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ur', child: Text('Urdu')),
              ],
              onChanged: (v) {
                if (v != null) onLanguageChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutDevelopersCard extends StatelessWidget {
  const _AboutDevelopersCard();

  @override
  Widget build(BuildContext context) {
    const cloudoraBlue = Color(0xFF1E88E5);
    const techGrey = Color(0xFF7A7A7A);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About Developers', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(text: 'Product: ShopEase\n'),
                  TextSpan(text: 'Built by '),
                  TextSpan(text: 'Cloudora', style: TextStyle(color: cloudoraBlue, fontWeight: FontWeight.w700)),
                  TextSpan(text: ' '),
                  TextSpan(text: 'Tech', style: TextStyle(color: techGrey, fontWeight: FontWeight.w700)),
                  TextSpan(text: '\nSoftware Solutions\n\n'),
                  TextSpan(text: 'Developers: Cloudora Engineering Team\n'),
                  TextSpan(text: 'Support: support@cloudora.tech\n'),
                  TextSpan(text: 'Website: www.cloudora.tech'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

