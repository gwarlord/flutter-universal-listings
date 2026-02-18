/// Photo Enhancement Integration for Add/Edit Listing Screen
/// 
/// This file provides the necessary setup to integrate AI Photo Enhancement
/// into the add/edit listing workflow

import 'package:caribtap/listings/ui/photo_enhancement/photo_enhancement.dart';
import 'package:caribtap/listings/ui/photo_enhancement/services/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Initialize providers for photo enhancement feature in add listing screen
/// Add this to the BlocProvider section in AddListingWrappingWidget or EditListingWrappingWidget
/// 
/// Example:
/// ```dart
/// BlocProvider<PhotoEnhancementCubit>(
///   create: (context) => PhotoEnhancementCubit(
///     enhancementService: PhotoEnhancementService(),
///     quotaManager: QuotaManager(),
///     offlineQueue: OfflineQueueManager(prefs: prefs!),
///     analytics: EnhancementAnalytics(),
///   ),
///   child: YourChildWidget(),
/// )
/// ```

class PhotoEnhancementIntegrationSetup {
  /// Helper method to create all required service instances
  static Map<String, dynamic> createServices() {
    return {
      'enhancementService': PhotoEnhancementService(),
      'quotaManager': QuotaManager(),
      'analytics': EnhancementAnalytics(),
      // OfflineQueueManager requires SharedPreferences instance
    };
  }

  /// Code snippet to add to add_listing_screen.dart imports:
  static const String importSnippet = '''
import 'package:caribtap/listings/ui/photo_enhancement/photo_enhancement.dart';
import 'package:caribtap/listings/ui/photo_enhancement/services/services.dart';
''';

  /// Code snippet to add to the build method's BlocProvider section:
  static const String blocProviderSnippet = '''
  BlocProvider<PhotoEnhancementCubit>(
    create: (context) => PhotoEnhancementCubit(
      enhancementService: PhotoEnhancementService(),
      quotaManager: QuotaManager(),
      userQuotaManager: UserQuotaManager(),
      offlineQueue: OfflineQueueManager(prefs: prefs), // Add SharedPreferences instance
      analytics: EnhancementAnalytics(),
    ),
    child: // ...rest of your widget tree
  ),
''';

  /// Code snippet to add enhance button next to image tiles
  static const String enhanceButtonSnippet = '''
  // Add this NEXT to the photo tiles (after _buildPhotoTile)
  ElevatedButton.icon(
    onPressed: () => _showEnhancementModal(context),
    icon: const Icon(Icons.auto_fix_high),
    label: const Text('Enhance Photos'),
  ),
''';

  /// Method to call when opening enhancement modal
  static const String modalMethodSnippet = '''
  void _showPhotoEnhancementModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PhotoEnhancementBottomSheet(
        listingId: widget.listingToEdit?.id ?? '',
        category: 'product',
        subscriptionTier: currentUser.subscriptionTier ?? 'free',
        userId: currentUser.userID,
      ),
    );
  }
''';
}

/// Constants for integration
class PhotoEnhancementIntegrationConstants {
  // Add these to your listing categories enum
  static const String productCategory = 'product';
  static const String serviceCategory = 'service';
  static const String personCategory = 'person';

  // Add these to your pubspec.yaml if not already present
  static const List<String> requiredDependencies = [
    'cloud_functions: ^4.5.0',
    'firebase_storage: ^11.0.0',
    'connectivity_plus: ^5.0.0',
  ];

  // Add these to your Android Gradle (android/app/build.gradle)
  static const String androidGradleMinSdkNote = 'minSdkVersion 21 required for Cloud Functions';
}

/// Integration checklist
class PhotoEnhancementIntegrationChecklist {
  static final List<String> steps = [
    '1. Add imports for photo_enhancement to add_listing_screen.dart',
    '2. Add PhotoEnhancementCubit to BlocProvider in AddListingWrappingWidget',
    '3. Add "Enhance Photos" button to image gallery section',
    '4. Create _showEnhancementModal() method in state class',
    '5. Update listingModel to include image_variants field',
    '6. Add PhotoEnhancementBottomSheet widget',
    '7. Update Firestore data models to support variants',
    '8. Deploy Cloud Functions (enhancePhoto, saveEnhancementVariant)',
    '9. Update user subscription tier checks',
    '10. Test full workflow: select image -> enhance -> approve -> save',
  ];

  static void printChecklist() {
    print('=== Photo Enhancement Integration Checklist ===');
    for (final step in steps) {
      print('☐ $step');
    }
  }
}
