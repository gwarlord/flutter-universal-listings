import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_module/api/listings_api_manager.dart';

class BookingServicesWrapperWidget extends StatelessWidget {
  final ListingsUser currentUser;

  const BookingServicesWrapperWidget({Key? key, required this.currentUser})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BookingServicesScreen(currentUser: currentUser);
  }
}

class BookingServicesScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const BookingServicesScreen({Key? key, required this.currentUser})
      : super(key: key);

  @override
  State<BookingServicesScreen> createState() => _BookingServicesScreenState();
}

class _BookingServicesScreenState extends State<BookingServicesScreen> {
  List<ListingModel> _listings = [];
  late ListingsUser currentUser;
  bool isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    _loadListings();
  }

  Future<void> _loadListings() async {
    try {
      final listings = await listingApiManager.getMyListings(
        currentUserID: currentUser.userID,
        favListingsIDs: currentUser.likedListingsIDs,
      );
      
      // Remove duplicates by id
      final Map<String, ListingModel> uniqueListings = {};
      for (final listing in listings) {
        uniqueListings[listing.id] = listing;
      }
      
      setState(() {
        _listings = uniqueListings.values.toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading listings: $e')),
        );
      }
    }
  }

  Future<void> _updateListing(ListingModel listing) async {
    if (_isUpdating) return;
    
    setState(() => _isUpdating = true);
    
    try {
      await listingApiManager.publishListing(listing);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Listing updated successfully'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating listing: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Services'.tr()),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listings.isEmpty
              ? Center(
                  child: Text('No listings found'.tr()),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _listings.length,
                  itemBuilder: (context, index) {
                    final listing = _listings[index];
                    return _buildListingCard(listing, dark, key: ValueKey(listing.id));
                  },
                ),
    );
  }

  Widget _buildListingCard(ListingModel listing, bool dark, {Key? key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      color: dark ? Colors.grey.shade900 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Listing Title
            Text(
              listing.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // Require Booking Toggle
            _buildToggleTile(
              title: 'Require Booking'.tr(),
              subtitle: 'Show a "Book Now" button on your listing'.tr(),
              value: listing.bookingEnabled ?? false,
              onChanged: _isUpdating ? null : (value) {
                final updated = listing.copyWith(bookingEnabled: value);
                _updateListing(updated);
                setState(() {
                  _listings = _listings.map((l) => l.id == listing.id ? updated : l).toList();
                });
              },
              dark: dark,
            ),

            if (listing.bookingEnabled ?? false) ...[
              const SizedBox(height: 12),
              // Allow Quantity Selection Toggle
              _buildToggleTile(
                title: 'Allow Quantity Selection'.tr(),
                subtitle: 'Customers can select quantity when booking services'.tr(),
                value: listing.allowQuantitySelection ?? false,
                onChanged: _isUpdating ? null : (value) {
                  final updated = listing.copyWith(allowQuantitySelection: value);
                  _updateListing(updated);
                  setState(() {
                    _listings = _listings.map((l) => l.id == listing.id ? updated : l).toList();
                  });
                },
                dark: dark,
              ),
              const SizedBox(height: 12),
              // Use Time Blocks Toggle
              _buildToggleTile(
                title: 'Use Time Blocks'.tr(),
                subtitle: 'Enable hourly time slot bookings instead of full day bookings'.tr(),
                value: listing.useTimeBlocks ?? false,
                onChanged: _isUpdating ? null : (value) {
                  final updated = listing.copyWith(useTimeBlocks: value);
                  _updateListing(updated);
                  setState(() {
                    _listings = _listings.map((l) => l.id == listing.id ? updated : l).toList();
                  });
                },
                dark: dark,
              ),
              if (listing.useTimeBlocks ?? false) ...[
                const SizedBox(height: 12),
                // Allow Multiple Bookings Per Day Toggle
                _buildToggleTile(
                  title: 'Allow Multiple Bookings Per Day'.tr(),
                  subtitle: 'Multiple customers can book different time slots on the same day'.tr(),
                  value: listing.allowMultipleBookingsPerDay ?? false,
                  onChanged: _isUpdating ? null : (value) {
                    final updated = listing.copyWith(allowMultipleBookingsPerDay: value);
                    _updateListing(updated);
                    setState(() {
                      _listings = _listings.map((l) => l.id == listing.id ? updated : l).toList();
                    });
                  },
                  dark: dark,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool)? onChanged,
    required bool dark,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: dark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
        ),
      ),
      activeColor: Color(colorPrimary),
      activeTrackColor: Color(colorPrimary).withOpacity(0.5),
      inactiveThumbColor: dark ? Colors.grey.shade600 : Colors.grey.shade400,
      inactiveTrackColor: dark ? Colors.grey.shade800 : Colors.grey.shade300,
    );
  }
}
