import 'package:flutter/material.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/map_explorer/models/country_activity_summary.dart';
import 'package:caribtap/map_explorer/models/country_map_config.dart';
import 'package:caribtap/map_explorer/models/map_explorer_entry.dart';
import 'package:caribtap/map_explorer/screens/caribbean_map_screen.dart';
import 'package:caribtap/map_explorer/screens/country_live_map_screen.dart';
import 'package:caribtap/map_explorer/services/country_map_service.dart';

class MapExplorerNavigationService {
  const MapExplorerNavigationService();

  static final CountryMapService _countryMapService = CountryMapService();

  Future<void> openRegionExplorer(
    BuildContext context, {
    required ListingsUser currentUser,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaribbeanMapScreen(currentUser: currentUser),
      ),
    );
  }

  Future<void> openLiveMap(
    BuildContext context, {
    required ListingsUser currentUser,
    required CountryMapConfig country,
    required MapExplorerEntry entry,
  }) {
    return Navigator.of(context).push(_fadeSlideRoute(
      CountryLiveMapScreen(
        currentUser: currentUser,
        country: country,
        entry: entry,
      ),
    ));
  }

  Future<void> openLiveMapWithEntry(
    BuildContext context, {
    required ListingsUser currentUser,
    required MapExplorerEntry entry,
  }) {
    final country = _countryMapService.getCountryById(entry.countryId);
    if (country == null) {
      return Future<void>.value();
    }
    return openLiveMap(
      context,
      currentUser: currentUser,
      country: country,
      entry: entry,
    );
  }

  PageRouteBuilder<void> _fadeSlideRoute(Widget child) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (_, animation, __, page) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final offset = Tween<Offset>(
          begin: const Offset(0.0, 0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: offset, child: page),
        );
      },
    );
  }
}
