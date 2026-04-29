enum DocumentType {
  invoice,
  quotation,
  proforma;

  String get dbValue => name;

  static DocumentType fromDb(String value) {
    return DocumentType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => DocumentType.invoice,
    );
  }

  String get prefix => switch (this) {
        DocumentType.invoice => 'INV',
        DocumentType.quotation => 'QUO',
        DocumentType.proforma => 'PRO',
      };

  String get title => switch (this) {
        DocumentType.invoice => 'Invoice',
        DocumentType.quotation => 'Quotation',
        DocumentType.proforma => 'Pro Forma Invoice',
      };
}

enum RecurringFrequency {
  weekly,
  monthly,
  quarterly;

  String get dbValue => name;

  static RecurringFrequency fromDb(String value) {
    return RecurringFrequency.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => RecurringFrequency.monthly,
    );
  }
}

