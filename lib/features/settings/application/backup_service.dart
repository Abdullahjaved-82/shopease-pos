import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_system/features/settings/domain/shop_settings.dart';

class CloudBackupFile {
  const CloudBackupFile({
    required this.id,
    required this.name,
    required this.size,
    required this.modifiedAt,
  });

  final String id;
  final String name;
  final int size;
  final DateTime? modifiedAt;
}

class BackupService {
  BackupService()
      : _googleSignIn = GoogleSignIn(
          scopes: [drive.DriveApi.driveFileScope],
        );

  final GoogleSignIn _googleSignIn;

  Future<GoogleSignInAccount?> signInWithGoogle() => _googleSignIn.signIn();

  Future<String> createBackupZip({required ShopSettings settings}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();
    final dbPath = p.join(docsDir.path, 'shopease_pos.sqlite');

    final backupDir = Directory(p.join(tempDir.path, 'shopease_backup_tmp'));
    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }
    await backupDir.create(recursive: true);

    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      await dbFile.copy(p.join(backupDir.path, 'shopease_pos.sqlite'));
    }

    if (settings.logoPath != null && settings.logoPath!.isNotEmpty) {
      final logo = File(settings.logoPath!);
      if (await logo.exists()) {
        await logo.copy(p.join(backupDir.path, p.basename(settings.logoPath!)));
      }
    }

    final settingsJson = jsonEncode({
      'name': settings.name,
      'address': settings.address,
      'phone': settings.phone,
      'taxRate': settings.taxRate,
      'receiptFooter': settings.receiptFooter,
      'currency': settings.currency,
      'logoPath': settings.logoPath,
      'accentColorHex': settings.accentColorHex,
      'defaultInvoiceTemplate': settings.defaultInvoiceTemplate,
      'defaultInvoiceLanguage': settings.defaultInvoiceLanguage,
      'autoBackupEnabled': settings.autoBackupEnabled,
      'autoBackupFrequency': settings.autoBackupFrequency,
      'autoExportEnabled': settings.autoExportEnabled,
      'autoExportFolder': settings.autoExportFolder,
    });
    await File(p.join(backupDir.path, 'settings.json')).writeAsString(settingsJson);

    final zipPath = p.join(tempDir.path, 'shopease_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    encoder.addDirectory(backupDir);
    encoder.close();

    await backupDir.delete(recursive: true);
    return zipPath;
  }

  Future<String?> uploadBackup(String filePath, {bool promptIfNeeded = true}) async {
    final client = await _getAuthenticatedClient(promptIfNeeded: promptIfNeeded);
    if (client == null) return null;

    final api = drive.DriveApi(client);
    final file = File(filePath);
    if (!await file.exists()) return null;

    final media = drive.Media(file.openRead(), await file.length());
    final driveFile = drive.File()
      ..name = p.basename(filePath)
      ..mimeType = 'application/zip';

    final uploaded = await api.files.create(driveFile, uploadMedia: media);
    return uploaded.id;
  }

  Future<List<CloudBackupFile>> listBackups() async {
    final client = await _getAuthenticatedClient(promptIfNeeded: true);
    if (client == null) return const [];

    final api = drive.DriveApi(client);
    final files = await api.files.list(
      q: "mimeType='application/zip' and trashed=false and name contains 'shopease_backup_'",
      orderBy: 'modifiedTime desc',
      $fields: 'files(id,name,size,modifiedTime)',
    );

    return (files.files ?? const [])
        .where((f) => f.id != null)
        .map(
          (f) => CloudBackupFile(
            id: f.id!,
            name: f.name ?? 'backup.zip',
            size: int.tryParse(f.size ?? '0') ?? 0,
            modifiedAt: f.modifiedTime,
          ),
        )
        .toList();
  }

  Future<String?> downloadBackup(String fileId) async {
    final client = await _getAuthenticatedClient(promptIfNeeded: true);
    if (client == null) return null;

    final api = drive.DriveApi(client);
    final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia);
    if (media is! drive.Media) return null;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    final tempDir = await getTemporaryDirectory();
    final path = p.join(tempDir.path, 'downloaded_backup_$fileId.zip');
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<void> restoreBackup(String zipPath) async {
    final input = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(input);
    input.close();

    final docsDir = await getApplicationDocumentsDirectory();
    final prefs = await SharedPreferences.getInstance();

    for (final file in archive) {
      final filename = file.name;
      if (filename.endsWith('.sqlite')) {
        final out = File(p.join(docsDir.path, 'shopease_pos.sqlite'));
        await out.writeAsBytes(file.content as List<int>, flush: true);
      } else if (filename.endsWith('settings.json')) {
        final content = utf8.decode(file.content as List<int>);
        final map = jsonDecode(content) as Map<String, dynamic>;
        await _restoreSettingsPrefs(prefs, map);
      } else if (filename.contains('.png') || filename.contains('.jpg') || filename.contains('.jpeg')) {
        final out = File(p.join(docsDir.path, p.basename(filename)));
        await out.writeAsBytes(file.content as List<int>, flush: true);
      }
    }
  }

  Future<void> _restoreSettingsPrefs(SharedPreferences prefs, Map<String, dynamic> map) async {
    Future<void> setString(String key, dynamic value) async {
      if (value == null) return;
      await prefs.setString(key, '$value');
    }

    Future<void> setBool(String key, dynamic value) async {
      if (value == null) return;
      await prefs.setBool(key, value == true);
    }

    Future<void> setDouble(String key, dynamic value) async {
      if (value == null) return;
      final parsed = value is num ? value.toDouble() : double.tryParse('$value');
      if (parsed != null) await prefs.setDouble(key, parsed);
    }

    await setString('shop_name', map['name']);
    await setString('shop_address', map['address']);
    await setString('shop_phone', map['phone']);
    await setDouble('shop_tax_rate', map['taxRate']);
    await setString('shop_receipt_footer', map['receiptFooter']);
    await setString('shop_currency', map['currency']);
    await setString('shop_logo_path', map['logoPath']);
    await setString('shop_accent_color_hex', map['accentColorHex']);
    await setString('shop_default_invoice_template', map['defaultInvoiceTemplate']);
    await setString('shop_default_invoice_language', map['defaultInvoiceLanguage']);
    await setBool('shop_auto_backup_enabled', map['autoBackupEnabled']);
    await setString('shop_auto_backup_frequency', map['autoBackupFrequency']);
    await setBool('shop_auto_export_enabled', map['autoExportEnabled']);
    await setString('shop_auto_export_folder', map['autoExportFolder']);
  }

  Future<dynamic> _getAuthenticatedClient({required bool promptIfNeeded}) async {
    if (_googleSignIn.currentUser == null) {
      if (!promptIfNeeded) return null;
      final account = await signInWithGoogle();
      if (account == null) return null;
    }
    return _googleSignIn.authenticatedClient();
  }
}

