import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiAIService {
  static final GeminiAIService _instance = GeminiAIService._internal();
  factory GeminiAIService() => _instance;
  GeminiAIService._internal();

  // Current Key: AIzaSyAnjfu8oJV3syOW_iqxFPAaLZw4Qf10S4c
  static const String _apiKey = 'AIzaSyAnjfu8oJV3syOW_iqxFPAaLZw4Qf10S4c';
  
  GenerativeModel? _model;
  bool _initialized = false;

  void initialize() {
    if (_initialized && _model != null) return;
    
    // 'gemini-1.5-flash' is the fastest "Free Tier" model available.
    // We use the 'models/' prefix which is sometimes required by the backend.
    const String modelName = 'gemini-1.5-flash';
    
    _model = GenerativeModel(
      model: modelName, 
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1024,
      ),
    );
    
    _initialized = true;
    print('🚀 [GEMINI v1.3] INITIALIZED');
    print('🚀 [GEMINI v1.3] Fast AI: gemini-1.5-flash (Free Tier)');
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
      print('❌ [GEMINI] Error: $e');
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
      final content = [Content.text('Improve this $category listing: $description')];
      final response = await _model!.generateContent(content);
      return response.text ?? description;
    } catch (e) {
      print('❌ [GEMINI] Error: $e');
      return _diagnoseAndFallback(e);
    }
  }

  String _diagnoseAndFallback(Object e) {
    final err = e.toString();
    if (err.contains('not found')) {
      return 'DIAGNOSIS: The API key is valid, but the "Generative Language API" is NOT ENABLED in the Cloud Console for this project. Please go to the Google Cloud Console and enable it.';
    }
    return 'Error: $err';
  }

  bool get isReady => _apiKey.isNotEmpty;
}
