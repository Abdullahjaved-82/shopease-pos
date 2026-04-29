class ShopSettings {
  const ShopSettings({
    required this.name,
    required this.adminName,
    required this.shopCity,
    required this.address,
    required this.phone,
    required this.taxRate,
    required this.receiptFooter,
    required this.currency,
    required this.logoPath,
    required this.pointsPerRupee,
    required this.rupeePerPoint,
    required this.minRedeemPoints,
    required this.expiryDays,
    required this.receiptTemplate,
    required this.balanceReminderTemplate,
    required this.accentColorHex,
    required this.defaultInvoiceTemplate,
    required this.defaultInvoiceLanguage,
    required this.autoBackupEnabled,
    required this.autoBackupFrequency,
    required this.autoExportEnabled,
    required this.autoExportFolder,
    required this.fbrEnabled,
    required this.syncEnabled,
    required this.syncIsMaster,
    required this.syncDeviceId,
    required this.syncDeviceName,
    required this.syncMasterHost,
    required this.syncLastSyncAt,
  });

  final String name;
  final String adminName;
  final String shopCity;
  final String address;
  final String phone;
  final double taxRate;
  final String receiptFooter;
  final String currency;
  final String? logoPath;
  final double pointsPerRupee;
  final double rupeePerPoint;
  final int minRedeemPoints;
  final int expiryDays;
  final String receiptTemplate;
  final String balanceReminderTemplate;
  final String accentColorHex;
  final String defaultInvoiceTemplate;
  final String defaultInvoiceLanguage;
  final bool autoBackupEnabled;
  final String autoBackupFrequency;
  final bool autoExportEnabled;
  final String? autoExportFolder;
  final bool fbrEnabled;
  final bool syncEnabled;
  final bool syncIsMaster;
  final String syncDeviceId;
  final String syncDeviceName;
  final String? syncMasterHost;
  final DateTime? syncLastSyncAt;

  factory ShopSettings.defaults() => const ShopSettings(
        name: 'ShopEase',
        adminName: 'Admin',
        shopCity: 'Lahore',
        address: '',
        phone: '',
        taxRate: 0,
        receiptFooter: 'Thank you for shopping with us!',
        currency: 'PKR',
        logoPath: null,
        pointsPerRupee: 0.1,
        rupeePerPoint: 0.5,
        minRedeemPoints: 100,
        expiryDays: 0,
        receiptTemplate: 'Hi {name}, thanks for shopping at {shop}! Receipt #{saleId} on {date}. Items:\n{items}\nTotal: PKR {total}. Balance: PKR {balance}.',
        balanceReminderTemplate: 'Dear {name}, your outstanding balance at {shop} is PKR {balance}. Please visit us. Thank you!',
        accentColorHex: '#1565C0',
        defaultInvoiceTemplate: 'modern',
        defaultInvoiceLanguage: 'en',
        autoBackupEnabled: false,
        autoBackupFrequency: 'daily',
        autoExportEnabled: false,
        autoExportFolder: null,
        fbrEnabled: false,
        syncEnabled: false,
        syncIsMaster: true,
        syncDeviceId: '',
        syncDeviceName: 'Register',
        syncMasterHost: null,
        syncLastSyncAt: null,
      );

  ShopSettings copyWith({
    String? name,
    String? adminName,
    String? shopCity,
    String? address,
    String? phone,
    double? taxRate,
    String? receiptFooter,
    String? currency,
    String? logoPath,
    double? pointsPerRupee,
    double? rupeePerPoint,
    int? minRedeemPoints,
    int? expiryDays,
    String? receiptTemplate,
    String? balanceReminderTemplate,
    String? accentColorHex,
    String? defaultInvoiceTemplate,
    String? defaultInvoiceLanguage,
    bool? autoBackupEnabled,
    String? autoBackupFrequency,
    bool? autoExportEnabled,
    String? autoExportFolder,
    bool? fbrEnabled,
    bool? syncEnabled,
    bool? syncIsMaster,
    String? syncDeviceId,
    String? syncDeviceName,
    String? syncMasterHost,
    DateTime? syncLastSyncAt,
  }) {
    return ShopSettings(
      name: name ?? this.name,
      adminName: adminName ?? this.adminName,
      shopCity: shopCity ?? this.shopCity,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      taxRate: taxRate ?? this.taxRate,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      currency: currency ?? this.currency,
      logoPath: logoPath ?? this.logoPath,
      pointsPerRupee: pointsPerRupee ?? this.pointsPerRupee,
      rupeePerPoint: rupeePerPoint ?? this.rupeePerPoint,
      minRedeemPoints: minRedeemPoints ?? this.minRedeemPoints,
      expiryDays: expiryDays ?? this.expiryDays,
      receiptTemplate: receiptTemplate ?? this.receiptTemplate,
      balanceReminderTemplate: balanceReminderTemplate ?? this.balanceReminderTemplate,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      defaultInvoiceTemplate: defaultInvoiceTemplate ?? this.defaultInvoiceTemplate,
      defaultInvoiceLanguage: defaultInvoiceLanguage ?? this.defaultInvoiceLanguage,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      autoBackupFrequency: autoBackupFrequency ?? this.autoBackupFrequency,
      autoExportEnabled: autoExportEnabled ?? this.autoExportEnabled,
      autoExportFolder: autoExportFolder ?? this.autoExportFolder,
      fbrEnabled: fbrEnabled ?? this.fbrEnabled,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      syncIsMaster: syncIsMaster ?? this.syncIsMaster,
      syncDeviceId: syncDeviceId ?? this.syncDeviceId,
      syncDeviceName: syncDeviceName ?? this.syncDeviceName,
      syncMasterHost: syncMasterHost ?? this.syncMasterHost,
      syncLastSyncAt: syncLastSyncAt ?? this.syncLastSyncAt,
    );
  }
}

