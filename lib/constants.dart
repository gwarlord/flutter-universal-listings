import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

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
String get googleApiKey => dotenv.env['GOOGLE_API_KEY'] ?? '';
