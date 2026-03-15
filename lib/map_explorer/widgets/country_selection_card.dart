import 'package:flutter/material.dart';
import 'package:caribtap/map_explorer/models/country_activity_summary.dart';
import 'package:caribtap/map_explorer/models/country_map_config.dart';

/// Slide-up bottom card that appears when the user selects a country in the
/// region explorer. Shows key stats and a CTA to open the Island Spotlight.
class CountrySelectionCard extends StatelessWidget {
  final CountryMapConfig country;
  final CountryActivitySummary? activity;
  final VoidCallback onOpenSpotlight;
  final VoidCallback onDismiss;

  const CountrySelectionCard({
    super.key,
    required this.country,
    required this.activity,
    required this.onOpenSpotlight,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final palette = country.paletteColors.map((hex) => Color(hex)).toList();
    final accent = palette.isNotEmpty ? palette.first : const Color(0xFF2E8BC0);
    final accent2 = palette.length > 1 ? palette[1] : accent;

    final listings = activity?.listingsCount ?? 0;
    final deals = activity?.dealsCount ?? 0;
    final rentals = activity?.rentalsCount ?? 0;
    final hasTrending = activity?.hasTrending ?? false;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        color: const Color(0xFF0E1D2C),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.22),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Palette gradient accent bar
          Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              gradient: LinearGradient(colors: [accent, accent2]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        country.displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (hasTrending)
                      Container(
                        margin: const EdgeInsets.only(top: 2, right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE85009).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFFF7832).withOpacity(0.5)),
                        ),
                        child: const Text(
                          'Trending',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF9048),
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: onDismiss,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 15, color: Colors.white54),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stats chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (listings > 0)
                      _StatChip(
                          icon: Icons.storefront_outlined,
                          label: '$listings listings',
                          color: accent),
                    if (deals > 0)
                      _StatChip(
                          icon: Icons.local_offer_outlined,
                          label: '$deals deals',
                          color: const Color(0xFF27AE60)),
                    if (rentals > 0)
                      _StatChip(
                          icon: Icons.apartment_outlined,
                          label: '$rentals rentals',
                          color: const Color(0xFF8E44AD)),
                    if (listings == 0 && deals == 0 && rentals == 0)
                      _StatChip(
                          icon: Icons.explore_outlined,
                          label: 'Ready to explore',
                          color: accent),
                  ],
                ),
                const SizedBox(height: 16),

                // CTA
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: onOpenSpotlight,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.travel_explore, size: 18),
                    label: const Text(
                      'Open Island Spotlight',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
