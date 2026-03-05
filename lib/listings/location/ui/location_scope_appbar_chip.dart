// lib/listings/location/ui/location_scope_appbar_chip.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:caribtap/listings/location/location_scope_cubit.dart';
import 'package:caribtap/listings/location/location_scope_model.dart';
import 'package:caribtap/listings/location/ui/location_scope_selector_sheet.dart';
import 'package:caribtap/listings/utils/caribbean_countries.dart';

/// AppBar chip widget that displays current location scope and allows quick toggling
class LocationScopeAppBarChip extends StatelessWidget {
  const LocationScopeAppBarChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationScopeCubit, LocationScopeState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final scope = state.scope;
        final effectiveCountry = state.effectiveCountry;
        
        // Get country name for display
        String displayLabel;
        IconData? iconData;
        if (scope.mode == LocationScopeMode.caribbean) {
          displayLabel = 'Caribbean'.tr();
          iconData = Icons.public;
        } else {
          final countryObj = effectiveCountry != null 
              ? CaribbeanCountries.byCode(effectiveCountry)
              : null;
          displayLabel = countryObj?.name ?? 'Local'.tr();
          iconData = Icons.location_on;
        }

        // Determine opacity based on mode
        final isCaribbean = scope.mode == LocationScopeMode.caribbean;
        final iconOpacity = isCaribbean ? 0.4 : 1.0;

        return GestureDetector(
          onTap: () => _handleTap(context),
          onLongPress: () => _handleLongPress(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Location icon
                Opacity(
                  opacity: iconOpacity,
                  child: Icon(
                    iconData,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                
                // Display label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    // Microcopy hint
                    Text(
                      _getMicrocopy(scope).tr(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(width: 4),
                
                // Dropdown indicator
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getMicrocopy(LocationScope scope) {
    switch (scope.mode) {
      case LocationScopeMode.caribbean:
        return 'Tap to localise';
      case LocationScopeMode.local:
        return 'Tap for Caribbean';
      case LocationScopeMode.nearby:
        return 'Tap to change';
    }
  }

  void _handleTap(BuildContext context) {
    // Quick toggle between Caribbean and Local
    context.read<LocationScopeCubit>().toggleQuick();
  }

  void _handleLongPress(BuildContext context) {
    // Open full selector bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LocationScopeSelectorSheet(),
    );
  }
}
