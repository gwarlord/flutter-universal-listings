import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppEnv {
  static const MethodChannel _envChannel = MethodChannel('caribtap/app_env');
  static const String _googleApiKeyDefine =
      String.fromEnvironment('GOOGLE_API_KEY', defaultValue: '');
  static const String _googleMapsApiKeyDefine =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');
  static const String _googleAndroidApiKeyDefine =
      String.fromEnvironment('GOOGLE_ANDROID_API_KEY', defaultValue: '');
  static const String _googleIosApiKeyDefine =
      String.fromEnvironment('GOOGLE_IOS_API_KEY', defaultValue: '');
  static const String _googlePlacesApiKeyDefine =
      String.fromEnvironment('GOOGLE_PLACES_API_KEY', defaultValue: '');
  static const String _googleWebClientIdDefine =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');
  static const String _geminiApiKeyDefine =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _webRecaptchaSiteKeyDefine =
      String.fromEnvironment('WEB_RECAPTCHA_SITE_KEY', defaultValue: '');
  static const String _appCheckForceDebugProviderDefine =
      String.fromEnvironment('APPCHECK_FORCE_DEBUG_PROVIDER', defaultValue: '');
  static String _nativeGoogleMapsApiKey = '';
  static String _nativeGooglePlacesApiKey = '';
  static String _nativeGeminiApiKey = '';

  static Future<void> loadNativePlatformConfig() async {
    if (kIsWeb) return;
    try {
      final key = await _envChannel.invokeMethod<String>('getGoogleMapsApiKey');
      _nativeGoogleMapsApiKey = key?.trim() ?? '';
    } catch (_) {
      _nativeGoogleMapsApiKey = '';
    }
    try {
      final key = await _envChannel.invokeMethod<String>('getGooglePlacesApiKey');
      _nativeGooglePlacesApiKey = key?.trim() ?? '';
    } catch (_) {
      _nativeGooglePlacesApiKey = '';
    }
    try {
      final key = await _envChannel.invokeMethod<String>('getGeminiApiKey');
      _nativeGeminiApiKey = key?.trim() ?? '';
    } catch (_) {
      _nativeGeminiApiKey = '';
    }
  }

  static Future<bool> loadDotEnvIfPresent() async {
    try {
      await dotenv.load(fileName: '.env');
      return true;
    } catch (_) {
      return false;
    }
  }

  static String get googleApiKey => _firstNonEmpty([
        _googleApiKeyDefine,
        _googleMapsApiKeyDefine,
      _dotenvValue('GOOGLE_API_KEY'),
      _dotenvValue('GOOGLE_MAPS_API_KEY'),
      _nativeGoogleMapsApiKey,
      ]);

  static String get googleMapsApiKey => _firstNonEmpty([
        _googleMapsApiKeyDefine,
      _dotenvValue('GOOGLE_MAPS_API_KEY'),
      _nativeGoogleMapsApiKey,
      ]);

  static String get googleAndroidApiKey => _firstNonEmpty([
        _googleAndroidApiKeyDefine,
      _dotenvValue('GOOGLE_ANDROID_API_KEY'),
      _nativeGoogleMapsApiKey,
      ]);

  static String get googleIosApiKey => _firstNonEmpty([
        _googleIosApiKeyDefine,
        _googleMapsApiKeyDefine,
      _dotenvValue('GOOGLE_IOS_API_KEY'),
      _dotenvValue('GOOGLE_MAPS_API_KEY'),
      _nativeGoogleMapsApiKey,
      ]);

  static String get googlePlacesApiKey => _firstNonEmpty([
        _googlePlacesApiKeyDefine,
      _dotenvValue('GOOGLE_PLACES_API_KEY'),
      _nativeGooglePlacesApiKey,
      _nativeGoogleMapsApiKey,
      ]);

  static String get googleWebClientId => _firstNonEmpty([
        _googleWebClientIdDefine,
      _dotenvValue('GOOGLE_WEB_CLIENT_ID'),
      ]);

  static String get geminiApiKey => _firstNonEmpty([
        _geminiApiKeyDefine,
      _dotenvValue('GEMINI_API_KEY'),
      _nativeGeminiApiKey,
      ]);

  static String get webRecaptchaSiteKey => _firstNonEmpty([
        _webRecaptchaSiteKeyDefine,
      _dotenvValue('WEB_RECAPTCHA_SITE_KEY'),
      ]);

  static bool get appCheckForceDebugProvider {
    final value = _firstNonEmpty([
      _appCheckForceDebugProviderDefine,
      _dotenvValue('APPCHECK_FORCE_DEBUG_PROVIDER'),
    ]).toLowerCase();
    return value == 'true';
  }

  static String? _dotenvValue(String key) {
    // flutter_dotenv throws NotInitializedError when .env wasn't loaded.
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }

  static String _firstNonEmpty(List<String?> candidates) {
    for (final value in candidates) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }
}