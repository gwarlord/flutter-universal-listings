import 'package:caribtap/listings/location/location_scope_cubit.dart';
import 'package:caribtap/listings/location/location_scope_model.dart';
import 'package:caribtap/listings/location/ui/location_scope_selector_sheet.dart';
import 'package:caribtap/listings/utils/caribbean_countries.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationScopeFloatingButton extends StatefulWidget {
  const LocationScopeFloatingButton({super.key});

  @override
  State<LocationScopeFloatingButton> createState() => _LocationScopeFloatingButtonState();
}

class _LocationScopeFloatingButtonState extends State<LocationScopeFloatingButton> {
  static const String _keyX = 'location_scope_fab_x';
  static const String _keyY = 'location_scope_fab_y';

  Offset _position = const Offset(20, 200);
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_keyX);
    final y = prefs.getDouble(_keyY);

    setState(() {
      if (x != null && y != null) {
        _position = Offset(x, y);
      }
      _isInitialized = true;
    });
  }

  Future<void> _savePosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyX, _position.dx);
    await prefs.setDouble(_keyY, _position.dy);
  }

  String _countryCodeToFlag(String countryCode) {
    return countryCode
        .toUpperCase()
        .split('')
        .map((char) => String.fromCharCode(0x1F1E6 + char.codeUnitAt(0) - 'A'.codeUnitAt(0)))
        .join();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<LocationScopeCubit, LocationScopeState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const SizedBox.shrink();
        }

        final scope = state.scope;
        final effectiveCountry = state.effectiveCountry;
        final isCaribbean = scope.mode == LocationScopeMode.caribbean;
        final isLocal = scope.mode == LocationScopeMode.local;

        String label;
        IconData? leadingIcon;
        String? flagEmoji;

        if (scope.mode == LocationScopeMode.caribbean) {
          label = 'Caribbean';
          leadingIcon = Icons.public;
        } else if (scope.mode == LocationScopeMode.nearby) {
          label = 'Nearby';
          leadingIcon = Icons.my_location;
        } else {
          final countryObj = effectiveCountry != null
              ? CaribbeanCountries.byCode(effectiveCountry)
              : null;
          label = countryObj?.name ?? 'Local';

          if (effectiveCountry != null && effectiveCountry.length == 2) {
            flagEmoji = _countryCodeToFlag(effectiveCountry);
          } else {
            leadingIcon = Icons.location_on;
          }
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final foregroundColor = (isCaribbean || isLocal)
          ? Colors.white
          : (isDark ? Colors.white : Theme.of(context).colorScheme.onSurface);

        final size = MediaQuery.of(context).size;
        final safePosition = Offset(
          _position.dx.clamp(8.0, (size.width - 88).clamp(8.0, size.width)),
          _position.dy.clamp(16.0, (size.height - 120).clamp(16.0, size.height)),
        );

        if (safePosition != _position) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _position = safePosition;
            });
          });
        }

        return Positioned(
          left: safePosition.dx,
          top: safePosition.dy,
          child: Tooltip(
            message: 'Tap to toggle • Long press for options',
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _position = Offset(
                    (_position.dx + details.delta.dx).clamp(0.0, size.width - 80),
                    (_position.dy + details.delta.dy).clamp(0.0, size.height - 120),
                  );
                });
              },
              onPanEnd: (_) => _savePosition(),
              onTap: () => context.read<LocationScopeCubit>().toggleQuick(),
              onLongPress: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const LocationScopeSelectorSheet(),
                );
              },
              child: Material(
                elevation: 6,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(28),
                shadowColor: Colors.black.withOpacity(0.3),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isLocal
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.65)
                            : Colors.white.withOpacity(0.65),
                        gradient: isCaribbean
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF9C27B0).withOpacity(0.65),
                                  const Color(0xFF673AB7).withOpacity(0.65),
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.40),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (flagEmoji != null)
                            Text(flagEmoji, style: const TextStyle(fontSize: 20))
                          else
                            Icon(
                              leadingIcon,
                              size: 20,
                              color: foregroundColor,
                            ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: foregroundColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.drag_indicator,
                                    size: 14,
                                    color: foregroundColor.withOpacity(0.8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Hold for more',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w500,
                                      color: foregroundColor.withOpacity(0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
