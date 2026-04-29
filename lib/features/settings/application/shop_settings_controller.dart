import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_system/features/settings/domain/shop_settings.dart';

part 'shop_settings_controller.g.dart';

const _kName = 'shop_name';
const _kAdminName = 'shop_admin_name';
const _kShopCity = 'shop_city';
const _kAddress = 'shop_address';
const _kPhone = 'shop_phone';
const _kTaxRate = 'shop_tax_rate';
const _kReceiptFooter = 'shop_receipt_footer';
const _kCurrency = 'shop_currency';
const _kLogoPath = 'shop_logo_path';
const _kPointsPerRupee = 'shop_points_per_rupee';
const _kRupeePerPoint = 'shop_rupee_per_point';
const _kMinRedeemPoints = 'shop_min_redeem_points';
const _kExpiryDays = 'shop_loyalty_expiry_days';
const _kReceiptTemplate = 'shop_receipt_template';
const _kBalanceReminderTemplate = 'shop_balance_template';
const _kAccentColorHex = 'shop_accent_color_hex';
const _kDefaultInvoiceTemplate = 'shop_default_invoice_template';
const _kDefaultInvoiceLanguage = 'shop_default_invoice_language';
const _kAutoBackupEnabled = 'shop_auto_backup_enabled';
const _kAutoBackupFrequency = 'shop_auto_backup_frequency';
const _kAutoExportEnabled = 'shop_auto_export_enabled';
const _kAutoExportFolder = 'shop_auto_export_folder';
const _kFbrEnabled = 'shop_fbr_enabled';
const _kSyncEnabled = 'shop_sync_enabled';
const _kSyncIsMaster = 'shop_sync_is_master';
const _kSyncDeviceId = 'shop_sync_device_id';
const _kSyncDeviceName = 'shop_sync_device_name';
const _kSyncMasterHost = 'shop_sync_master_host';
const _kSyncLastSyncAt = 'shop_sync_last_sync_at';

@riverpod
class ShopSettingsController extends _$ShopSettingsController {
  late SharedPreferences _prefs;

  @override
  Future<ShopSettings> build() async {
    _prefs = await SharedPreferences.getInstance();
    return _readFromPrefs();
  }

  Future<void> save(ShopSettings settings) async {
    state = AsyncData(settings);
    await _prefs.setString(_kName, settings.name);
    await _prefs.setString(_kAdminName, settings.adminName);
    await _prefs.setString(_kShopCity, settings.shopCity);
    await _prefs.setString(_kAddress, settings.address);
    await _prefs.setString(_kPhone, settings.phone);
    await _prefs.setDouble(_kTaxRate, settings.taxRate);
    await _prefs.setString(_kReceiptFooter, settings.receiptFooter);
    await _prefs.setString(_kCurrency, settings.currency);
    await _prefs.setDouble(_kPointsPerRupee, settings.pointsPerRupee);
    await _prefs.setDouble(_kRupeePerPoint, settings.rupeePerPoint);
    await _prefs.setInt(_kMinRedeemPoints, settings.minRedeemPoints);
    await _prefs.setInt(_kExpiryDays, settings.expiryDays);
    await _prefs.setString(_kReceiptTemplate, settings.receiptTemplate);
    await _prefs.setString(_kBalanceReminderTemplate, settings.balanceReminderTemplate);
    await _prefs.setString(_kAccentColorHex, settings.accentColorHex);
    await _prefs.setString(_kDefaultInvoiceTemplate, settings.defaultInvoiceTemplate);
    await _prefs.setString(_kDefaultInvoiceLanguage, settings.defaultInvoiceLanguage);
    await _prefs.setBool(_kAutoBackupEnabled, settings.autoBackupEnabled);
    await _prefs.setString(_kAutoBackupFrequency, settings.autoBackupFrequency);
    await _prefs.setBool(_kAutoExportEnabled, settings.autoExportEnabled);
    await _prefs.setBool(_kFbrEnabled, settings.fbrEnabled);
    await _prefs.setBool(_kSyncEnabled, settings.syncEnabled);
    await _prefs.setBool(_kSyncIsMaster, settings.syncIsMaster);
    await _prefs.setString(_kSyncDeviceId, settings.syncDeviceId);
    await _prefs.setString(_kSyncDeviceName, settings.syncDeviceName);
    if (settings.syncMasterHost == null || settings.syncMasterHost!.isEmpty) {
      await _prefs.remove(_kSyncMasterHost);
    } else {
      await _prefs.setString(_kSyncMasterHost, settings.syncMasterHost!);
    }
    if (settings.syncLastSyncAt == null) {
      await _prefs.remove(_kSyncLastSyncAt);
    } else {
      await _prefs.setString(_kSyncLastSyncAt, settings.syncLastSyncAt!.toUtc().toIso8601String());
    }
    if (settings.autoExportFolder == null || settings.autoExportFolder!.isEmpty) {
      await _prefs.remove(_kAutoExportFolder);
    } else {
      await _prefs.setString(_kAutoExportFolder, settings.autoExportFolder!);
    }
    if (settings.logoPath != null) {
      await _prefs.setString(_kLogoPath, settings.logoPath!);
    } else {
      await _prefs.remove(_kLogoPath);
    }
  }

  ShopSettings _readFromPrefs() {
    final defaults = ShopSettings.defaults();
    final syncDeviceId = _prefs.getString(_kSyncDeviceId) ?? DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    return ShopSettings(
      name: _prefs.getString(_kName) ?? defaults.name,
      adminName: _prefs.getString(_kAdminName) ?? defaults.adminName,
      shopCity: _prefs.getString(_kShopCity) ?? defaults.shopCity,
      address: _prefs.getString(_kAddress) ?? '',
      phone: _prefs.getString(_kPhone) ?? '',
      taxRate: _prefs.getDouble(_kTaxRate) ?? 0,
      receiptFooter: _prefs.getString(_kReceiptFooter) ?? defaults.receiptFooter,
      currency: _prefs.getString(_kCurrency) ?? defaults.currency,
      logoPath: _prefs.getString(_kLogoPath),
      pointsPerRupee: _prefs.getDouble(_kPointsPerRupee) ?? defaults.pointsPerRupee,
      rupeePerPoint: _prefs.getDouble(_kRupeePerPoint) ?? defaults.rupeePerPoint,
      minRedeemPoints: _prefs.getInt(_kMinRedeemPoints) ?? defaults.minRedeemPoints,
      expiryDays: _prefs.getInt(_kExpiryDays) ?? defaults.expiryDays,
      receiptTemplate: _prefs.getString(_kReceiptTemplate) ?? defaults.receiptTemplate,
      balanceReminderTemplate: _prefs.getString(_kBalanceReminderTemplate) ?? defaults.balanceReminderTemplate,
      accentColorHex: _prefs.getString(_kAccentColorHex) ?? defaults.accentColorHex,
      defaultInvoiceTemplate: _prefs.getString(_kDefaultInvoiceTemplate) ?? defaults.defaultInvoiceTemplate,
      defaultInvoiceLanguage: _prefs.getString(_kDefaultInvoiceLanguage) ?? defaults.defaultInvoiceLanguage,
      autoBackupEnabled: _prefs.getBool(_kAutoBackupEnabled) ?? defaults.autoBackupEnabled,
      autoBackupFrequency: _prefs.getString(_kAutoBackupFrequency) ?? defaults.autoBackupFrequency,
      autoExportEnabled: _prefs.getBool(_kAutoExportEnabled) ?? defaults.autoExportEnabled,
      autoExportFolder: _prefs.getString(_kAutoExportFolder),
      fbrEnabled: _prefs.getBool(_kFbrEnabled) ?? defaults.fbrEnabled,
      syncEnabled: _prefs.getBool(_kSyncEnabled) ?? defaults.syncEnabled,
      syncIsMaster: _prefs.getBool(_kSyncIsMaster) ?? defaults.syncIsMaster,
      syncDeviceId: syncDeviceId,
      syncDeviceName: _prefs.getString(_kSyncDeviceName) ?? defaults.syncDeviceName,
      syncMasterHost: _prefs.getString(_kSyncMasterHost),
      syncLastSyncAt: _prefs.getString(_kSyncLastSyncAt) == null
          ? null
          : DateTime.tryParse(_prefs.getString(_kSyncLastSyncAt)!)?.toUtc(),
    );
  }
}

final shopSettingsProvider = shopSettingsControllerProvider;

