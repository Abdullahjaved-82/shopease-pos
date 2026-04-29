class CurrencyInfo {
  const CurrencyInfo({required this.code, required this.symbol, required this.name});

  final String code;
  final String symbol;
  final String name;
}

class CurrencyService {
  static const supported = <CurrencyInfo>[
    CurrencyInfo(code: 'PKR', symbol: 'Rs', name: 'Pakistani Rupee'),
    CurrencyInfo(code: 'USD', symbol: r'$', name: 'US Dollar'),
    CurrencyInfo(code: 'AED', symbol: 'AED', name: 'UAE Dirham'),
    CurrencyInfo(code: 'SAR', symbol: 'SAR', name: 'Saudi Riyal'),
    CurrencyInfo(code: 'GBP', symbol: 'GBP', name: 'British Pound'),
  ];

  static CurrencyInfo byCode(String code) {
    return supported.firstWhere(
      (c) => c.code == code,
      orElse: () => supported.first,
    );
  }

  static String format(double value, String code) {
    final c = byCode(code);
    return '${c.symbol} ${value.toStringAsFixed(2)}';
  }
}
