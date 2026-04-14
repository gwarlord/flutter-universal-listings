import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/filter_model.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/listings_module/filters/filters_bloc.dart';

class FilterWrappingWidget extends StatelessWidget {
  final Map<String, String>? filtersValue;
  final String? titleText;
  final String? saveButtonText;
  final String? instructionText;
  final bool includeListingDefaults;

  const FilterWrappingWidget({
    super.key,
    this.filtersValue,
    this.titleText,
    this.saveButtonText,
    this.instructionText,
    this.includeListingDefaults = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FiltersBloc(listingsRepository: listingApiManager),
      child: FiltersScreen(
        filtersValue: filtersValue,
        titleText: titleText,
        saveButtonText: saveButtonText,
        instructionText: instructionText,
        includeListingDefaults: includeListingDefaults,
      ),
    );
  }
}

class FiltersScreen extends StatefulWidget {
  final Map<String, String>? filtersValue;
  final String? titleText;
  final String? saveButtonText;
  final String? instructionText;
  final bool includeListingDefaults;

  const FiltersScreen({
    super.key,
    this.filtersValue,
    this.titleText,
    this.saveButtonText,
    this.instructionText,
    this.includeListingDefaults = false,
  });

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  List<FilterModel> _filters = [];
  bool isLoading = true;

  List<FilterModel> _buildEffectiveFilters(List<FilterModel> source) {
    final cloned = source
        .map(
          (f) => FilterModel(
            id: f.id,
            name: f.name,
            options: List<dynamic>.from(f.options),
          ),
        )
        .toList();

    if (!widget.includeListingDefaults) {
      return cloned;
    }

    _mergeFilterOptions(
      cloned,
      'Delivery',
      const ['Same-day delivery'],
    );

    _mergeFilterOptions(
      cloned,
      'Category-Specific Features',
      const [
        'Restaurant: Dine-in',
        'Restaurant: Takeout',
        'Professional Service: Emergency service',
        'Professional Service: Free estimate',
        'Events: Indoor venue',
        'Events: Outdoor venue',
        'Accommodation: Self check-in',
        'Accommodation: Kitchen',
      ],
    );

    return cloned;
  }

  void _mergeFilterOptions(
    List<FilterModel> target,
    String filterName,
    List<String> defaults,
  ) {
    final index = target.indexWhere(
      (f) => f.name.trim().toLowerCase() == filterName.toLowerCase(),
    );

    if (index < 0) {
      target.add(
        FilterModel(
          id: filterName
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
              .replaceAll(RegExp(r'^_|_$'), ''),
          name: filterName,
          options: List<dynamic>.from(defaults),
        ),
      );
      return;
    }

    final existing = target[index];
    final merged = <String>[];
    merged.addAll(existing.options.map((e) => e.toString()));
    for (final opt in defaults) {
      if (!merged.contains(opt)) {
        merged.add(opt);
      }
    }
    existing.options = merged;
  }

  @override
  void initState() {
    super.initState();
    context.read<FiltersBloc>().add(GetFiltersEvent());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = isDarkMode(context);
    final backgroundColor =
        isDark ? Colors.grey[900] : theme.scaffoldBackgroundColor;

    return DraggableScrollableSheet(
      expand: false,
      maxChildSize: .9,
      initialChildSize: .9,
      minChildSize: .2,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle for DraggableScrollableSheet
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.titleText ?? 'Filters'.tr(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close'.tr(),
                        style: TextStyle(color: Color(colorPrimary))),
                  ),
                ],
              ),
            ),
            Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.instructionText ??
                          'Only select filters that apply to your listing.'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocConsumer<FiltersBloc, FiltersState>(
                listener: (context, state) {
                  if (state is FiltersReadyState) {
                    setState(() {
                      isLoading = false;
                      _filters = _buildEffectiveFilters(state.filters);
                    });
                  }
                },
                builder: (context, state) {
                  if (isLoading) {
                    return const Center(
                        child: CircularProgressIndicator.adaptive());
                  }
                  if (_filters.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: showEmptyState(
                        'No filters found.'.tr(),
                        'All filters will show up here once added by the admin.'
                            .tr(),
                      ),
                    );
                  } else {
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: _filters.length,
                      padding: const EdgeInsets.only(bottom: 100),
                      itemBuilder: (context, index) => FilterTileWidget(
                        filter: _filters[index],
                        filtersValue: widget.filtersValue,
                      ),
                    );
                  }
                },
              ),
            ),
            // Bottom Action Bar
            Container(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                24 + MediaQuery.of(context).viewPadding.bottom + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(colorPrimary),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  widget.saveButtonText ?? 'Save Filters'.tr(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.pop(context, widget.filtersValue);
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class FilterTileWidget extends StatefulWidget {
  final FilterModel filter;
  final Map<String, String>? filtersValue;

  const FilterTileWidget({super.key, required this.filter, this.filtersValue});

  @override
  State<FilterTileWidget> createState() => _FilterTileWidgetState();
}

class _FilterTileWidgetState extends State<FilterTileWidget> {
  late FilterModel filter;

  String _getExamplesForOption(String option) {
    // Mapping of options to their specific examples
    final Map<String, String> examples = {
      // Categories
      'Professional Service': 'Plumber, Electrician, Hair Stylist, Barber, Consultant',
      'Food & Drink': 'Restaurants, Cafes, Bars, Bakeries',
      'Shopping': 'Boutiques, Supermarkets, Electronics, Malls',
      'Health & Beauty': 'Gyms, Spas, Salons, Pharmacies',
      'Entertainment': 'Cinemas, Theme Parks, Museums, Nightclubs',
      'Accommodation': 'Hotels, Villas, Apartments, Guesthouses',
      'Automotive': 'Mechanics, Car Rentals, Car Wash, Dealerships',
      'Home & Garden': 'Hardware Stores, Florists, Interior Design, Furniture',
      'Services': 'Laundry, Tailoring, Delivery, Photography',
      'Education': 'Schools, Tutors, Training Centers, Libraries',
      'Real Estate': 'Agencies, Property Management, Appraisers',
      'Construction': 'Contractors, Architects, Material Suppliers',
      
      // Amenities/Features
      'WiFi': 'Free high-speed internet for customers',
      'Parking': 'Available street parking, private lot, or garage',
      'Outdoor Seating': 'Patio, garden, or sidewalk tables',
      'Delivery': 'Door-to-door delivery or courier services',
      'Takeout': 'Order online or by phone for pickup',
      'Reservations': 'Advance booking for tables or appointments',
      'Wheelchair Accessible': 'Ramps, wide doors, and accessible restrooms',
      'Pet Friendly': 'Dogs or other pets allowed on premises',
      'Accepts Cards': 'Visa, Mastercard, or mobile payments accepted',
      'Air Conditioned': 'Cool and comfortable indoor environment',
      'Smoking Area': 'Designated space for smokers',
      
      // Price Range
      'Inexpensive': 'Budget-friendly options (e.g., Fast food, Street food)',
      'Moderate': 'Mid-range prices (e.g., Casual dining, Local stores)',
      'Expensive': 'Premium or upscale pricing (e.g., Fine dining, Luxury brands)',
      'Very Expensive': 'Exclusive or ultra-high-end pricing',
    };

    return examples[option] ?? '';
  }

  void _showInfoDialog(String option) {
    final isDark = isDarkMode(context);
    final String examples = _getExamplesForOption(option);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Color(colorPrimary)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.tr(),
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This filter indicates if the listing matches the criteria for ${option.toLowerCase().tr()}.'
                  .tr(),
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 15),
            ),
            if (examples.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Examples / Details:'.tr(),
                style: TextStyle(
                  color: Color(colorPrimary),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                examples.tr(),
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'.tr(),
                style: TextStyle(
                    color: Color(colorPrimary), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    filter = widget.filter;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = isDarkMode(context);
    final selected = (widget.filtersValue?[filter.name]?.split(',') ?? [])
        .where((e) => e.trim().isNotEmpty)
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            filter.name.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Color(colorPrimary),
            ),
          ),
        ),
        ...filter.options.map<Widget>((option) {
          final optionStr = option.toString();
          final isSelected = selected.contains(optionStr);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: InkWell(
              onTap: () {
                setState(() {
                  final newSelected = Set<String>.from(selected);
                  if (!isSelected) {
                    newSelected.add(optionStr);
                  } else {
                    newSelected.remove(optionStr);
                  }
                  widget.filtersValue?[filter.name] = newSelected.join(',');
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected
                      ? Color(colorPrimary).withOpacity(isDark ? 0.25 : 0.05)
                      : isDark
                          ? Colors.grey[850]!.withOpacity(0.5)
                          : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      activeColor: Color(colorPrimary),
                      checkColor: Colors.white,
                      side: BorderSide(
                          color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (checked) {
                        setState(() {
                          final newSelected = Set<String>.from(selected);
                          if (checked == true) {
                            newSelected.add(optionStr);
                          } else {
                            newSelected.remove(optionStr);
                          }
                          widget.filtersValue?[filter.name] =
                              newSelected.join(',');
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        optionStr.tr(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? Color(colorPrimary)
                              : isDark
                                  ? Colors.white
                                  : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.info_outline,
                        size: 20,
                        color: isDark
                            ? Colors.white38
                            : theme.hintColor.withOpacity(0.5),
                      ),
                      onPressed: () => _showInfoDialog(optionStr),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 8),
        Divider(
            indent: 20,
            endIndent: 20,
            color: isDark ? Colors.grey[800] : Colors.grey[200]),
      ],
    );
  }
}
