/// Photo Enhancement - Dependencies & Setup Documentation
/// 
/// This file documents all required dependencies and initialization setup

class PhotoEnhancementSetupGuide {
  /// Dependencies to add to pubspec.yaml
  /// 
  /// Add these to your pubspec.yaml dev_dependencies or dependencies section
  static const Map<String, String> requiredDependencies = {
    // Already likely installed in your project:
    'flutter_bloc': '9.1.1+',
    'cloud_firestore': '4.14.0+',
    'cloud_functions': '4.5.0+',
    'firebase_storage': '11.0.0+',
    'firebase_analytics': '10.0.0+',

    // May need to add:
    'connectivity_plus': '5.0.0+', // For offline detection
    'shared_preferences': '2.0.0+', // For offline queue (usually already there)
  };

  /// Functions dependencies (package.json for TypeScript Cloud Functions)
  /// 
  /// Add these to your functions/package.json
  static const Map<String, String> cloudFunctionsDependencies = {
    'firebase-functions': '^4.5.0',
    'firebase-admin': '^12.0.0',
    '@google-cloud/vision': '^3.5.0',
    '@google-cloud/storage': '^7.0.0',
    'sharp': '^0.32.0',
    'uuid': '^9.0.0',
  };

  /// Step-by-step setup instructions
  static const List<String> setupSteps = [
    '1. Update pubspec.yaml with required dependencies',
    '2. Run "flutter pub get" to install new packages',
    '3. Update functions/package.json with Cloud Function dependencies',
    '4. Run "npm install" in functions directory',
    '5. Enable Cloud Functions API in Google Cloud Console',
    '6. Enable Vision API in Google Cloud Console',
    '7. Enable Cloud Storage API in Google Cloud Console',
    '8. Configure Firebase Firestore Security Rules (already provided)',
    '9. Deploy Cloud Functions: firebase deploy --only functions:enhancePhoto',
    '10. Initialize services in your app with BlocProvider',
    '11. Add PhotoEnhancementCubit to your BLoC structure',
    '12. Test with actual listing and images',
  ];

  /// Initialization code for main.dart or app setup
  static const String initializationCode = '''
// In your main.dart or app initialization code:

import 'package:caribtap/listings/ui/photo_enhancement/photo_enhancement.dart';
import 'package:shared_preferences/shared_preferences.dart';

void setupPhotoEnhancement() {
  // Initialize SharedPreferences for offline queue
  SharedPreferences.getInstance().then((prefs) {
    // Create service instances
    final enhancementService = PhotoEnhancementService();
    final quotaManager = QuotaManager();
    final offlineQueueManager = OfflineQueueManager(prefs: prefs);
    final analytics = EnhancementAnalytics();

    // These will be provided via BlocProvider
    // See integration_guide.dart for BlocProvider setup
  });
}

// In your app's BlocProvider tree, add:
BlocProvider<PhotoEnhancementCubit>(
  create: (context) => PhotoEnhancementCubit(
    enhancementService: PhotoEnhancementService(),
    quotaManager: QuotaManager(),
    userQuotaManager: UserQuotaManager(),
    offlineQueue: OfflineQueueManager(prefs: prefs), 
    analytics: EnhancementAnalytics(),
  ),
  child: YourAppWidget(),
)
''';

  /// Firebase Console setup steps
  static const String firebaseSetupSteps = '''
  1. Go to Firebase Console (console.firebase.google.com)
  2. Select your CaribTap project
  3. Enable these APIs:
     - Cloud Functions (Build > Functions)
     - Vision AI (Discover > APIs)
     - Cloud Storage (Storage)
  
  4. Set up Cloud Function:
     - Create function: enhancePhoto
     - Trigger: HTTPS (Callable)
     - Runtime: Node.js 18
     - Deploy with: firebase deploy --only functions
  
  5. Configure Firebase Rules:
     - Firestore > Rules (already configured)
     - Add image_variants and enhancement_quotas collections
  
  6. Set Cloud Function permissions:
     - Ensure service account has Vision API permissions
     - Ensure service account has Storage permissions
''';

  /// Environment variables needed
  static const Map<String, String> requiredEnvironmentVars = {
    'FIREBASE_PROJECT_ID': 'Your Firebase Project ID',
    'FIREBASE_STORAGE_BUCKET': 'your-project.appspot.com',
    'GOOGLE_CLOUD_VISION_API_KEY': 'Your API Key',
  };

  /// Android configuration required
  static const String androidConfig = '''
  In android/app/build.gradle:

  android {
    compileSdkVersion 34  // Updated for latest APIs
    
    defaultConfig {
      minSdkVersion 21    // Required for some Firebase features
      targetSdkVersion 34
    }
  }

  In android/app/AndroidManifest.xml, add permissions:
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
  <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
''';

  /// iOS configuration required
  static const String iosConfig = '''
  In ios/Podfile, ensure:
  - platform :ios, '12.0' (minimum for Firebase)
  
  In ios/Runner/Info.plist, add:
  <key>NSPhotoLibraryUsageDescription</key>
  <string>App needs access to photos to enhance them</string>
  
  <key>NSCameraUsageDescription</key>
  <string>App needs camera access</string>
''';

  /// Troubleshooting guide
  static const Map<String, String> troubleshootingGuide = {
    'Cloud Function not deploying': 'Check firebase deploy logs. Ensure Node.js dependencies are installed.',
    'Vision API errors': 'Ensure Vision API is enabled in Google Cloud Console and API key has correct permissions.',
    'Storage permission denied': 'Check Firestore rules and Firebase authentication status.',
    'Images not uploading': 'Verify Cloud Storage bucket exists and has correct access rules.',
    'Offline queue not working': 'Ensure SharedPreferences is initialized before accessing OfflineQueueManager.',
    'Cubit state not updating': 'Verify BlocListener is properly set up and cubit is provided in BlocProvider.',
  };
}

/// Sample configuration injection
class PhotoEnhancementConfigInjection {
  static const String exampleSetup = '''
  // In your main app initialization:
  
  void setupDependencies() {
    // Vision API Configuration
    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = 'path/to/service-account.json';
    
    // Firebase configuration (usually auto-initialized)
    // Firebase.initializeApp() is called in main.dart
    
    // Storage bucket configuration
    final storageBucket = FirebaseStorage.instance.bucket('your-bucket-name');
  }
  ''';
}

/// Deployment checklist
class PhotoEnhancementDeploymentChecklist {
  static final List<String> checklist = [
    '☐ All dependencies added to pubspec.yaml',
    '☐ flutter pub get executed',
    '☐ Vision API enabled in Google Cloud',
    '☐ Cloud Functions API enabled',
    '☐ Cloud Storage API enabled',
    '☐ Cloud Functions deployed (firebase deploy)',
    '☐ Firestore security rules updated',
    '☐ enhancement_quotas collection created',
    '☐ image_variants subcollection structure ready',
    '☐ BlocProvider<PhotoEnhancementCubit>() added',
    '☐ PhotoEnhancementBottomSheet imported and useable',
    '☐ Enhance button added to listing edit screen',
    '☐ Subscription tier checks implemented',
    '☐ Offline queue manager initialized',
    '☐ Analytics events logged',
    '☐ Feature flag created in Firebase Remote Config',
    '☐ Testing with real images completed',
    '☐ User documentation prepared',
  ];

  static void printChecklist() {
    print('');
    print('╔════════════════════════════════════════════════════════════╗');
    print('║ Photo Enhancement - Deployment Checklist                   ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('');
    for (final item in checklist) {
      print(item);
    }
    print('');
  }
}
