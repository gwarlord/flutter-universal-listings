enum SupportedCurrency {
  usd,
  xcd,
  ttd,
  jmd,
  bbd,
  gyd,
}

class CurrencyDisplayPreference {
  static const String original = 'original';
  static const String local = 'local';
}

extension SupportedCurrencyCode on SupportedCurrency {
  String get code {
    switch (this) {
      case SupportedCurrency.usd:
        return 'USD';
      case SupportedCurrency.xcd:
        return 'XCD';
      case SupportedCurrency.ttd:
        return 'TTD';
      case SupportedCurrency.jmd:
        return 'JMD';
      case SupportedCurrency.bbd:
        return 'BBD';
      case SupportedCurrency.gyd:
        return 'GYD';
    }
  }

  String get displayLabel {
    switch (this) {
      case SupportedCurrency.usd:
        return 'USD';
      case SupportedCurrency.xcd:
        return 'XCD';
      case SupportedCurrency.ttd:
        return 'TTD';
      case SupportedCurrency.jmd:
        return 'JMD';
      case SupportedCurrency.bbd:
        return 'BBD';
      case SupportedCurrency.gyd:
        return 'GYD';
    }
  }
}

SupportedCurrency? supportedCurrencyFromCode(String code) {
  final normalized = code.trim().toUpperCase();
  for (final currency in SupportedCurrency.values) {
    if (currency.code == normalized) {
      return currency;
    }
  }
  return null;
}

String normalizePreferenceValue(String? value) {
  final normalized = (value ?? '').trim().toUpperCase();

  if (normalized.isEmpty || normalized == CurrencyDisplayPreference.local.toUpperCase()) {
    return CurrencyDisplayPreference.local;
  }

  if (normalized == CurrencyDisplayPreference.original.toUpperCase()) {
    return CurrencyDisplayPreference.original;
  }

  if (supportedCurrencyFromCode(normalized) != null) {
    return normalized;
  }

  return CurrencyDisplayPreference.local;
}
