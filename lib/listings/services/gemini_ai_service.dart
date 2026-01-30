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
      final prompt = 'Write a short professional description for a Caribbean business: $title ($category). Location: $location.';
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      return response.text ?? '';
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
      final content = [Content.text('Expand and improve this $category listing description for a Caribbean business. Write a multi-sentence, detailed, and engaging About section that highlights the business’s value, services, and benefits. Make the output longer and more helpful than the original. End with a clear, friendly call to action urging readers to contact, call, message, or book now. Do not include any preamble, explanation, or options. Only return the improved About text itself:\n\n$description')];
      final response = await _model!.generateContent(content);
      var aiText = response.text ?? description;
      // Post-process: Remove preamble, explanations, or options, keep only the first user-ready sentence/paragraph
      if (aiText.contains('\n')) {
        // Take only the first non-empty line
        aiText = aiText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).first;
      }
      // Remove common preambles if present
      final preambles = [
        'Here is',
        'Here\'s',
        'Suggestion:',
        'Improved',
        'Enhanced',
        'Option',
        'Sure,',
        'Certainly,',
        'Of course,',
        'AI-generated',
      ];
      for (final p in preambles) {
        if (aiText.toLowerCase().startsWith(p.toLowerCase())) {
          aiText = aiText.substring(p.length).trimLeft();
        }
      }
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
