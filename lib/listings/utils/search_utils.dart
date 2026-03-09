import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/event_model.dart';

class SearchUtils {
  /// Builds a comprehensive searchable string from a listing model.
  /// Includes: Title, Description, Place, Category, Price, Contact Info,
  /// Social Media, Services, Digital Menu, Rentals, and Denormalized Keywords.
  static String buildListingSearchString(ListingModel l) {
    final b = StringBuffer();

    // Core Identity & Description
    b.writeln(l.title);
    b.writeln(l.description);
    b.writeln(l.place);
    b.writeln(l.categoryTitle);
    b.writeln(l.price);
    b.writeln(l.openingHours);
    b.writeln(l.locationInstructions ?? '');

    // Contact Information
    b.writeln(l.phone);
    b.writeln(l.email);
    b.writeln(l.website);
    b.writeln(l.authorName);

    // Social Media
    b.writeln(l.instagram);
    b.writeln(l.facebook);
    b.writeln(l.tiktok);
    b.writeln(l.whatsapp);
    b.writeln(l.youtube);
    b.writeln(l.x);

    // Services / Booking Services
    if (l.services.isNotEmpty) {
      for (final s in l.services) {
        b.writeln(s.name);
        b.writeln(s.description);
        b.writeln(s.duration);
        b.writeln(s.price);
      }
    }

    // Digital Menu Items
    if (l.menuEnabled && l.menuSections.isNotEmpty) {
      for (final section in l.menuSections) {
        if (section['title'] != null) b.writeln(section['title']);
        final items = section['items'] as List?;
        if (items != null) {
          for (final item in items) {
            if (item is Map) {
              if (item['name'] != null) b.writeln(item['name']);
              if (item['description'] != null) b.writeln(item['description']);
              final tags = item['tags'] as List?;
              if (tags != null) b.writeln(tags.join(' '));
            }
          }
        }
      }
    }

    // Rental Config (Basic)
    if (l.rentalConfig != null) {
      b.writeln(l.rentalConfig!.termsAndConditions ?? '');
    }

    // ✅ Denormalized Keywords (From Rental/Store Catalogs)
    if (l.searchKeywords.isNotEmpty) {
      b.writeln(l.searchKeywords.join(' '));
    }

    // Filters / Metadata
    if (l.filters.isNotEmpty) {
      l.filters.forEach((k, v) {
        b.writeln(k);
        if (v is String) b.writeln(v);
        if (v is List) b.writeln(v.join(' '));
      });
    }

    return b.toString().toLowerCase();
  }

  /// Builds a searchable string for an event model.
  static String buildEventSearchString(EventModel e) {
    final b = StringBuffer();
    b.writeln(e.title);
    b.writeln(e.description);
    b.writeln(e.venueName);
    b.writeln(e.ticketInstructions);
    b.writeln(e.committee);

    for (final t in e.ticketTypes) {
      b.writeln(t.name);
      b.writeln(t.description);
      b.writeln(t.currency);
    }

    for (final m in e.committeeMembers) {
      b.writeln(m.name);
      b.writeln(m.contactNumber);
    }

    b.writeln(e.facebookUrl);
    b.writeln(e.instagramUrl);

    return b.toString().toLowerCase();
  }

  /// Fuzzy match logic with typo tolerance
  static bool fuzzyMatch(String query, String text) {
    if (query.isEmpty) return true;
    final normalizedQuery = query.trim().toLowerCase();

    if (text.contains(normalizedQuery)) return true;

    // Basic typo tolerance against tokens
    final tokens = text.split(RegExp(r'[\s,.;:!\?\n\r]+'));
    for (final token in tokens) {
      if (token.isEmpty) continue;
      if (levenshtein(token, normalizedQuery) <= 1) return true;
    }
    return false;
  }

  /// Levenshtein distance calculation for typo tolerance
  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = a.length;
    final n = b.length;
    List<int> prev = List<int>.generate(n + 1, (j) => j);
    for (int i = 1; i <= m; i++) {
      List<int> curr = List<int>.filled(n + 1, 0);
      curr[0] = i;
      for (int j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = _min3(
          curr[j - 1] + 1, // insertion
          prev[j] + 1, // deletion
          prev[j - 1] + cost, // substitution
        );
      }
      prev = curr;
    }
    return prev[n];
  }

  static int _min3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);
}
