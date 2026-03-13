import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

String localizeCategoryLabel(String value, BuildContext context) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return value;

  final normalized = trimmed
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final titleCase = normalized
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map(
        (word) =>
            word.substring(0, 1).toUpperCase() +
            word.substring(1).toLowerCase(),
      )
      .join(' ');

  String? translateIfExists(String key) {
    if (!trExists(key, context: context)) return null;
    return key.tr(context: context);
  }

  for (final key in <String>[trimmed, normalized, titleCase]) {
    final translated = translateIfExists(key);
    if (translated != null) return translated;
  }

  final normalizedLower = normalized.toLowerCase();
  final normalizedAlias = normalizedLower
      .replaceAll('&', ' and ')
      .replaceAll('/', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final normalizedAliasCompact = normalizedAlias.replaceAll(' and ', ' ');

  const aliases = <String, String>{
    'food drink': 'Food & Drink',
    'food drinks': 'Food & Drink',
    'food beverage': 'Food & Drink',
    'food beverages': 'Food & Drink',
    'food and beverage': 'Food & Drink',
    'food and beverages': 'Food & Drink',
    'restaurants': 'Restaurants',
    'restaurant': 'Restaurant',
    'realestate': 'Real Estate',
    'real estate': 'Real Estate',
    'automobile': 'Automotive',
    'auto': 'Auto',
    'automotive': 'Automotive',
    'health beauty': 'Health & Beauty',
    'health and beauty': 'Health & Beauty',
    'health wellness': 'Health & Wellness',
    'health and wellness': 'Health & Wellness',
    'beauty spa': 'Beauty & Spa',
    'beauty and spa': 'Beauty & Spa',
    'home service': 'Home Services',
    'home services': 'Home Services',
    'professional service': 'Professional Service',
    'professional services': 'Professional Services',
    'travel tourism': 'Travel & Tourism',
    'travel and tourism': 'Travel & Tourism',
    'home garden': 'Home & Garden',
    'home and garden': 'Home & Garden',
    'retail stores': 'Shopping',
    'retail and stores': 'Shopping',
    'construction': 'Home Services',
    'construction handyman services': 'Home Services',
    'construction and handyman services': 'Home Services',
    'handyman services': 'Home Services',
    'personal service': 'Professional Service',
    'personal services': 'Professional Services',
    'street seasonal hustles': 'Street & Seasonal Hustles',
    'street and seasonal hustles': 'Street & Seasonal Hustles',
    'education skills transfer': 'Education & Skills Transfer',
    'education and skills transfer': 'Education & Skills Transfer',
  };

  final aliasKey = aliases[normalizedLower] ??
      aliases[normalizedAlias] ??
      aliases[normalizedAliasCompact];
  if (aliasKey != null) {
    final translated = translateIfExists(aliasKey);
    if (translated != null) return translated;
  }

  final keywordSource = normalizedAliasCompact
      .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final keywordHaystack = ' $keywordSource ';
  bool hasWord(String word) => keywordHaystack.contains(' $word ');
  bool hasAny(List<String> words) => words.any(hasWord);

  String? canonicalKey;
  if (hasAny(['restaurant', 'restaurants'])) {
    canonicalKey = 'Restaurants';
  } else if (hasWord('real') && hasWord('estate') ||
      hasAny(['property', 'properties', 'realtor'])) {
    canonicalKey = 'Real Estate';
  } else if (hasAny(
    ['retail', 'shop', 'shopping', 'store', 'stores', 'market', 'boutique'],
  )) {
    canonicalKey = 'Shopping';
  } else if (hasAny([
    'construction',
    'handyman',
    'contractor',
    'repair',
    'plumbing',
    'electric',
    'cleaning',
    'maintenance',
    'renovation',
    'home',
    'services',
  ])) {
    canonicalKey = 'Home Services';
  } else if (hasAny([
        'professional',
        'consulting',
        'accounting',
        'legal',
        'agency',
      ]) ||
      ((hasWord('personal') || hasWord('concierge')) &&
          hasAny(['service', 'services']))) {
    canonicalKey = 'Professional Services';
  } else if (hasAny(['nightlife', 'club', 'clubs', 'bar', 'bars'])) {
    canonicalKey = 'Nightlife';
  } else if (hasAny([
    'food',
    'beverage',
    'drink',
    'drinks',
    'dining',
    'cafe',
    'bakery',
  ])) {
    canonicalKey = 'Food & Drink';
  } else if (hasAny([
    'auto',
    'automotive',
    'car',
    'cars',
    'vehicle',
    'vehicles',
    'mechanic',
  ])) {
    canonicalKey = 'Automotive';
  } else if (hasAny(['beauty', 'spa', 'salon', 'cosmetic'])) {
    canonicalKey = 'Beauty & Spa';
  } else if (hasAny(['health', 'fitness', 'gym', 'wellness'])) {
    canonicalKey = 'Health & Fitness';
  } else if (hasAny([
    'electronics',
    'tech',
    'technology',
    'computer',
    'mobile',
    'phone',
  ])) {
    canonicalKey = 'Electronics';
  } else if (hasAny(['event', 'events'])) {
    canonicalKey = 'Events';
  } else if (hasAny(['entertainment', 'music', 'movie', 'cinema'])) {
    canonicalKey = 'Entertainment';
  } else if (hasAny([
    'education',
    'school',
    'tutor',
    'training',
    'skills',
    'transfer',
  ])) {
    canonicalKey = 'Education';
  } else if (hasAny(['travel', 'tourism', 'tour', 'vacation'])) {
    canonicalKey = 'Travel & Tourism';
  } else if (hasAny(['pet', 'pets', 'veterinary', 'vet'])) {
    canonicalKey = 'Pets';
  } else if (hasAny(['sport', 'sports', 'athletic'])) {
    canonicalKey = 'Sports';
  } else if (hasAny(['accommodation', 'hotel', 'hostel', 'lodging'])) {
    canonicalKey = 'Accommodation';
  } else if (hasAny(['home', 'garden'])) {
    canonicalKey = 'Home & Garden';
  }

  if (canonicalKey != null) {
    final translated = translateIfExists(canonicalKey);
    if (translated != null) return translated;
  }

  return normalized;
}
