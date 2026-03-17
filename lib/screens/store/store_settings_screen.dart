import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/store_service.dart';
import 'package:caribtap/listings/ui/table_mode/staff_tables_screen.dart';

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
  late TextEditingController _deliveryFeeController;
  late TextEditingController _shippingFeeController;
  
  late bool _pickupEnabled;
  late bool _deliveryEnabled;
  late double _deliveryFee;
  late bool _dineInEnabled;
  late bool _shippingEnabled;
  late double _shippingFee;
  late int _leadTimeHours;
  
  bool _isSaving = false;
  bool _canManageTableMode = false;

  @override
  void initState() {
    super.initState();
    _pickupEnabled = widget.listing.storePickupEnabled;
    _deliveryEnabled = widget.listing.storeDeliveryEnabled;
    _deliveryFee = widget.listing.storeDeliveryFee;
    _dineInEnabled = widget.listing.storeDineInEnabled;
    _shippingEnabled = widget.listing.storeShippingEnabled;
    _shippingFee = widget.listing.storeShippingFee;
    _leadTimeHours = widget.listing.storeLeadTimeHours;
    _deliveryFeeController = TextEditingController(text: _deliveryFee > 0 ? _deliveryFee.toString() : '');
    _shippingFeeController = TextEditingController(text: _shippingFee > 0 ? _shippingFee.toString() : '');
    _checkTableModePermissions();
  }

  Future<void> _checkTableModePermissions() async {
    // Check if user is owner
    if (widget.currentUser.userID == widget.listing.authorID) {
      setState(() {
        _canManageTableMode = true;
      });
      return;
    }

    // Check if user is a collaborator with manageTableMode permission
    try {
      final collabSnap = await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.listing.id)
          .collection('collaborators')
          .doc(widget.currentUser.userID)
          .get();

      if (collabSnap.exists) {
        final data = collabSnap.data();
        final isActive = data?['isActive'] == true;
        final permissions = data?['permissions'] as Map<String, dynamic>? ?? {};
        final hasTablePermission = permissions['manageTableMode'] == true;

        if (mounted && isActive && hasTablePermission) {
          setState(() {
            _canManageTableMode = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking table mode permissions: $e');
    }
  }

  @override
  void dispose() {
    _deliveryFeeController.dispose();
    _shippingFeeController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    triggerHapticLight();
    // Validate at least one fulfillment method is enabled
    if (!_pickupEnabled && !_deliveryEnabled && !_dineInEnabled && !_shippingEnabled) {
      showSnackBar(context, 'At least one fulfillment method must be enabled'.tr());
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Update listing with new settings
      final updatedListing = widget.listing;
      updatedListing.storePickupEnabled = _pickupEnabled;
      updatedListing.storeDeliveryEnabled = _deliveryEnabled;
      updatedListing.storeDeliveryFee = _deliveryFee;
      updatedListing.storeDineInEnabled = _dineInEnabled;
      updatedListing.storeShippingEnabled = _shippingEnabled;
      updatedListing.storeShippingFee = _shippingFee;
      updatedListing.storeLeadTimeHours = _leadTimeHours;

      // Save to Firestore
      await _storeService.updateListingStoreSettings(
        listingId: widget.listing.id,
        pickupEnabled: _pickupEnabled,
        deliveryEnabled: _deliveryEnabled,
        deliveryFee: _deliveryFee,
        dineInEnabled: _dineInEnabled,
        shippingEnabled: _shippingEnabled,
        shippingFee: _shippingFee,
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

  void _showFulfillmentInfo() {
    final dark = isDarkMode(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'store_fulfillment_info_title'.tr(),
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
        content: Text(
          'store_fulfillment_info_body'.tr(),
          style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'.tr()),
          ),
        ],
      ),
    );
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
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom + 50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fulfillment Methods Section
            Row(
              children: [
                Text(
                  'Fulfillment Methods'.tr(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'store_fulfillment_info_tooltip'.tr(),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _showFulfillmentInfo,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: dark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
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
                        triggerHapticLight();
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
                        triggerHapticLight();
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
            const SizedBox(height: 12),

            // Delivery Fee (shown only when delivery is enabled)
            if (_deliveryEnabled) ...[
              Card(
                color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Fee (Optional)'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: dark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _deliveryFeeController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: dark ? Colors.white : Colors.black),
                              onChanged: (value) {
                                setState(() {
                                  _deliveryFee = double.tryParse(value) ?? 0.0;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: 'Fee amount'.tr(),
                                labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                                hintText: '0.00'.tr(),
                                hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black26),
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: dark ? Colors.grey.shade800 : Colors.white,
                                prefixText: '${widget.listing.storeCurrencyCode ?? 'USD'} ',
                                prefixStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: dark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Leave empty or 0 for free delivery'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Dining In Option
            Card(
              color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Checkbox(
                      value: _dineInEnabled,
                      onChanged: (value) {
                        triggerHapticLight();
                        setState(() => _dineInEnabled = value ?? false);
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
                            'Dining In'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: dark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Customers order for dining in at your location'.tr(),
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

            // Shipping Option
            Card(
              color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Checkbox(
                      value: _shippingEnabled,
                      onChanged: (value) {
                        triggerHapticLight();
                        setState(() => _shippingEnabled = value ?? false);
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
                            'Shipping'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: dark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Orders sent via carrier with tracking'.tr(),
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

            // Shipping Fee (shown only when shipping is enabled)
            if (_shippingEnabled) ...[
              Card(
                color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shipping Fee (Optional)'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: dark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: dark ? Colors.white : Colors.black),
                              onChanged: (value) {
                                setState(() {
                                  _shippingFee = double.tryParse(value) ?? 0.0;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: 'Fee amount'.tr(),
                                labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                                hintText: '0.00'.tr(),
                                hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black26),
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: dark ? Colors.grey.shade800 : Colors.white,
                                prefixText: '${widget.listing.storeCurrencyCode ?? 'USD'} ',
                                prefixStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: dark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              controller: _shippingFeeController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Leave empty or 0 for free shipping'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Table Mode Section
            if (_canManageTableMode) ...[
              Text(
                'Table Mode'.tr(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: dark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage dine-in tables and QR codes for this listing'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                child: ListTile(
                  leading: Icon(
                    Icons.table_restaurant,
                  color: Color(cfg.colorPrimary),
                ),
                title: Text(
                  'Tables & QR Codes'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  'Create tables, share QR codes, and manage sessions'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: dark ? Colors.white70 : Colors.black54,
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StaffTablesScreen(
                        listing: widget.listing,
                        currentUser: widget.currentUser,
                      ),
                    ),
                  );
                },
              ),
            ),
              const SizedBox(height: 32),
            ],

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
                        triggerHapticLight();
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
