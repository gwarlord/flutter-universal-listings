import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/services/store_service.dart';

/// Store Settings Screen - Configure Mini Store fulfillment options
class StoreSettingsScreen extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser currentUser;
  final VoidCallback onSettingsUpdated;

  const StoreSettingsScreen({
    Key? key,
    required this.listing,
    required this.currentUser,
    required this.onSettingsUpdated,
  }) : super(key: key);

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final StoreService _storeService = StoreService();
  
  late bool _pickupEnabled;
  late bool _deliveryEnabled;
  late int _leadTimeHours;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pickupEnabled = widget.listing.storePickupEnabled;
    _deliveryEnabled = widget.listing.storeDeliveryEnabled;
    _leadTimeHours = widget.listing.storeLeadTimeHours;
  }

  Future<void> _saveSettings() async {
    // Validate at least one fulfillment method is enabled
    if (!_pickupEnabled && !_deliveryEnabled) {
      showSnackBar(context, 'At least one fulfillment method must be enabled'.tr());
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Update listing with new settings
      final updatedListing = widget.listing;
      updatedListing.storePickupEnabled = _pickupEnabled;
      updatedListing.storeDeliveryEnabled = _deliveryEnabled;
      updatedListing.storeLeadTimeHours = _leadTimeHours;

      // Save to Firestore
      await _storeService.updateListingStoreSettings(
        listingId: widget.listing.id,
        pickupEnabled: _pickupEnabled,
        deliveryEnabled: _deliveryEnabled,
        leadTimeHours: _leadTimeHours,
      );

      if (mounted) {
        widget.onSettingsUpdated();
        showSnackBar(context, 'Store settings updated'.tr());
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Error saving settings: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Store Settings'.tr(),
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: dark ? Colors.white : Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fulfillment Methods Section
            Text(
              'Fulfillment Methods'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select how customers can receive their orders'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),

            // Pickup Option
            Card(
              color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Checkbox(
                      value: _pickupEnabled,
                      onChanged: (value) {
                        setState(() => _pickupEnabled = value ?? false);
                      },
                      activeColor: Color(cfg.colorPrimary),
                      side: BorderSide(
                        color: dark ? Colors.white : Colors.grey,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pickup'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: dark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Customers pick up their order at your location'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Delivery Option
            Card(
              color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Checkbox(
                      value: _deliveryEnabled,
                      onChanged: (value) {
                        setState(() => _deliveryEnabled = value ?? false);
                      },
                      activeColor: Color(cfg.colorPrimary),
                      side: BorderSide(
                        color: dark ? Colors.white : Colors.grey,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: dark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You deliver orders to customer addresses'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Lead Time Section
            Text(
              'Minimum Lead Time'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'How many hours before customers can place orders'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),

            Card(
              color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_leadTimeHours hours'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(cfg.colorPrimary),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.info_outline,
                            color: dark ? Colors.white : Colors.black,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
                                title: Text(
                                  'Lead Time Help'.tr(),
                                  style: TextStyle(
                                    color: dark ? Colors.white : Colors.black,
                                  ),
                                ),
                                content: Text(
                                  'For example, 24 hours means customers cannot place orders for same-day fulfillment. They must order at least 24 hours in advance.'.tr(),
                                  style: TextStyle(
                                    color: dark ? Colors.grey.shade300 : Colors.black,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      'OK'.tr(),
                                      style: TextStyle(
                                        color: Color(cfg.colorPrimary),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _leadTimeHours.toDouble(),
                      min: 0,
                      max: 120,
                      divisions: 120,
                      label: '$_leadTimeHours hours',
                      activeColor: Color(cfg.colorPrimary),
                      onChanged: (value) {
                        setState(() => _leadTimeHours = value.toInt());
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'No lead time (now)'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '5 days'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(cfg.colorPrimary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Save Settings'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
