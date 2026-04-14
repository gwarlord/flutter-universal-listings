import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:caribtap/core/config/app_env.dart';

class GeminiAIService {
  static final GeminiAIService _instance = GeminiAIService._internal();
  factory GeminiAIService() => _instance;
  GeminiAIService._internal();

  // Gemini API key can come from dart-defines or .env fallback.
  static String get _apiKey => AppEnv.geminiApiKey;
  
  GenerativeModel? _model;
  bool _initialized = false;

  String get _maskedKey {
    final key = _apiKey;
    if (key.length < 8) return '***';
    final start = key.substring(0, 6);
    final end = key.substring(key.length - 4);
    return '$start...$end';
  }

  void initialize() {
    if (_initialized && _model != null) return;
    if (_apiKey.isEmpty) {
      print('❌ [GEMINI] API key not configured.');
      throw Exception('GEMINI_API_KEY not configured');
    }
    // Use 'gemini-2.0-flash' as recommended by Google
    const String modelName = 'gemini-2.0-flash';
    _model = GenerativeModel(
      model: modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1024,
      ),
    );
    _initialized = true;
    print('🚀 [GEMINI v1.3] INITIALIZED (key: $_maskedKey)');
    print('🚀 [GEMINI v1.3] Using: gemini-2.0-flash (v1beta)');
  }

  Future<String> generateListingDescription({
    required String title,
    required String category,
    String? existingDescription,
    String? location,
    List<String> services = const [],
  }) async {
    initialize();
    try {
      print('🤖 [GEMINI] Generating description...');
      
      final servicesText = services.isNotEmpty 
          ? '\nServices: ${services.join(", ")}'
          : '';
      
      final locationText = location?.isNotEmpty ?? false
          ? 'in $location'
          : '';
      
      final prompt = '''Create a brief, engaging description for a Caribbean $category business.

Business: $title $locationText$servicesText

Write a concise 2-3 sentence description (max 80 words) that:
- Highlights what makes this business unique
- Mentions key services or benefits
- Invites customers to engage

Use plain text only. NO markdown, NO asterisks, NO hashtags.

Return ONLY the description text with no preamble.''';
      
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      var aiText = response.text ?? '';
      
      aiText = aiText.trim();
      
      // Remove common preambles if present
      final preambles = [
        'Here is',
        'Here\'s',
        'Description:',
        'Based on',
        'I\'ve created',
        'Sure,',
        'Certainly,',
        'Of course,',
        'AI-generated',
      ];
      for (final p in preambles) {
        if (aiText.toLowerCase().startsWith(p.toLowerCase())) {
          aiText = aiText.substring(p.length).trimLeft();
          if (aiText.startsWith(':')) {
            aiText = aiText.substring(1).trimLeft();
          }
        }
      }
      
      print('✅ [GEMINI] Generated (${aiText.length} chars)');
      return aiText;
    } catch (e) {
      print('❌ [GEMINI] Error (generateListingDescription): $e');
      return _diagnoseAndFallback(e);
    }
  }

  Future<String> enhanceDescription({
    required String description,
    required String category,
  }) async {
    initialize();
    try {
      print('🤖 [GEMINI] Enhancing description...');
      final content = [Content.text('''Improve this $category business description. Make it more engaging and professional while keeping it brief.

Current: $description

Write a concise 2-3 sentence improvement (max 80 words) that:
- Highlights unique value
- Sounds professional and warm
- Invites customer action

Use PLAIN TEXT ONLY. NO markdown, NO asterisks, NO hashtags, NO special formatting.

Return ONLY the improved description with no preamble.''')];
      final response = await _model!.generateContent(content);
      var aiText = response.text ?? description;
      
      aiText = aiText.trim();
      
      // Remove common preambles if present
      final preambles = [
        'Here is',
        'Here\'s',
        'Suggestion:',
        'Improved:',
        'Enhanced:',
        'Enhanced description:',
        'Option',
        'Sure,',
        'Certainly,',
        'Of course,',
        'AI-generated',
        'Based on the description',
      ];
      for (final p in preambles) {
        if (aiText.toLowerCase().startsWith(p.toLowerCase())) {
          aiText = aiText.substring(p.length).trimLeft();
          if (aiText.startsWith(':')) {
            aiText = aiText.substring(1).trimLeft();
          }
        }
      }
      
      print('✅ [GEMINI] Enhanced (${aiText.length} chars)');
      return aiText;
    } catch (e) {
      print('❌ [GEMINI] Error (enhanceDescription): $e');
      return _diagnoseAndFallback(e);
    }
  }

  String _diagnoseAndFallback(Object e) {
    final err = e.toString();
    print('🔎 [GEMINI] Raw error: $err');
    print('🔑 [GEMINI] Key in use (masked): $_maskedKey');
    if (err.contains('not found') || err.contains('not supported')) {
      print('');
      print('═════════════════════════════════════════════════════════════');
      print('⚠️  GEMINI API NOT ENABLED OR RESTRICTED');
      print('═════════════════════════════════════════════════════════════');
      print('The Generative Language API is NOT ENABLED for this project.');
      print('');
      print('FIX: Go to Google Cloud Console and:');
      print('  1. Select your project');
      print('  2. Enable "Generative Language API"');
      print('  3. Ensure the API key has the correct permissions');
      print('═════════════════════════════════════════════════════════════');
      print('');
      return 'AI feature temporarily unavailable. Please enable Generative Language API in Google Cloud Console.';
    }
    if (err.contains('UNAUTHENTICATED') || err.contains('invalid API key')) {
      return 'Invalid or expired API key. Please verify your API key.';
    }
    return 'Error: $err';
  }

  bool get isReady => _apiKey.isNotEmpty;
}
