import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'supported_currency.dart';

class ExchangeRateSet {
  final String baseCurrency;
  final Map<String, double> rates;
  final DateTime fetchedAt;

  const ExchangeRateSet({
    required this.baseCurrency,
    required this.rates,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'baseCurrency': baseCurrency,
      'fetchedAt': fetchedAt.toIso8601String(),
      'rates': rates,
    };
  }

  factory ExchangeRateSet.fromJson(Map<String, dynamic> json) {
    final rawRates = (json['rates'] as Map?) ?? const {};
    final rates = <String, double>{};

    for (final entry in rawRates.entries) {
      final code = entry.key.toString().toUpperCase();
      final value = _toDouble(entry.value);
      if (value != null && value > 0) {
        rates[code] = value;
      }
    }

    return ExchangeRateSet(
      baseCurrency: (json['baseCurrency']?.toString() ?? 'USD').toUpperCase(),
      fetchedAt: DateTime.tryParse(json['fetchedAt']?.toString() ?? '') ?? DateTime.now(),
      rates: rates,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class ExchangeRateService {
  ExchangeRateService._();

  static final ExchangeRateService instance = ExchangeRateService._();

  static const String _cacheKey = 'caribtap.exchange_rate_set.v1';
  static const Duration _maxAge = Duration(days: 1);
  static const String _baseCurrency = 'USD';

  ExchangeRateSet? _cachedRateSet;
  Future<ExchangeRateSet?>? _refreshInFlight;

  Future<ExchangeRateSet?> getRateSet() async {
    if (_cachedRateSet != null) {
      return _cachedRateSet;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final set = ExchangeRateSet.fromJson(decoded);
      _cachedRateSet = set;
      return set;
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshRatesIfStale() async {
    final existing = await getRateSet();
    final isStale = existing == null || DateTime.now().difference(existing.fetchedAt) > _maxAge;
    if (!isStale) {
      return;
    }

    await refreshRates();
  }

  Future<ExchangeRateSet?> refreshRates() {
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }

    _refreshInFlight = _refreshRatesInternal();
    return _refreshInFlight!.whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<ExchangeRateSet?> _refreshRatesInternal() async {
    try {
      final uri = Uri.parse('https://open.er-api.com/v6/latest/$_baseCurrency');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return await getRateSet();
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawRates = (decoded['rates'] as Map?) ?? const {};
      final rates = <String, double>{
        _baseCurrency: 1.0,
      };

      for (final currency in SupportedCurrency.values) {
        final code = currency.code;
        if (code == _baseCurrency) {
          rates[code] = 1.0;
          continue;
        }
        final rate = ExchangeRateSet._toDouble(rawRates[code]);
        if (rate != null && rate > 0) {
          rates[code] = rate;
        }
      }

      if (rates.length < 2) {
        return await getRateSet();
      }

      final rateSet = ExchangeRateSet(
        baseCurrency: _baseCurrency,
        rates: rates,
        fetchedAt: DateTime.now(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(rateSet.toJson()));
      _cachedRateSet = rateSet;
      return rateSet;
    } catch (_) {
      return await getRateSet();
    }
  }
}
