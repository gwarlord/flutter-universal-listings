import 'package:flutter/material.dart';
import 'package:caribtap/map_explorer/models/map_explorer_intent.dart';

class SpotlightCategoryChip extends StatelessWidget {
  final MapExplorerIntent intent;
  final bool selected;
  final VoidCallback onTap;

  const SpotlightCategoryChip({
    super.key,
    required this.intent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? scheme.primary : scheme.surface,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline.withOpacity(0.3),
          ),
        ),
        child: Text(
          intent.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
