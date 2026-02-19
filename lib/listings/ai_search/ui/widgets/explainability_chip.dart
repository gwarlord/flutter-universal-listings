import 'package:flutter/material.dart';
import 'package:caribtap/listings/ai_search/models/search_result.dart';

/// Widget for displaying explainability chips
class ExplainabilityChipWidget extends StatelessWidget {
  final ExplainabilityChip chip;
  final VoidCallback? onTap;

  const ExplainabilityChipWidget({
    Key? key,
    required this.chip,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: chip.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: chip.color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              chip.icon,
              size: 14,
              color: chip.color,
            ),
            const SizedBox(width: 4),
            Text(
              chip.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: chip.color.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Group of filter chips
class FilterChipGroup extends StatelessWidget {
  final List<String> selectedFilters;
  final List<String> availableFilters;
  final Function(String) onFilterToggle;

  const FilterChipGroup({
    Key? key,
    required this.selectedFilters,
    required this.availableFilters,
    required this.onFilterToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableFilters.map((filter) {
        final isSelected = selectedFilters.contains(filter);
        return FilterChip(
          label: Text(filter),
          selected: isSelected,
          onSelected: (selected) => onFilterToggle(filter),
          checkmarkColor: Colors.white,
        );
      }).toList(),
    );
  }
}
