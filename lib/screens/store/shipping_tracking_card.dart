import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/model/order_request.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/entitlement_service.dart';
import 'package:caribtap/listings/services/pro_gate.dart';
import 'package:caribtap/listings/services/store_service.dart';
import 'package:caribtap/listings/ui/subscription/pro_upgrade_screen.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/screens/store/barcode_scanner_field.dart';

/// Widget for lister to enter/edit shipping tracking information
/// 
/// Features:
/// - Shows locked panel if user doesn't have "CaribTap Pro" entitlement
/// - Upgrade CTA button to navigate to paywall
/// - Form to enter carrier, tracking number, tracking URL, and status
/// - Server-side verification of Pro entitlement in Cloud Function
class ShippingTrackingCard extends StatefulWidget {
  final OrderRequest order;
  final ListingsUser currentUser;
  final VoidCallback onTrackingUpdated;

  const ShippingTrackingCard({
    Key? key,
    required this.order,
    required this.currentUser,
    required this.onTrackingUpdated,
  }) : super(key: key);

  @override
  State<ShippingTrackingCard> createState() => _ShippingTrackingCardState();
}

class _ShippingTrackingCardState extends State<ShippingTrackingCard> {
  final StoreService _storeService = StoreService();
  final EntitlementService _entitlementService = EntitlementService();

  late TextEditingController _carrierController;
  late TextEditingController _trackingNumberController;
  late TextEditingController _trackingUrlController;
  late String _selectedStatus;

  bool _isLoading = false;
  bool _hasProfessional = false;
  bool _checkingEntitlement = true;
  DateTime? _lastSaveAttempt;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _checkProfessionalEntitlement();
  }

  void _initializeControllers() {
    _carrierController = TextEditingController(
      text: widget.order.shipping?.carrierName ?? '',
    );
    _trackingNumberController = TextEditingController(
      text: widget.order.shipping?.trackingNumber ?? '',
    );
    _trackingUrlController = TextEditingController(
      text: widget.order.shipping?.trackingUrl ?? '',
    );
    _selectedStatus = widget.order.shipping?.status.value ?? 'UNKNOWN';
  }

  Future<void> _checkProfessionalEntitlement() async {
    try {
      final entitlement =
          await _entitlementService.fetchEntitlement(widget.currentUser.userID);
      final hasPro = ProGate.tierAtLeast(
        entitlement,
        1,
        isAdmin: widget.currentUser.isAdmin,
      );

      setState(() {
        _hasProfessional = hasPro;
        _checkingEntitlement = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _checkingEntitlement = false);
      }
    }
  }

  Future<void> _saveTracking() async {
    final trackingNumber = _trackingNumberController.text.trim();
    final trackingUrl = _trackingUrlController.text.trim();

    // Validate required fields
    if (trackingNumber.isEmpty) {
      showSnackBar(context, 'Tracking number is required'.tr());
      return;
    }

    if (trackingUrl.isEmpty) {
      showSnackBar(context, 'Tracking URL is required'.tr());
      return;
    }

    // Prevent rapid successive saves to avoid App Check rate limiting
    final now = DateTime.now();
    if (_lastSaveAttempt != null) {
      final timeSinceLastSave = now.difference(_lastSaveAttempt!);
      if (timeSinceLastSave.inSeconds < 3) {
        showSnackBar(context, 'Please wait a moment before saving again'.tr());
        return;
      }
    }
    _lastSaveAttempt = now;

    setState(() => _isLoading = true);

    try {
      await _storeService.setOrderTracking(
        orderId: widget.order.id,
        carrierName: _carrierController.text.trim().isEmpty
            ? null
            : _carrierController.text.trim(),
        trackingNumber: trackingNumber,
        trackingUrl: trackingUrl,
        status: _selectedStatus,
      );

      if (mounted) {
        showSnackBar(context, 'Tracking information saved'.tr());
        widget.onTrackingUpdated();
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Error saving tracking: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode(context)
            ? Colors.grey.shade900
            : Colors.white,
        title: Text(
          'Unlock Shipping Tracking'.tr(),
          style: TextStyle(
            color: isDarkMode(context) ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Shipping tracking is available for CaribTap Pro subscribers. Upgrade now to track orders and keep customers updated.'.tr(),
          style: TextStyle(
            color: isDarkMode(context)
                ? Colors.grey.shade300
                : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe later'.tr(),
              style: TextStyle(color: Color(cfg.colorPrimary)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToPaywall();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(cfg.colorPrimary),
            ),
            child: Text(
              'Upgrade now'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToPaywall() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProUpgradeScreen(currentUser: widget.currentUser),
      ),
    );

    // After purchasing, check entitlement again
    if (result == true && mounted) {
      _checkProfessionalEntitlement();
    }
  }

  @override
  void dispose() {
    _carrierController.dispose();
    _trackingNumberController.dispose();
    _trackingUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    if (_checkingEntitlement) {
      return Card(
        color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(cfg.colorPrimary)),
            ),
          ),
        ),
      );
    }

    if (!_hasProfessional) {
      // Show locked panel
      return Card(
        color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: Color(cfg.colorPrimary),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shipping Tracking'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: dark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pro feature'.tr(),
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
              const SizedBox(height: 12),
              Text(
                'Upgrade to CaribTap Pro to add tracking information and keep your customers updated on shipments.'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  color: dark ? Colors.grey.shade300 : Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _showUpgradeDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(cfg.colorPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Upgrade to Pro'.tr(),
                    style: const TextStyle(
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

    // Show tracking form
    return Card(
      color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  color: Color(cfg.colorPrimary),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Shipping Tracking'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Carrier Name
            TextField(
              controller: _carrierController,
              style: TextStyle(color: dark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'Carrier (optional)'.tr(),
                labelStyle: TextStyle(
                  color: dark ? Colors.white70 : Colors.black54,
                ),
                hintText: 'e.g., FedEx, UPS, DHL'.tr(),
                hintStyle: TextStyle(
                  color: dark ? Colors.white38 : Colors.black26,
                ),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: dark ? Colors.grey.shade800 : Colors.white,
                enabled: !_isLoading,
              ),
            ),
            const SizedBox(height: 12),

            // Tracking Number with Barcode Scanner
            BarcodeTextField(
              controller: _trackingNumberController,
              labelText: 'Tracking Number *'.tr(),
              hintText: 'Scan barcode or enter manually'.tr(),
              isLoading: _isLoading,
              isDarkMode: dark,
              onChanged: (value) {
                // Optional: handle real-time changes if needed
              },
            ),
            const SizedBox(height: 12),

            // Tracking URL
            TextField(
              controller: _trackingUrlController,
              style: TextStyle(color: dark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'Tracking URL *'.tr(),
                labelStyle: TextStyle(
                  color: dark ? Colors.white70 : Colors.black54,
                ),
                hintText: 'https://...'.tr(),
                hintStyle: TextStyle(
                  color: dark ? Colors.white38 : Colors.black26,
                ),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: dark ? Colors.grey.shade800 : Colors.white,
                enabled: !_isLoading,
              ),
            ),
            const SizedBox(height: 12),

            // Status Dropdown
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              isExpanded: true,
              items: [
                DropdownMenuItem(value: 'UNKNOWN', child: Text('Unknown'.tr())),
                DropdownMenuItem(
                    value: 'LABEL_CREATED', child: Text('Label Created'.tr())),
                DropdownMenuItem(value: 'IN_TRANSIT', child: Text('In Transit'.tr())),
                DropdownMenuItem(
                    value: 'OUT_FOR_DELIVERY',
                    child: Text('Out for Delivery'.tr())),
                DropdownMenuItem(value: 'DELIVERED', child: Text('Delivered'.tr())),
              ],
              onChanged: _isLoading ? null : (value) {
                if (value != null) {
                  setState(() => _selectedStatus = value);
                }
              },
              style: TextStyle(color: dark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'Status'.tr(),
                labelStyle: TextStyle(
                  color: dark ? Colors.white70 : Colors.black54,
                ),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: dark ? Colors.grey.shade800 : Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTracking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(cfg.colorPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Save Tracking'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            if (widget.order.shipping?.trackingNumber != null) ...[
              const SizedBox(height: 12),
              Text(
                'Last updated: ${DateFormat('MMM d, y • h:mm a').format(widget.order.shipping?.updatedAt ?? DateTime.now())}'
                    .tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
