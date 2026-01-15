// lib/listings/utils/caribbean_countries.dart

class CaribbeanCountry {
  final String code; // ISO-3166-1 alpha-2 where possible
  final String name;

  const CaribbeanCountry({
    required this.code,
    required this.name,
  });
}

/// CARICOM + key Caribbean territories commonly used in “regional” apps.
class CaribbeanCountries {
  static const List<CaribbeanCountry> all = [
    CaribbeanCountry(code: 'AI', name: 'Anguilla'),
    CaribbeanCountry(code: 'AG', name: 'Antigua and Barbuda'),
    CaribbeanCountry(code: 'AW', name: 'Aruba'),
    CaribbeanCountry(code: 'BS', name: 'Bahamas'),
    CaribbeanCountry(code: 'BB', name: 'Barbados'),
    CaribbeanCountry(code: 'BZ', name: 'Belize'),
    CaribbeanCountry(code: 'BM', name: 'Bermuda'),
    CaribbeanCountry(code: 'VG', name: 'British Virgin Islands'),
    CaribbeanCountry(code: 'BQ', name: 'Caribbean Netherlands'),
    CaribbeanCountry(code: 'KY', name: 'Cayman Islands'),
    CaribbeanCountry(code: 'CU', name: 'Cuba'),
    CaribbeanCountry(code: 'CW', name: 'Curaçao'),
    CaribbeanCountry(code: 'DM', name: 'Dominica'),
    CaribbeanCountry(code: 'DO', name: 'Dominican Republic'),
    CaribbeanCountry(code: 'GF', name: 'French Guiana'),
    CaribbeanCountry(code: 'GD', name: 'Grenada'),
    CaribbeanCountry(code: 'GP', name: 'Guadeloupe'),
    CaribbeanCountry(code: 'GY', name: 'Guyana'),
    CaribbeanCountry(code: 'HT', name: 'Haiti'),
    CaribbeanCountry(code: 'JM', name: 'Jamaica'),
    CaribbeanCountry(code: 'MQ', name: 'Martinique'),
    CaribbeanCountry(code: 'MS', name: 'Montserrat'),
    CaribbeanCountry(code: 'PR', name: 'Puerto Rico'),
    CaribbeanCountry(code: 'BL', name: 'Saint Barthélemy'),
    CaribbeanCountry(code: 'KN', name: 'Saint Kitts and Nevis'),
    CaribbeanCountry(code: 'LC', name: 'Saint Lucia'),
    CaribbeanCountry(code: 'MF', name: 'Saint Martin (French part)'),
    CaribbeanCountry(code: 'VC', name: 'Saint Vincent and the Grenadines'),
    CaribbeanCountry(code: 'SX', name: 'Sint Maarten (Dutch part)'),
    CaribbeanCountry(code: 'SR', name: 'Suriname'),
    CaribbeanCountry(code: 'TT', name: 'Trinidad and Tobago'),
    CaribbeanCountry(code: 'TC', name: 'Turks and Caicos Islands'),
    CaribbeanCountry(code: 'VI', name: 'U.S. Virgin Islands'),
  ];

  /// ✅ Validate Caribbean country codes
  static bool isAllowedCode(String? code) {
    if (code == null) return false;
    final normalized = code.trim().toUpperCase();
    return all.any((c) => c.code == normalized);
  }

  /// ✅ Lookup helper (USED by Home & Listing Details)
  static CaribbeanCountry? byCode(String? code) {
    if (code == null || code.trim().isEmpty) return null;

    final normalized = code.trim().toUpperCase();

    try {
      return all.firstWhere(
            (c) => c.code == normalized,
      );
    } catch (_) {
      return null;
    }
  }
}
