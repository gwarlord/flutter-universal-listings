enum LabelStrategy {
  /// No persistent canvas label — SVG shape only with optional trending dot.
  dot,
  /// Show a slim name label below the island shape.
  name,
}

class RegionAnchor {
  final double x;
  final double y;

  const RegionAnchor({
    required this.x,
    required this.y,
  });
}

class CountryHotspot {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double x;
  final double y;

  const CountryHotspot({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.x,
    required this.y,
  });
}

class CountryMapConfig {
  final String id;
  final String displayName;
  final String isoCode;
  final double centerLat;
  final double centerLng;
  final double defaultMapZoom;
  final List<int> paletteColors;
  final String svgAssetPath;
  final String layoutKey;
  final bool supported;
  final double regionX;
  final double regionY;
  final List<CountryHotspot> hotspots;
  final RegionAnchor? regionPosition;
  final RegionAnchor? labelAnchor;
  final RegionAnchor? labelOffset;
  final RegionAnchor? cardAnchor;
  final RegionAnchor? activityBadgeOffset;
  final double regionScale;
  final LabelStrategy labelStrategy;
  final String? abbreviation;

  const CountryMapConfig({
    required this.id,
    required this.displayName,
    required this.isoCode,
    required this.centerLat,
    required this.centerLng,
    required this.defaultMapZoom,
    required this.paletteColors,
    required this.svgAssetPath,
    required this.layoutKey,
    required this.supported,
    required this.regionX,
    required this.regionY,
    this.hotspots = const [],
    this.regionPosition,
    this.labelAnchor,
    this.labelOffset,
    this.cardAnchor,
    this.activityBadgeOffset,
    this.regionScale = 1.0,
    this.labelStrategy = LabelStrategy.dot,
    this.abbreviation,
  });

  RegionAnchor get effectiveRegionPosition =>
      regionPosition ?? RegionAnchor(x: regionX, y: regionY);

  RegionAnchor get effectiveLabelOffset =>
      labelOffset ?? const RegionAnchor(x: 0, y: 0);

  RegionAnchor get effectiveCardAnchor =>
      cardAnchor ?? effectiveRegionPosition;
}
