import 'package:flutter/foundation.dart';
import 'package:caribtap/core/config/app_env.dart';

// Removed chat-related imports for migration to flutter_chat_ui
const usersCollection = 'users';
const socialFeedsCollection = 'social_feeds';
const chatFeedLiveCollection = 'chat_feed_live';
const chatChannelsCollection = 'channels';
const messagesLiveCollection = 'messages_live';
const pageSizeLimit = 20;
const liveCollectionLimit = 50;

const eula = 'https://www.instamobile.io/eula-instachatty/';
const privacyPolicyURL = 'https://instamobile.io/privacy-policy/';

// Load from .env file - NEVER commit actual keys to git
String get googleApiKey => AppEnv.googleApiKey;

String get googleAndroidApiKey => AppEnv.googleAndroidApiKey;

String get googleIosApiKey => AppEnv.googleIosApiKey;

String get googlePlacesApiKey => AppEnv.googlePlacesApiKey;

String get placesApiKey {
	// On iOS, prefer the iOS-restricted key so Places requests include a key
	// that matches X-Ios-Bundle-Identifier restrictions.
	if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS &&
		googleIosApiKey.trim().isNotEmpty) {
		return googleIosApiKey.trim();
	}
	if (googlePlacesApiKey.trim().isNotEmpty) return googlePlacesApiKey.trim();
	if (googleApiKey.trim().isNotEmpty) return googleApiKey.trim();
	// Places autocomplete/details use HTTP APIs, so platform-restricted SDK
	// keys are only safe as a last resort fallback on non-iOS platforms.
	if (defaultTargetPlatform == TargetPlatform.android &&
		googleAndroidApiKey.trim().isNotEmpty) {
		return googleAndroidApiKey.trim();
	}
	return '';
}

String get placesApiKeySource {
	if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS &&
		googleIosApiKey.trim().isNotEmpty) {
		return 'GOOGLE_IOS_API_KEY';
	}
	if (googlePlacesApiKey.trim().isNotEmpty) return 'GOOGLE_PLACES_API_KEY';
	if (googleApiKey.trim().isNotEmpty) return 'GOOGLE_API_KEY/GOOGLE_MAPS_API_KEY';
	if (defaultTargetPlatform == TargetPlatform.android &&
		googleAndroidApiKey.trim().isNotEmpty) {
		return 'GOOGLE_ANDROID_API_KEY fallback';
	}
	return '<missing>';
}

String maskApiKey(String key) {
	final trimmed = key.trim();
	if (trimmed.isEmpty) return '<empty>';
	if (trimmed.length <= 8) return '***';
	return '${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 4)}';
}
