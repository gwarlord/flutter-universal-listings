import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

// Removed chat-related imports for migration to flutter_chat_ui
const facebookButtonColor = 0xFF415893;
const usersCollection = 'users';
const socialFeedsCollection = 'social_feeds';
const chatFeedLiveCollection = 'chat_feed_live';
const chatChannelsCollection = 'channels';
const messagesLiveCollection = 'messages_live';
const pageSizeLimit = 20;
const liveCollectionLimit = 50;

// DEPRECATED: Move to Firebase Cloud Functions - client-side FCM tokens are insecure
String get serverKey => dotenv.env['FCM_SERVER_KEY'] ?? '';

const eula = 'https://www.instamobile.io/eula-instachatty/';
const privacyPolicyURL = 'https://instamobile.io/privacy-policy/';

// Load from .env file - NEVER commit actual keys to git
String _firstNonEmpty(List<String?> candidates) {
	for (final value in candidates) {
		final trimmed = value?.trim() ?? '';
		if (trimmed.isNotEmpty) return trimmed;
	}
	return '';
}

String get googleApiKey => _firstNonEmpty([
	dotenv.env['GOOGLE_API_KEY'],
	dotenv.env['GOOGLE_MAPS_API_KEY'],
]);

String get googleAndroidApiKey => dotenv.env['GOOGLE_ANDROID_API_KEY'] ?? '';

String get googleIosApiKey => _firstNonEmpty([
	dotenv.env['GOOGLE_IOS_API_KEY'],
	dotenv.env['GOOGLE_MAPS_API_KEY'],
]);

String get googlePlacesApiKey => dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';

String get placesApiKey {
	if (googlePlacesApiKey.trim().isNotEmpty) return googlePlacesApiKey.trim();
	if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS &&
		googleIosApiKey.trim().isNotEmpty) {
		return googleIosApiKey.trim();
	}
	if (kIsWeb) return googleApiKey;
	if (defaultTargetPlatform == TargetPlatform.android &&
		googleAndroidApiKey.trim().isNotEmpty) {
		return googleAndroidApiKey.trim();
	}
	return googleApiKey;
}

String get placesApiKeySource {
	if (googlePlacesApiKey.trim().isNotEmpty) return 'GOOGLE_PLACES_API_KEY';
	if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS &&
		googleIosApiKey.trim().isNotEmpty) {
		return 'GOOGLE_IOS_API_KEY/GOOGLE_MAPS_API_KEY';
	}
	if (kIsWeb) return 'GOOGLE_API_KEY/GOOGLE_MAPS_API_KEY';
	if (defaultTargetPlatform == TargetPlatform.android &&
		googleAndroidApiKey.trim().isNotEmpty) {
		return 'GOOGLE_ANDROID_API_KEY';
	}
	return 'GOOGLE_API_KEY/GOOGLE_MAPS_API_KEY';
}

String maskApiKey(String key) {
	final trimmed = key.trim();
	if (trimmed.isEmpty) return '<empty>';
	if (trimmed.length <= 8) return '***';
	return '${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 4)}';
}
