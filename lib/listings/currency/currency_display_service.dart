import 'dart:ui';

import 'currency_formatter.dart';
import 'exchange_rate_service.dart';
import 'supported_currency.dart';

class CurrencyDisplayResult {
  final String originalFormatted;
  final String? approximateFormatted;
  final bool isApproximate;

  const CurrencyDisplayResult({
    required this.originalFormatted,
    required this.approximateFormatted,
    required this.isApproximate,
  });
}

class CurrencyDisplayService {
  CurrencyDisplayService({
    ExchangeRateService? exchangeRateService,
    CurrencyFormatter? formatter,
  })  : _exchangeRateService = exchangeRateService ?? ExchangeRateService.instance,
        _formatter = formatter ?? CurrencyFormatter();

  final ExchangeRateService _exchangeRateService;
  final CurrencyFormatter _formatter;

  Future<CurrencyDisplayResult> buildDisplayResult({
    required String rawAmount,
    required String originalCurrencyCode,
    required String? preferenceValue,
  }) async {
    final originalCode = originalCurrencyCode.trim().toUpperCase();
    final amount = _parseAmount(rawAmount);

    final originalFormatted = amount != null
        ? _formatter.formatAmount(currencyCode: originalCode, amount: amount)
        : '$originalCode ${rawAmount.trim()}';

    final targetCode = _resolveTargetCurrencyCode(
      preferenceValue: preferenceValue,
      originalCurrencyCode: originalCode,
    );

    if (amount == null || targetCode == null || targetCode == originalCode) {
      return CurrencyDisplayResult(
        originalFormatted: originalFormatted,
        approximateFormatted: null,
        isApproximate: false,
      );
    }

    await _exchangeRateService.refreshRatesIfStale();
    final rates = await _exchangeRateService.getRateSet();
    if (rates == null) {
      return CurrencyDisplayResult(
        originalFormatted: originalFormatted,
        approximateFormatted: null,
        isApproximate: false,
      );
    }

    final converted = convertAmount(
      amount: amount,
      fromCurrencyCode: originalCode,
      toCurrencyCode: targetCode,
      rateSet: rates,
    );

    if (converted == null) {
      return CurrencyDisplayResult(
        originalFormatted: originalFormatted,
        approximateFormatted: null,
        isApproximate: false,
      );
    }

    return CurrencyDisplayResult(
      originalFormatted: originalFormatted,
      approximateFormatted: '≈ ${_formatter.formatAmount(currencyCode: targetCode, amount: converted)}',
      isApproximate: true,
    );
  }

  double? convertAmount({
    required double amount,
    required String fromCurrencyCode,
    required String toCurrencyCode,
    required ExchangeRateSet rateSet,
  }) {
    final from = fromCurrencyCode.trim().toUpperCase();
    final to = toCurrencyCode.trim().toUpperCase();
    final base = rateSet.baseCurrency.trim().toUpperCase();

    if (!amount.isFinite || amount < 0) return null;
    if (from == to) return amount;

    final fromRate = from == base ? 1.0 : rateSet.rates[from];
    final toRate = to == base ? 1.0 : rateSet.rates[to];

    if (fromRate == null || toRate == null || fromRate <= 0 || toRate <= 0) {
      return null;
    }

    final baseAmount = amount / fromRate;
    final converted = baseAmount * toRate;
    if (!converted.isFinite || converted < 0) {
      return null;
    }
    return converted;
  }

  String? _resolveTargetCurrencyCode({
    required String? preferenceValue,
    required String originalCurrencyCode,
  }) {
    final normalizedPreference = normalizePreferenceValue(preferenceValue);

    if (normalizedPreference == CurrencyDisplayPreference.original) {
      return null;
    }

    if (normalizedPreference == CurrencyDisplayPreference.local) {
      final localCode = _resolveLocalCurrencyCode();
      if (localCode == null || localCode == originalCurrencyCode) {
        return null;
      }
      return localCode;
    }

    if (normalizedPreference == originalCurrencyCode) {
      return null;
    }

    return supportedCurrencyFromCode(normalizedPreference)?.code;
  }

  String? _resolveLocalCurrencyCode() {
    final country = PlatformDispatcher.instance.locale.countryCode?.toUpperCase() ?? '';
    const mapping = <String, String>{
      // USD
      'US': 'USD',
      'AS': 'USD',
      'BQ': 'USD',
      'EC': 'USD',
      'FM': 'USD',
      'GU': 'USD',
      'IO': 'USD',
      'MH': 'USD',
      'MP': 'USD',
      'PR': 'USD',
      'PW': 'USD',
      'SV': 'USD',
      'TC': 'USD',
      'TL': 'USD',
      'UM': 'USD',
      'VG': 'USD',
      'VI': 'USD',

      // XCD
      'AG': 'XCD',
      'AI': 'XCD',
      'DM': 'XCD',
      'GD': 'XCD',
      'KN': 'XCD',
      'LC': 'XCD',
      'MS': 'XCD',
      'VC': 'XCD',

      // TTD
      'TT': 'TTD',

      // JMD
      'JM': 'JMD',

      // BBD
      'BB': 'BBD',

      // GYD
      'GY': 'GYD',
    };

    final mapped = mapping[country];
    if (mapped == null) {
      return null;
    }

    return supportedCurrencyFromCode(mapped)?.code;
  }

  double? _parseAmount(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    var normalized = trimmed.replaceAll(RegExp(r'[^0-9,.-]'), '');

    if (normalized.contains(',') && normalized.contains('.')) {
      normalized = normalized.replaceAll(',', '');
    } else if (normalized.contains(',') && !normalized.contains('.')) {
      normalized = normalized.replaceAll(',', '.');
    }

    return double.tryParse(normalized);
  }
}
