import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/brand_model.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/services/brand_service.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/screens/brand/brand_locations_screen.dart';
import 'package:instaflutter/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';

/// Widget showing other locations of a brand
class MoreLocationsSection extends StatefulWidget {
  final ListingModel currentListing;
  final String brandId;
  final ListingsUser? currentUser;
  final VoidCallback? onLocationsLoaded;

  const MoreLocationsSection({
    Key? key,
    required this.currentListing,
    required this.brandId,
    this.currentUser,
    this.onLocationsLoaded,
  }) : super(key: key);

  @override
  State<MoreLocationsSection> createState() => _MoreLocationsSectionState();
}

class _MoreLocationsSectionState extends State<MoreLocationsSection> {
  final BrandService _brandService = BrandService();
  late BrandModel? _brand;
  late List<ListingModel> _otherLocations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final brand = await _brandService.getBrand(widget.brandId);
      final locations = await _brandService.getOtherBrandLocations(
        widget.currentListing.id,
        widget.brandId,
      );

      setState(() {
        _brand = brand;
        _otherLocations = locations;
        _isLoading = false;
      });

      widget.onLocationsLoaded?.call();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _otherLocations.isEmpty) {
      return const SizedBox.shrink();
    }

    final dark = isDarkMode(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 20,
                  color: Color(cfg.colorPrimary),
                ),
                const SizedBox(width: 8),
                Text(
                  'More Locations'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                if (_otherLocations.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BrandLocationsScreen(
                            brandId: widget.brandId,
                            brandName: _brand?.name,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'View all'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(cfg.colorPrimary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Locations carousel
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _otherLocations.length > 3 ? 3 : _otherLocations.length,
              itemBuilder: (context, index) {
                final location = _otherLocations[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < (_otherLocations.length > 3 ? 2 : _otherLocations.length - 1) ? 12 : 0,
                  ),
                  child: _buildLocationCard(location, dark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(ListingModel location, bool dark) {
    return GestureDetector(
      onTap: () {
        final user = widget.currentUser ?? context.read<AuthenticationBloc>().state.user;
        if (user == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ListingDetailsWrappingWidget(
              listing: location,
              currentUser: user,
            ),
          ),
        );
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: dark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
        child: Stack(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                child: location.photo.isNotEmpty
                    ? Image.network(
                        location.photo,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.image_not_supported,
                            color: dark ? Colors.grey.shade700 : Colors.grey.shade400,
                          );
                        },
                      )
                    : Icon(
                        Icons.store,
                        color: dark ? Colors.grey.shade700 : Colors.grey.shade400,
                      ),
              ),
            ),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),

            // Text overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      location.locationLabel ?? location.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (location.place.isNotEmpty)
                      Text(
                        location.place,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
