class InvoiceL10n {
  const InvoiceL10n._(this.locale);

  final String locale;

  static InvoiceL10n of(String locale) => InvoiceL10n._(locale == 'ur' ? 'ur' : 'en');

  static const Map<String, Map<String, String>> _labels = {
    'en': {
      'invoice': 'Invoice',
      'quotation': 'Quotation',
      'proforma': 'Pro Forma Invoice',
      'invoiceNo': 'Invoice No',
      'date': 'Date',
      'dueDate': 'Due Date',
      'status': 'Status',
      'billTo': 'Bill To',
      'description': 'Description',
      'qty': 'Qty',
      'unitPrice': 'Unit Price',
      'lineTotal': 'Line Total',
      'subtotal': 'Subtotal',
      'discount': 'Discount',
      'tax': 'Tax',
      'total': 'Total',
      'notes': 'Notes',
      'terms': 'Payment Terms',
      'paymentInstructions': 'Payment Instructions',
      'thanks': 'Thank you for your business!',
      'pkrEquivalent': 'PKR Equivalent',
    },
    'ur': {
      'invoice': 'انوائس',
      'quotation': 'کوٹیشن',
      'proforma': 'پرو فارما انوائس',
      'invoiceNo': 'انوائس نمبر',
      'date': 'تاریخ',
      'dueDate': 'آخری تاریخ',
      'status': 'حالت',
      'billTo': 'بل برائے',
      'description': 'تفصیل',
      'qty': 'تعداد',
      'unitPrice': 'فی قیمت',
      'lineTotal': 'کل رقم',
      'subtotal': 'ذیلی کل',
      'discount': 'ڈسکاؤنٹ',
      'tax': 'ٹیکس',
      'total': 'کل',
      'notes': 'نوٹس',
      'terms': 'ادائیگی کی شرائط',
      'paymentInstructions': 'ادائیگی کی ہدایات',
      'thanks': 'آپ کے اعتماد کا شکریہ!',
      'pkrEquivalent': 'پاکستانی روپے میں',
    },
  };

  String t(String key) => _labels[locale]?[key] ?? _labels['en']![key] ?? key;

  bool get isUrdu => locale == 'ur';
}


