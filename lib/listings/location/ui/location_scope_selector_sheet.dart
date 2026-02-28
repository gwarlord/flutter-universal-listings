// lib/listings/location/ui/location_scope_selector_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:caribtap/listings/location/location_scope_cubit.dart';
import 'package:caribtap/listings/location/location_scope_model.dart';
import 'package:caribtap/listings/ai_search/ui/screens/ai_search_screen.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/utils/caribbean_countries.dart';

/// Bottom sheet for selecting location scope mode and settings
class LocationScopeSelectorSheet extends StatefulWidget {
  const LocationScopeSelectorSheet({super.key});

  @override
  State<LocationScopeSelectorSheet> createState() => _LocationScopeSelectorSheetState();
}

class _LocationScopeSelectorSheetState extends State<LocationScopeSelectorSheet> {
  late LocationScopeMode _selectedMode;
  late String? _selectedCountry;
  late bool _strictLocalOnly;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<LocationScopeCubit>();
    _selectedMode = cubit.state.scope.mode;
    _selectedCountry = cubit.state.scope.selectedCountry ?? cubit.state.scope.homeCountry;
    _strictLocalOnly = cubit.state.scope.strictLocalOnly;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark 
        ? const Color(0xFF1E1E1E) 
        : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Location Scope'.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Choose what content you want to see'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: subtextColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildAiSearchEntry(),
              const SizedBox(height: 24),

              // Mode selector
              _buildModeSelector(),
              const SizedBox(height: 20),

              // Country picker (only for Local mode)
              if (_selectedMode == LocationScopeMode.local) ...[
                _buildCountryPicker(),
                const SizedBox(height: 20),
                
                // Strict local only toggle
                _buildStrictToggle(),
                const SizedBox(height: 20),
              ],

              // Nearby mode info
              if (_selectedMode == LocationScopeMode.nearby) ...[
                _buildNearbyInfo(),
                const SizedBox(height: 20),
              ],

              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mode'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        
        // Local mode
        _buildModeOption(
          mode: LocationScopeMode.local,
          icon: Icons.location_on,
          title: 'Local',
          description: 'Show content from a specific country',
        ),
        const SizedBox(height: 8),
        
        // Caribbean mode
        _buildModeOption(
          mode: LocationScopeMode.caribbean,
          icon: Icons.public,
          title: 'Caribbean',
          description: 'Show content from all Caribbean countries',
        ),
        const SizedBox(height: 8),
        
        // Nearby mode
        _buildModeOption(
          mode: LocationScopeMode.nearby,
          icon: Icons.my_location,
          title: 'Nearby',
          description: 'Show content based on your GPS location',
        ),
      ],
    );
  }

  Widget _buildAiSearchEntry() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: _openAiSearch,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white24 : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15),
        ),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search with AI'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _openAiSearch() {
    final userId = context.read<AuthenticationBloc>().user?.userID;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open AI Search right now'.tr())),
      );
      return;
    }

    Navigator.of(context).pop();
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => AiSearchScreen(userId: userId),
      ),
    );
  }

  Widget _buildModeOption({
    required LocationScopeMode mode,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isSelected = _selectedMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;
    
    return InkWell(
      onTap: () => setState(() => _selectedMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : (isDark ? Colors.white24 : Theme.of(context).colorScheme.outline.withOpacity(0.3)),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected 
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : textColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : textColor,
                    ),
                  ),
                  Text(
                    description.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryPicker() {
    final homeCountry = context.read<LocationScopeCubit>().state.scope.homeCountry;
    final selectedCountryObj = _selectedCountry != null 
        ? CaribbeanCountries.byCode(_selectedCountry!)
        : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Country'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (homeCountry != null && _selectedCountry != homeCountry)
              TextButton.icon(
                onPressed: () {
                  setState(() => _selectedCountry = homeCountry);
                },
                icon: const Icon(Icons.home, size: 16),
                label: Text('Use Home Country'.tr()),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showCountryPicker(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.white24 : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedCountryObj?.name ?? 'Select Country'.tr(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: textColor,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: textColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStrictToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.1)
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Strict Local Only'.tr(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _strictLocalOnly 
                          ? 'Only show content from selected country'.tr()
                          : 'Show local content first, then other islands'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _strictLocalOnly,
                onChanged: (value) => setState(() => _strictLocalOnly = value),
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return colorScheme.onPrimary;
                  }
                  return isDark ? Colors.white70 : Colors.white;
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return colorScheme.primary;
                  }
                  return isDark ? Colors.white24 : Colors.black12;
                }),
                trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return colorScheme.primary.withOpacity(0.8);
                  }
                  return isDark ? Colors.white38 : Colors.black26;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyInfo() {
    final hasPermission = context.watch<LocationScopeCubit>().state.hasLocationPermission;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.1)
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            hasPermission ? Icons.check_circle : Icons.info,
            color: hasPermission 
                ? Colors.green
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasPermission 
                  ? 'Location permission granted. Content will be filtered based on your GPS location.'.tr()
                  : 'Location permission required. You will be prompted when you save.'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'.tr()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: () => _handleSave(),
            child: Text('Apply'.tr()),
          ),
        ),
      ],
    );
  }

  void _showCountryPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CountryPickerSheetContent(
        backgroundColor: backgroundColor,
        textColor: textColor,
        selectedCountry: _selectedCountry,
        onCountrySelected: (code) {
          setState(() => _selectedCountry = code);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _CountryPickerSheetContent({
    required Color backgroundColor,
    required Color textColor,
    required String? selectedCountry,
    required Function(String) onCountrySelected,
  }) {
    final searchController = TextEditingController();
    
    return StatefulBuilder(
      builder: (context, setState) {
        final filteredCountries = searchController.text.isEmpty
            ? CaribbeanCountries.all.toList()
            : CaribbeanCountries.all.where((country) {
                return country.name.toLowerCase().contains(searchController.text.toLowerCase());
              }).toList();

        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Text(
                'Select Country'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search countries...'.tr(),
                  hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.search, color: textColor.withOpacity(0.6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredCountries.length,
                  itemBuilder: (context, index) {
                    final country = filteredCountries[index];
                    final isSelected = selectedCountry == country.code;
                    return ListTile(
                      title: Text(
                        country.name,
                        style: TextStyle(color: textColor),
                      ),
                      trailing: isSelected 
                          ? const Icon(Icons.check_circle)
                          : null,
                      selected: isSelected,
                      onTap: () {
                        onCountrySelected(country.code);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSave() async {
    final cubit = context.read<LocationScopeCubit>();

    // If nearby mode and no permission, request it
    if (_selectedMode == LocationScopeMode.nearby && !cubit.state.hasLocationPermission) {
      await cubit.requestLocationPermissionAndInfer();
      // If permission still denied after request, don't apply nearby mode
      if (!cubit.state.hasLocationPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location permission is required for Nearby mode'.tr()),
              action: SnackBarAction(
                label: 'OK'.tr(),
                onPressed: () {},
              ),
            ),
          );
        }
        return;
      }
    }

    // Apply settings
    await cubit.setMode(_selectedMode);
    if (_selectedMode == LocationScopeMode.local && _selectedCountry != null) {
      await cubit.setCountry(_selectedCountry);
    }
    await cubit.setStrictLocalOnly(_strictLocalOnly);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
