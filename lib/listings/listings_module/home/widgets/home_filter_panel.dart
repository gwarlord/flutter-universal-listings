import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/listings/model/home_filter_state.dart';
import 'package:caribtap/listings/model/categories_model.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/core/utils/helper.dart';

/// Filter panel/bottom sheet for Home screen
class HomeFilterPanel extends StatefulWidget {
  final HomeFilterState currentFilters;
  final List<CategoriesModel> categories;
  final Function(HomeFilterState) onApply;
  final VoidCallback onClear;

  const HomeFilterPanel({
    Key? key,
    required this.currentFilters,
    required this.categories,
    required this.onApply,
    required this.onClear,
  }) : super(key: key);

  @override
  State<HomeFilterPanel> createState() => _HomeFilterPanelState();
}

class _HomeFilterPanelState extends State<HomeFilterPanel> {
  late HomeFilterState _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.currentFilters;
  }

  void _updateFilter(HomeFilterState newFilters) {
    setState(() {
      _filters = newFilters;
    });
  }

  void _showCategorySelector(bool isDark, Color primaryColor) {
    final searchController = TextEditingController();
    var tempSelected = List<String>.from(_filters.categoryIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.trim().toLowerCase();
            final filteredCategories = query.isEmpty
                ? widget.categories
                : widget.categories
                    .where((c) => c.title.toLowerCase().contains(query))
                    .toList();

            return SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Category'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempSelected = [];
                            });
                          },
                          child: Text(
                            'Clear All'.tr(),
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setModalState(() {}),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Search categories...'.tr(),
                        hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        filled: true,
                        fillColor: isDark ? Colors.black : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredCategories.length,
                        itemBuilder: (context, index) {
                          final category = filteredCategories[index];
                          final selected = tempSelected.contains(category.id);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (checked) {
                              setModalState(() {
                                if (checked == true) {
                                  tempSelected.add(category.id);
                                } else {
                                  tempSelected.remove(category.id);
                                }
                              });
                            },
                            activeColor: primaryColor,
                            checkColor: Colors.white,
                            side: BorderSide(
                              color: isDark ? Colors.white : Colors.black54,
                              width: 1.5,
                            ),
                            title: Text(
                              category.title,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            ),
                            controlAffinity: ListTileControlAffinity.trailing,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          _updateFilter(_filters.copyWith(categoryIds: tempSelected));
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Apply Filters'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final primaryColor = Color(cfg.colorPrimary);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Filters'.tr(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    widget.onClear();
                    setState(() {
                      _filters = const HomeFilterState();
                    });
                  },
                  child: Text(
                    'Clear All'.tr(),
                    style: TextStyle(color: primaryColor),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: isDark ? Colors.white : Colors.black,
                ),
              ],
            ),
          ),

          // Scrollable filter options
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Open Now
                  _buildSwitchTile(
                    title: 'Open Now'.tr(),
                    subtitle: 'Show only businesses currently open'.tr(),
                    value: _filters.openNowOnly,
                    onChanged: (val) => _updateFilter(_filters.copyWith(openNowOnly: val)),
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 8),

                  // Mini Store
                  _buildSwitchTile(
                    title: 'Has Mini Store'.tr(),
                    subtitle: 'Buy products directly'.tr(),
                    value: _filters.hasMiniStore,
                    onChanged: (val) => _updateFilter(_filters.copyWith(hasMiniStore: val)),
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 8),

                  // Rentals
                  _buildSwitchTile(
                    title: 'Has Rentals'.tr(),
                    subtitle: 'Rent equipment or vehicles'.tr(),
                    value: _filters.hasRentals,
                    onChanged: (val) => _updateFilter(_filters.copyWith(hasRentals: val)),
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 8),

                  // Bookings
                  _buildSwitchTile(
                    title: 'Has Booking'.tr(),
                    subtitle: 'Book appointments or reservations'.tr(),
                    value: _filters.hasBooking,
                    onChanged: (val) => _updateFilter(_filters.copyWith(hasBooking: val)),
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 8),

                  // Deals
                  _buildSwitchTile(
                    title: 'Has Deals'.tr(),
                    subtitle: 'Special offers available'.tr(),
                    value: _filters.hasDeals,
                    onChanged: (val) => _updateFilter(_filters.copyWith(hasDeals: val)),
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 8),

                  _buildSwitchTile(
                    title: 'Events'.tr(),
                    subtitle: 'Show events in discovery feed'.tr(),
                    value: _filters.includeEvents,
                    onChanged: (val) => _updateFilter(_filters.copyWith(includeEvents: val)),
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 16),

                  // Fulfillment options
                  Text(
                    'Fulfillment Options'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),

                  _buildSwitchTile(
                    title: 'Delivery'.tr(),
                    subtitle: 'Delivers to your address'.tr(),
                    value: _filters.supportsDelivery,
                    onChanged: (val) => _updateFilter(_filters.copyWith(supportsDelivery: val)),
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 8),

                  _buildSwitchTile(
                    title: 'Pickup'.tr(),
                    subtitle: 'Pick up at location'.tr(),
                    value: _filters.supportsPickup,
                    onChanged: (val) => _updateFilter(_filters.copyWith(supportsPickup: val)),
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 8),

                  _buildSwitchTile(
                    title: 'Dine-in'.tr(),
                    subtitle: 'Eat at the restaurant'.tr(),
                    value: _filters.supportsDineIn,
                    onChanged: (val) => _updateFilter(_filters.copyWith(supportsDineIn: val)),
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),

                  // Category filter
                  if (widget.categories.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Category'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCategorySelector(isDark, primaryColor),
                  ],
                ],
              ),
            ),
          ),

          // Apply button
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_filters);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Apply Filters'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? primaryColor.withOpacity(0.3) : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: primaryColor,
            inactiveThumbColor: isDark ? Colors.grey.shade300 : Colors.white,
            inactiveTrackColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(bool isDark, Color primaryColor) {
    final selectedCount = _filters.categoryIds.length;
    final label = selectedCount == 0
        ? 'All Categories'.tr()
        : '$selectedCount ${'Category'.tr()}';

    return GestureDetector(
      onTap: () => _showCategorySelector(isDark, primaryColor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.tune, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}
