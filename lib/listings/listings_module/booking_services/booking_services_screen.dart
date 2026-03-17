import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/listings_module/add_listing/add_listing_screen.dart';

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
          SnackBar(content: Text('${'Error loading listings'.tr()}: $e')),
        );
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Choose a listing to manage booking settings, services, time blocks, blocked dates, and custom questions.'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _listings.length,
                        itemBuilder: (context, index) {
                          final listing = _listings[index];
                          return _buildListingCard(
                            listing,
                            dark,
                            key: ValueKey(listing.id),
                          );
                        },
                      ),
                    ),
                  ],
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
            Text(
              listing.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              listing.bookingEnabled
                  ? 'Booking is enabled for this listing.'.tr()
                  : 'Booking is currently disabled for this listing.'.tr(),
              style: TextStyle(
                fontSize: 13,
                color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  dark: dark,
                  label: listing.bookingEnabled
                      ? 'Booking On'.tr()
                      : 'Booking Off'.tr(),
                ),
                _buildInfoChip(
                  dark: dark,
                  label:
                      '${'Services'.tr()}: ${listing.services.length}',
                ),
                _buildInfoChip(
                  dark: dark,
                  label: listing.allowQuantitySelection
                      ? 'Quantity Enabled'.tr()
                      : 'Quantity Disabled'.tr(),
                ),
                _buildInfoChip(
                  dark: dark,
                  label: listing.useTimeBlocks
                      ? '${'Time Blocks'.tr()}: ${listing.timeBlocks.length}'
                      : 'Time Blocks Off'.tr(),
                ),
                _buildInfoChip(
                  dark: dark,
                  label:
                      '${'Blocked Dates'.tr()}: ${listing.blockedDates.length}',
                ),
                _buildInfoChip(
                  dark: dark,
                  label: listing.enableCustomQuestions
                      ? '${'Questions'.tr()}: ${listing.customQuestions.length}'
                      : 'Questions Off'.tr(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await push(
                    context,
                    EditListingWrappingWidget(
                      currentUser: currentUser,
                      listingToEdit: listing,
                    ),
                  );
                  if (mounted) {
                    _loadListings();
                  }
                },
                icon: const Icon(Icons.edit_outlined),
                label: Text('Open Booking Settings'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(colorPrimary),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required bool dark,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
        ),
      ),
    );
  }
}
