import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:share_plus/share_plus.dart';

/// Service for creating and sharing deep links to listings
/// 
/// Deep link format: https://caribtap.com/l/<listingId>
/// When opened:
/// - If app installed → opens listing detail screen
/// - If not installed → redirects to app store or landing page
class DeepLinkService {
  // Custom scheme - works immediately without server setup
  static const String _customScheme = 'caribtap';
  static const String _listingHost = 'listing';
  static const String _listingManageHost = 'listing_manage';
  
  // Web domain (requires server-side configuration with assetlinks.json and apple-app-site-association)
  static const String _baseDomain = 'caribtap.com';
  static const String _listingPathPrefix = '/l/';
  
  /// Creates a shareable deep link for a listing
  /// 
  /// Returns a URL in the format: caribtap://listing/<listingId>
  /// This format works immediately without any server configuration
  Future<String> createListingShareLink(String listingId, {
    String? title,
    String? description,
    String? imageUrl,
  }) async {
    // Use custom scheme for immediate support (no server setup needed)
    final deepLinkUrl = '$_customScheme://$_listingHost/$listingId';
    
    // Alternative web-based format (requires server configuration):
    // final deepLinkUrl = 'https://$_baseDomain$_listingPathPrefix$listingId';
    
    // For production, you might want to use Firebase Dynamic Links
    // or a URL shortener service here
    // Example: final shortLink = await _createFirebaseDynamicLink(listingId, title, description, imageUrl);
    
    return deepLinkUrl;
  }
  
  /// Share a listing via the OS share sheet
  /// 
  /// [listing] - The listing to share
  /// [sharePositionOrigin] - Optional position for iPad share popover
  Future<void> shareListing(
    ListingModel listing, {
    Rect? sharePositionOrigin,
  }) async {
    try {
      // Create the deep link
      final shareLink = await createListingShareLink(
        listing.id,
        title: listing.title,
        description: listing.description,
        imageUrl: listing.photo,
      );
      
      // Create the share message
      final shareMessage = _buildShareMessage(listing, shareLink);
      
      // Share using the platform share sheet
      final result = await Share.share(
        shareMessage,
        subject: 'Check out ${listing.title} on CaribTap',
        sharePositionOrigin: sharePositionOrigin,
      );
      
      // Log share result (optional)
      if (result.status == ShareResultStatus.success) {
        print('✅ Listing shared successfully: ${listing.id}');
        // Optionally track analytics here
        await _trackShareEvent(listing.id, 'success');
      } else if (result.status == ShareResultStatus.dismissed) {
        print('ℹ️ Share dismissed by user');
      }
    } catch (e) {
      print('❌ Error sharing listing: $e');
      // Optionally show error to user
      rethrow;
    }
  }
  
  /// Share a listing with custom text
  Future<void> shareListingWithText(
    String listingId,
    String customMessage, {
    Rect? sharePositionOrigin,
  }) async {
    try {
      final shareLink = await createListingShareLink(listingId);
      final fullMessage = '$customMessage\n\n$shareLink';
      
      await Share.share(
        fullMessage,
        subject: 'Check this out on CaribTap',
        sharePositionOrigin: sharePositionOrigin,
      );
      
      await _trackShareEvent(listingId, 'success');
    } catch (e) {
      print('❌ Error sharing listing: $e');
      rethrow;
    }
  }
  
  /// Build the share message for a listing
  String _buildShareMessage(ListingModel listing, String shareLink) {
    final buffer = StringBuffer();
    
    // Title line
    buffer.writeln('Check this out on CaribTap! 🌴');
    buffer.writeln();
    
    // Listing title
    buffer.writeln(listing.title);
    
    // Location if available
    if (listing.place.isNotEmpty) {
      buffer.writeln('📍 ${listing.place}');
    }
    
    // Price if available
    if (listing.price.isNotEmpty && listing.price != '0') {
      buffer.writeln('💰 ${listing.currencyCode} ${listing.price}');
    }
    
    buffer.writeln();
    
    // Deep link
    buffer.writeln(shareLink);
    buffer.writeln();
    
    // Call to action
    buffer.writeln('Download CaribTap to view this listing and discover more!');
    
    return buffer.toString();
  }
  
  /// Parse a deep link URL and extract the listing ID
  /// 
  /// Returns the listing ID if the URL is a valid listing deep link, null otherwise
  static String? parseListingIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Check if this is a listing deep link
      // Format: https://caribtap.com/l/<listingId>
      if (uri.host.contains(_baseDomain) && 
          uri.path.startsWith(_listingPathPrefix)) {
        final listingId = uri.path.substring(_listingPathPrefix.length);
        
        // Remove any trailing slashes or query parameters
        final cleanId = listingId.split('?').first.split('/').first;
        
        return cleanId.isNotEmpty ? cleanId : null;
      }
      
      // Check for custom scheme (optional fallback)
      // Format: caribtap://listing/<listingId>
      if (uri.scheme == 'caribtap' && uri.host == 'listing') {
        final listingId = uri.pathSegments.isNotEmpty 
            ? uri.pathSegments.first 
            : null;
        return listingId;
      }
      
      return null;
    } catch (e) {
      print('❌ Error parsing deep link: $e');
      return null;
    }
  }
  
  /// Validate if a URL is a listing deep link
  static bool isListingDeepLink(String url) {
    return parseListingIdFromUrl(url) != null;
  }

  /// Parse a deep link URL and extract the listing ID for management links
  ///
  /// Format: caribtap://listing_manage?listingId=<listingId>
  static String? parseListingManageIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme == _customScheme && uri.host == _listingManageHost) {
        final listingId = uri.queryParameters['listingId'] ??
            (uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null);
        return listingId?.isNotEmpty == true ? listingId : null;
      }
      return null;
    } catch (e) {
      print('❌ Error parsing listing manage link: $e');
      return null;
    }
  }

  static bool isListingManageDeepLink(String url) {
    return parseListingManageIdFromUrl(url) != null;
  }
  
  /// Get a listing by ID from Firestore
  /// 
  /// Returns the listing if found, null otherwise
  Future<ListingModel?> getListingById(String listingId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(listingId)
          .get();
      
      if (doc.exists && doc.data() != null) {
        return ListingModel.fromJson(doc.data()!);
      }
      
      return null;
    } catch (e) {
      print('❌ Error fetching listing by ID: $e');
      return null;
    }
  }
  
  /// Track share events (optional - for analytics)
  Future<void> _trackShareEvent(String listingId, String status) async {
    try {
      // Track in Firestore or your analytics service
      await FirebaseFirestore.instance
          .collection('analytics')
          .doc('shares')
          .collection('events')
          .add({
        'listingId': listingId,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'mobile',
      });
    } catch (e) {
      // Fail silently - analytics shouldn't break the app
      print('⚠️ Error tracking share event: $e');
    }
  }
  
  // Optional: Firebase Dynamic Links implementation
  // Uncomment and configure if you want to use Firebase Dynamic Links
  /*
  Future<String> _createFirebaseDynamicLink(
    String listingId,
    String? title,
    String? description,
    String? imageUrl,
  ) async {
    try {
      final DynamicLinkParameters parameters = DynamicLinkParameters(
        uriPrefix: 'https://caribtap.page.link',
        link: Uri.parse('https://$_baseDomain$_listingPathPrefix$listingId'),
        androidParameters: AndroidParameters(
          packageName: 'com.caribtap.instaflutter.android',
          minimumVersion: 1,
          fallbackUrl: Uri.parse('https://play.google.com/store/apps/details?id=com.caribtap.instaflutter.android'),
        ),
        iosParameters: IOSParameters(
          bundleId: 'com.caribtap.instaflutter.ios',
          minimumVersion: '1.0.0',
          appStoreId: 'YOUR_APP_STORE_ID',
          fallbackUrl: Uri.parse('https://apps.apple.com/app/idYOUR_APP_STORE_ID'),
        ),
        socialMetaTagParameters: SocialMetaTagParameters(
          title: title ?? 'Check this out on CaribTap',
          description: description,
          imageUrl: imageUrl != null ? Uri.parse(imageUrl) : null,
        ),
      );
      
      final ShortDynamicLink shortLink = await FirebaseDynamicLinks.instance
          .buildShortLink(parameters);
      
      return shortLink.shortUrl.toString();
    } catch (e) {
      print('❌ Error creating Firebase Dynamic Link: $e');
      // Fallback to basic deep link
      return 'https://$_baseDomain$_listingPathPrefix$listingId';
    }
  }
  */
}
