import 'package:intl_phone_number_input/intl_phone_number_input.dart';

class PhoneFormatHint {
  final String countryName;
  final String nationalExample;
  final String internationalExample;

  const PhoneFormatHint({
    required this.countryName,
    required this.nationalExample,
    required this.internationalExample,
  });
}

const Map<String, PhoneFormatHint> _phoneFormatHints = {
  'AI': PhoneFormatHint(countryName: 'Anguilla', nationalExample: '2641234567', internationalExample: '+12641234567'),
  'AG': PhoneFormatHint(countryName: 'Antigua and Barbuda', nationalExample: '2681234567', internationalExample: '+12681234567'),
  'AW': PhoneFormatHint(countryName: 'Aruba', nationalExample: '5601234', internationalExample: '+2975601234'),
  'BS': PhoneFormatHint(countryName: 'Bahamas', nationalExample: '2421234567', internationalExample: '+12421234567'),
  'BB': PhoneFormatHint(countryName: 'Barbados', nationalExample: '2461234567', internationalExample: '+12461234567'),
  'BZ': PhoneFormatHint(countryName: 'Belize', nationalExample: '6221234', internationalExample: '+5016221234'),
  'BM': PhoneFormatHint(countryName: 'Bermuda', nationalExample: '4411234567', internationalExample: '+14411234567'),
  'VG': PhoneFormatHint(countryName: 'British Virgin Islands', nationalExample: '2841234567', internationalExample: '+12841234567'),
  'BQ': PhoneFormatHint(countryName: 'Caribbean Netherlands', nationalExample: '3181234', internationalExample: '+5993181234'),
  'KY': PhoneFormatHint(countryName: 'Cayman Islands', nationalExample: '3451234567', internationalExample: '+13451234567'),
  'CU': PhoneFormatHint(countryName: 'Cuba', nationalExample: '51234567', internationalExample: '+5351234567'),
  'CW': PhoneFormatHint(countryName: 'Curacao', nationalExample: '95123456', internationalExample: '+59995123456'),
  'DM': PhoneFormatHint(countryName: 'Dominica', nationalExample: '7671234567', internationalExample: '+17671234567'),
  'DO': PhoneFormatHint(countryName: 'Dominican Republic', nationalExample: '8091234567', internationalExample: '+18091234567'),
  'GF': PhoneFormatHint(countryName: 'French Guiana', nationalExample: '694201234', internationalExample: '+594694201234'),
  'GD': PhoneFormatHint(countryName: 'Grenada', nationalExample: '4731234567', internationalExample: '+14731234567'),
  'GP': PhoneFormatHint(countryName: 'Guadeloupe', nationalExample: '690123456', internationalExample: '+590690123456'),
  'GY': PhoneFormatHint(countryName: 'Guyana', nationalExample: '6123456', internationalExample: '+5926123456'),
  'HT': PhoneFormatHint(countryName: 'Haiti', nationalExample: '34123456', internationalExample: '+50934123456'),
  'JM': PhoneFormatHint(countryName: 'Jamaica', nationalExample: '8761234567', internationalExample: '+18761234567'),
  'MQ': PhoneFormatHint(countryName: 'Martinique', nationalExample: '696201234', internationalExample: '+596696201234'),
  'MS': PhoneFormatHint(countryName: 'Montserrat', nationalExample: '6641234567', internationalExample: '+16641234567'),
  'PR': PhoneFormatHint(countryName: 'Puerto Rico', nationalExample: '7871234567', internationalExample: '+17871234567'),
  'BL': PhoneFormatHint(countryName: 'Saint Barthelemy', nationalExample: '690123456', internationalExample: '+590690123456'),
  'KN': PhoneFormatHint(countryName: 'Saint Kitts and Nevis', nationalExample: '8691234567', internationalExample: '+18691234567'),
  'LC': PhoneFormatHint(countryName: 'Saint Lucia', nationalExample: '7581234567', internationalExample: '+17581234567'),
  'MF': PhoneFormatHint(countryName: 'Saint Martin', nationalExample: '690123456', internationalExample: '+590690123456'),
  'VC': PhoneFormatHint(countryName: 'Saint Vincent and the Grenadines', nationalExample: '7841234567', internationalExample: '+17841234567'),
  'SX': PhoneFormatHint(countryName: 'Sint Maarten', nationalExample: '7215201234', internationalExample: '+17215201234'),
  'SR': PhoneFormatHint(countryName: 'Suriname', nationalExample: '7412345', internationalExample: '+5977412345'),
  'TT': PhoneFormatHint(countryName: 'Trinidad and Tobago', nationalExample: '8681234567', internationalExample: '+18681234567'),
  'TC': PhoneFormatHint(countryName: 'Turks and Caicos Islands', nationalExample: '6491234567', internationalExample: '+16491234567'),
  'VI': PhoneFormatHint(countryName: 'U.S. Virgin Islands', nationalExample: '3401234567', internationalExample: '+13401234567'),
};

String digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

/// Normalizes user-entered phone values into a verification-friendly format.
///
/// Rules:
/// - Keeps digits only (plus an optional leading +).
/// - Converts 00 international prefix to +.
/// - Adds + automatically when missing.
String normalizePhoneForVerification(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  if (trimmed.startsWith('00')) {
    final digits = digitsOnly(trimmed.substring(2));
    return digits.isEmpty ? '' : '+$digits';
  }

  final hasLeadingPlus = trimmed.startsWith('+');
  final digits = digitsOnly(trimmed);
  if (digits.isEmpty) return '';

  return hasLeadingPlus ? '+$digits' : '+$digits';
}

int phoneDigitCount(String raw) => digitsOnly(raw).length;

/// Basic E.164 guardrail used across capture points.
bool isLikelyVerifiablePhone(String raw) {
  final normalized = normalizePhoneForVerification(raw);
  final count = phoneDigitCount(normalized);
  return normalized.startsWith('+') && count >= 8 && count <= 15;
}

Future<String?> normalizePhoneForCountry(String raw, String isoCode) async {
  final normalizedIso = isoCode.trim().toUpperCase();
  if (normalizedIso.isEmpty) return null;

  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final candidate = trimmed.startsWith('+') || trimmed.startsWith('00')
      ? normalizePhoneForVerification(trimmed)
      : trimmed;

  try {
    final parsed = await PhoneNumber.getRegionInfoFromPhoneNumber(
      candidate,
      normalizedIso,
    );

    if ((parsed.isoCode ?? '').trim().toUpperCase() != normalizedIso) {
      return null;
    }

    return parsed.phoneNumber;
  } catch (_) {
    return null;
  }
}

Future<String> formatPhoneForDisplay(String raw, String isoCode) async {
  final normalized = await normalizePhoneForCountry(raw, isoCode);
  if (normalized == null) return raw;

  try {
    final parsed = await PhoneNumber.getRegionInfoFromPhoneNumber(
      normalized,
      isoCode.trim().toUpperCase(),
    );
    return await PhoneNumber.getParsableNumber(parsed);
  } catch (_) {
    return raw;
  }
}

PhoneFormatHint? phoneFormatHintForIso(String isoCode) {
  return _phoneFormatHints[isoCode.trim().toUpperCase()];
}

String phoneGuidanceMessage(String isoCode) {
  final hint = phoneFormatHintForIso(isoCode);
  if (hint == null) {
    return 'Enter the full phone number including area code, or use international format like +12345678901.';
  }

  return 'For ${hint.countryName}, enter the full number including area code. Example: ${hint.nationalExample} or ${hint.internationalExample}.';
}

String phoneValidationMessage(String isoCode) {
  final hint = phoneFormatHintForIso(isoCode);
  if (hint == null) {
    return 'Enter a valid phone number for your selected country, including area code or country code.';
  }

  return 'This number does not match ${hint.countryName}. Enter the full number including area code, for example ${hint.nationalExample} or ${hint.internationalExample}.';
}
