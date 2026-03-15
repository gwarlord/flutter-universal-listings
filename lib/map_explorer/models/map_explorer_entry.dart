import 'package:caribtap/map_explorer/models/map_explorer_intent.dart';

enum MapExplorerSourceLayer {
  regionExplorer,
  islandSpotlight,
  liveMap,
}

class MapExplorerEntry {
  final String countryId;
  final String? hotspotId;
  final MapExplorerIntent? intent;
  final MapExplorerSourceLayer sourceLayer;

  const MapExplorerEntry({
    required this.countryId,
    this.hotspotId,
    this.intent,
    required this.sourceLayer,
  });
}
