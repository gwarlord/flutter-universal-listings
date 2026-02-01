import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiAIService {
  static final GeminiAIService _instance = GeminiAIService._internal();
  factory GeminiAIService() => _instance;
  GeminiAIService._internal();

  // Gemini API key is now loaded from .env using flutter_dotenv
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  
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
      print('❌ [GEMINI] API key not found in .env!');
      throw Exception('GEMINI_API_KEY not set in .env');
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
          ? '\nServices offered: ${services.join(", ")}'
          : '';
      
      final locationText = location?.isNotEmpty ?? false
          ? '\nLocation: $location'
          : '';
      
      final prompt = '''Create an engaging, professional About/Description section for a Caribbean business with these details:

BUSINESS NAME: $title
CATEGORY: $category
$locationText$servicesText

Write a compelling description (150-250 words) that:
1. Opens with a compelling headline about what makes this business special
2. Highlights 3-5 key benefits, features, or services (use - for list items)
3. Includes a "Why Choose Us" section with 2-3 differentiators
4. Ends with a clear call to action (visit, call, book, message, etc.)
5. Uses markdown formatting (* for bold, - for lists) for visual appeal
6. Maintains a warm, professional, Caribbean-friendly tone

Return ONLY the description text with no preamble or meta-commentary. Start directly with the content.''';
      
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      var aiText = response.text ?? '';
      
      // Clean up markdown formatting from AI response
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
          // Remove trailing colon if present
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
      final content = [Content.text('''You are an expert Caribbean business marketing writer. Enhance and expand this $category listing description into a compelling, well-structured About section.

CURRENT DESCRIPTION: $description

REQUIREMENTS:
1. Start with a powerful headline that captures the business essence
2. Highlight 3-5 key benefits, features, or services
3. Use strong formatting: bold for emphasis, lists for features, short paragraphs for scannability
4. Add a unique "Why Choose Us" section with 2-3 differentiators
5. End with a clear call to action (visit, call, book, message)
6. Make it warm, professional, and Caribbean-friendly
7. Aim for 150-300 words total
8. Use markdown formatting (* for bold, - for lists, # for headers) to make it visually engaging

Return ONLY the enhanced description with no preamble, explanations, or meta-commentary. Start directly with the content.''')];
      final response = await _model!.generateContent(content);
      var aiText = response.text ?? description;
      
      // Clean up markdown formatting from AI response
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
          // Remove trailing colon if present
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
