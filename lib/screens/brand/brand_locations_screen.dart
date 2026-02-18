import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/brand_model.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/brand_service.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';

/// Screen displaying all locations of a brand
class BrandLocationsScreen extends StatefulWidget {
  final String brandId;
  final String? brandName; // Optional, will fetch if not provided
  final ListingsUser? currentUser;

  const BrandLocationsScreen({
    Key? key,
    required this.brandId,
    this.brandName,
    this.currentUser,
  }) : super(key: key);

  @override
  State<BrandLocationsScreen> createState() => _BrandLocationsScreenState();
}

class _BrandLocationsScreenState extends State<BrandLocationsScreen> {
  final BrandService _brandService = BrandService();
  BrandModel? _brand;
  List<ListingModel> _locations = [];
  bool _isLoading = true;
  String _sortBy = 'nearest'; // 'nearest', 'name', 'newest'

  @override
  void initState() {
    super.initState();
    _loadBrandData();
  }

  Future<void> _loadBrandData() async {
    try {
      final brand = await _brandService.getBrand(widget.brandId);
      final locations = await _brandService.getBrandLocations(widget.brandId);

      setState(() {
        _brand = brand;
        _locations = locations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(context, 'Failed to load brand locations: $e');
      }
    }
  }

  void _sortLocations() {
    switch (_sortBy) {
      case 'name':
        _locations.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'newest':
        _locations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'nearest':
      default:
        // Sort by nearest (would need user location)
        break;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          _brand?.name ?? widget.brandName ?? 'Locations'.tr(),
          style: TextStyle(
            color: dark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: dark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _locations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        size: 64,
                        color: dark ? Colors.grey.shade700 : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No locations found'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          color: dark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Brand header
                    if (_brand != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: dark ? Colors.grey.shade900 : Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Brand logo and name
                            Row(
                              children: [
                                if (_brand!.logoUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _brand!.logoUrl!,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: Color(cfg.colorPrimary).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.store,
                                            color: Color(cfg.colorPrimary),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                else
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Color(cfg.colorPrimary).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.store,
                                      color: Color(cfg.colorPrimary),
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _brand!.name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: dark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      if (_brand!.description != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _brand!.description!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: dark ? Colors.white70 : Colors.black54,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      if (_brand!.isVerified) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.verified,
                                              size: 14,
                                              color: Color(cfg.colorPrimary),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Verified Brand'.tr(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(cfg.colorPrimary),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],

                    // Sort options
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Text(
                            '${_locations.length} location${_locations.length != 1 ? 's' : ''}'
                                .tr(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: dark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const Spacer(),
                          DropdownButton<String>(
                            value: _sortBy,
                            dropdownColor: dark ? Colors.grey.shade800 : Colors.white,
                            style: TextStyle(
                              color: dark ? Colors.white : Colors.black87,
                              fontSize: 12,
                            ),
                            underline: const SizedBox(),
                            onChanged: (value) {
                              setState(() => _sortBy = value ?? 'nearest');
                              _sortLocations();
                            },
                            items: [
                              DropdownMenuItem(
                                value: 'nearest',
                                child: Text('Nearest'.tr()),
                              ),
                              DropdownMenuItem(
                                value: 'name',
                                child: Text('Name'.tr()),
                              ),
                              DropdownMenuItem(
                                value: 'newest',
                                child: Text('Newest'.tr()),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Locations list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _locations.length,
                        itemBuilder: (context, index) {
                          final location = _locations[index];
                          return _buildLocationCard(location, dark);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildLocationCard(ListingModel location, bool dark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: dark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
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
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.locationLabel ?? location.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: dark ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: dark ? Colors.white54 : Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location.place,
                            style: TextStyle(
                              fontSize: 12,
                              color: dark ? Colors.white54 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (location.phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: dark ? Colors.white54 : Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            location.phone,
                            style: TextStyle(
                              fontSize: 12,
                              color: dark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: dark ? Colors.white38 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
