// lib/listings/location/ui/location_scope_filter_chips.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:caribtap/listings/location/location_scope_cubit.dart';
import 'package:caribtap/listings/location/location_scope_model.dart';
import 'package:caribtap/listings/location/ui/location_scope_selector_sheet.dart';
import 'package:caribtap/listings/utils/caribbean_countries.dart';

/// Displays active filter chips under the AppBar to show current location scope
class LocationScopeFilterChips extends StatelessWidget {
  const LocationScopeFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationScopeCubit, LocationScopeState>(
      builder: (context, state) {
        final scope = state.scope;
        
        // Don't show chips if in Caribbean mode (default/show all)
        if (scope.mode == LocationScopeMode.caribbean) {
          return const SizedBox.shrink();
        }

        final chips = <Widget>[];

        // Show mode chip
        if (scope.mode == LocationScopeMode.local) {
          final countryObj = state.effectiveCountry != null 
              ? CaribbeanCountries.byCode(state.effectiveCountry!)
              : null;
          final countryName = countryObj?.name ?? state.effectiveCountry ?? 'Local';
          
          chips.add(
            Chip(
              avatar: const Icon(Icons.location_on, size: 16),
              label: Text(countryName),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () => _handleClearFilter(context),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              labelStyle: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          );

          // Add "Strict" chip if strict mode is enabled
          if (scope.strictLocalOnly) {
            chips.add(
              Chip(
                avatar: const Icon(Icons.filter_alt, size: 16),
                label: Text('Strict'.tr()),
                backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
            );
          }
        } else if (scope.mode == LocationScopeMode.nearby) {
          chips.add(
            Chip(
              avatar: const Icon(Icons.my_location, size: 16),
              label: Text('Nearby'.tr()),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () => _handleClearFilter(context),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              labelStyle: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          );
        }

        if (chips.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips,
          ),
        );
      },
    );
  }

  void _handleClearFilter(BuildContext context) {
    // Switch to Caribbean mode (show all)
    context.read<LocationScopeCubit>().setMode(LocationScopeMode.caribbean);
  }
}
