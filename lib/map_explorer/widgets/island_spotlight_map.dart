import 'package:flutter/material.dart';
import 'package:caribtap/map_explorer/models/country_map_config.dart';

class IslandSpotlightMap extends StatelessWidget {
  final CountryMapConfig country;
  final ValueChanged<CountryHotspot> onHotspotTap;

  const IslandSpotlightMap({
    super.key,
    required this.country,
    required this.onHotspotTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = country.paletteColors.map((hex) => Color(hex)).toList();
    final c1 = colors.isNotEmpty ? colors.first : Theme.of(context).colorScheme.primary;
    final c2 = colors.length > 1 ? colors[1] : Theme.of(context).colorScheme.secondary;
    final c3 = colors.length > 2 ? colors[2] : Colors.white;

    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1.withOpacity(0.9), c2.withOpacity(0.85), c3.withOpacity(0.75)],
        ),
        boxShadow: [
          BoxShadow(
            color: c1.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SpotlightContourPainter(accent: c1.withOpacity(0.36)),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 190,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(70),
                color: Colors.white.withOpacity(0.16),
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.2),
              ),
            ),
          ),
          ...country.hotspots.map(
            (hotspot) => Positioned(
              left: hotspot.x * 260,
              top: hotspot.y * 190,
              child: GestureDetector(
                onTap: () => onHotspotTap(hotspot),
                child: Column(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: c1, width: 2),
                      ),
                      child: Icon(Icons.place, color: c1, size: 12),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hotspot.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightContourPainter extends CustomPainter {
  final Color accent;

  _SpotlightContourPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accent;

    for (int i = 0; i < 5; i++) {
      final inset = 16.0 + (i * 18.0);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
        Radius.circular(30 + i * 8),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightContourPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}
