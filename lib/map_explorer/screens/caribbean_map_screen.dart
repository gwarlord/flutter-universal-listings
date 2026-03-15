import 'package:flutter/material.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/map_explorer/models/country_activity_summary.dart';
import 'package:caribtap/map_explorer/models/country_map_config.dart';
import 'package:caribtap/map_explorer/models/map_explorer_entry.dart';
import 'package:caribtap/map_explorer/models/map_explorer_intent.dart';
import 'package:caribtap/map_explorer/services/country_activity_service.dart';
import 'package:caribtap/map_explorer/services/country_map_service.dart';
import 'package:caribtap/map_explorer/services/map_explorer_navigation_service.dart';
import 'package:caribtap/map_explorer/widgets/caribbean_region_map.dart';
import 'package:caribtap/map_explorer/widgets/country_selection_card.dart';

/// Layer 1 — Caribbean Region Explorer.
///
/// Tapping an island selects it and slides up a [CountrySelectionCard].
/// The bottom CTA opens the country live map directly.
class CaribbeanMapScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const CaribbeanMapScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<CaribbeanMapScreen> createState() => _CaribbeanMapScreenState();
}

class _CaribbeanMapScreenState extends State<CaribbeanMapScreen> {
  final CountryMapService _countryMapService = CountryMapService();
  final CountryActivityService _countryActivityService = CountryActivityService();
  final MapExplorerNavigationService _navigationService =
      const MapExplorerNavigationService();

  late final List<CountryMapConfig> _countries;
  Map<String, CountryActivitySummary> _activity = const {};
  bool _loading = true;

  CountryMapConfig? _selected;
  String? _selectedMarkerId;

  @override
  void initState() {
    super.initState();
    _countries = _countryMapService.getSupportedCountries();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    final activity = await _countryActivityService.getActivityByCountry(_countries);
    if (!mounted) return;
    setState(() {
      _activity = activity;
      _loading = false;
    });
  }

  void _onIslandTap(CountryMapConfig country) {
    setState(() {
      _selected = _selected?.id == country.id ? null : country;
      _selectedMarkerId = null;
    });
  }

  void _onMarkerTap(CountryMapConfig country) {
    setState(() {
      _selected = country;
      _selectedMarkerId = country.id;
    });
  }

  void _openSpotlight() {
    final country = _selected;
    if (country == null) return;
    _navigationService.openLiveMap(
      context,
      currentUser: widget.currentUser,
      country: country,
      entry: MapExplorerEntry(
        countryId: country.id,
        intent: MapExplorerIntent.all,
        sourceLayer: MapExplorerSourceLayer.regionExplorer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1E2E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Caribbean Explorer',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _selected != null ? 1.0 : 0.0,
            child: TextButton(
              onPressed:
                  _selected != null
                    ? () => setState(() {
                      _selected = null;
                      _selectedMarkerId = null;
                      })
                    : null,
              child: const Text('Deselect',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _selected == null
                    ? 'Tap an island to explore'
                    : 'Exploring ${_selected!.displayName}',
                key: ValueKey(_selected?.id ?? 'idle'),
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white54))
                        : CaribbeanRegionMap(
                            key: const ValueKey('map'),
                            countries: _countries,
                            activity: _activity,
                            selectedCountryId: _selected?.id,
                            selectedMarkerId: _selectedMarkerId,
                            onIslandTap: _onIslandTap,
                            onMarkerTap: _onMarkerTap,
                          ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOutCubic));
                      return SlideTransition(
                          position: slide,
                          child: FadeTransition(
                              opacity: animation, child: child));
                    },
                    child: _selected != null
                        ? CountrySelectionCard(
                            key: ValueKey(_selected!.id),
                            country: _selected!,
                            activity: _activity[_selected!.id],
                            onOpenSpotlight: _openSpotlight,
                            onDismiss: () => setState(() {
                              _selected = null;
                              _selectedMarkerId = null;
                            }),
                          )
                        : const SizedBox.shrink(key: ValueKey('empty')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
