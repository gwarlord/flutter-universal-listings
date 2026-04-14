import 'package:intl/intl.dart';

class CurrencyFormatter {
  static const Map<String, String> _preferredSymbols = {
  'USD': 'US\$ ',
  'XCD': 'EC\$ ',
  'TTD': 'TT\$ ',
  'JMD': 'J\$ ',
  'BBD': 'BDS\$ ',
  'GYD': 'GY\$ ',
  };

  String formatAmount({
    required String currencyCode,
    required double amount,
  }) {
    final normalizedCode = currencyCode.trim().toUpperCase();
    final symbol = _preferredSymbols[normalizedCode] ?? '$normalizedCode ';

    final format = NumberFormat.currency(
      name: normalizedCode,
      symbol: symbol,
      decimalDigits: 2,
    );
    return format.format(amount);
  }
}
