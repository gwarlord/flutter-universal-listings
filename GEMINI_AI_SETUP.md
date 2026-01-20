# Gemini AI Integration Setup

## Getting Your API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy the generated key

## Adding the API Key to Your App

Open `lib/listings/services/gemini_ai_service.dart` and replace:

```dart
static const String _apiKey = 'YOUR_GEMINI_API_KEY_HERE';
```

With your actual API key:

```dart
static const String _apiKey = 'AIzaSyC...your-actual-key...';
```

## Features

- **Generate Description**: Creates a compelling listing description based on title, category, location, and services
- **Enhance Description**: Improves existing descriptions with better grammar, tone, and structure
- **Caribbean Context**: AI understands Caribbean business context and culture

## Usage

1. Fill in the listing title and category
2. Click the "✨ Generate with AI" or "✨ Enhance with AI" button below the description field
3. Wait for the AI to generate suggestions
4. Review and click "Use This" to apply, or "Regenerate" for a new version

## Rate Limits

Gemini API free tier:
- 60 requests per minute
- 1,500 requests per day
- Suitable for development and moderate production use

For production with high volume, consider:
- Upgrading to paid tier
- Adding rate limiting in the app
- Caching generated descriptions

## Security Note

⚠️ **Never commit your API key to version control!**

For production, store the API key in:
- Firebase Remote Config
- Environment variables
- Secure cloud key management

## Cost

Free tier is generous for most use cases. Paid pricing:
- Input: $0.00025 per 1K characters
- Output: $0.0005 per 1K characters

A typical description generation costs < $0.001
