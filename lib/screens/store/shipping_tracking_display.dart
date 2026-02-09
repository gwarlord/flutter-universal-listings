import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:instaflutter/listings/model/order_request.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/core/utils/helper.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget to display shipping tracking information to customers
/// 
/// Shows:
/// - Carrier name
/// - Tracking number (with copy button)
/// - Tracking URL (with open external button)
/// - Status badge
/// - Last updated timestamp
class ShippingTrackingDisplay extends StatelessWidget {
  final OrderRequest order;

  const ShippingTrackingDisplay({
    Key? key,
    required this.order,
  }) : super(key: key);

  Future<void> _openTrackingUrl(BuildContext context) async {
    if (order.shipping?.trackingUrl == null) return;

    try {
      if (await canLaunchUrl(Uri.parse(order.shipping!.trackingUrl!))) {
        await launchUrl(
          Uri.parse(order.shipping!.trackingUrl!),
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (context.mounted) {
          showSnackBar(context, 'Could not open tracking URL'.tr());
        }
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Error opening link: $e');
      }
    }
  }

  void _copyTrackingNumber(BuildContext context) {
    if (order.shipping?.trackingNumber == null) return;

    final text = order.shipping!.trackingNumber!;
    Clipboard.setData(ClipboardData(text: text));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tracking number copied: $text'.tr()),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _copyCarrierName(BuildContext context) {
    if (order.shipping?.carrierName == null) return;

    final text = order.shipping!.carrierName!;
    Clipboard.setData(ClipboardData(text: text));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Carrier name copied: $text'.tr()),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _copyTrackingUrl(BuildContext context) {
    if (order.shipping?.trackingUrl == null) return;

    final text = order.shipping!.trackingUrl!;
    Clipboard.setData(ClipboardData(text: text));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tracking URL copied'.tr()),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getStatusLabel() {
    switch (order.shipping?.status) {
      case null:
        return 'Unknown';
      default:
        final status = order.shipping!.status.value;
        switch (status) {
          case 'LABEL_CREATED':
            return 'Label Created';
          case 'IN_TRANSIT':
            return 'In Transit';
          case 'OUT_FOR_DELIVERY':
            return 'Out for Delivery';
          case 'DELIVERED':
            return 'Delivered';
          default:
            return 'Unknown';
        }
    }
  }

  Color _getStatusColor() {
    switch (order.shipping?.status) {
      case null:
        return Colors.grey;
      default:
        final status = order.shipping!.status.value;
        switch (status) {
          case 'LABEL_CREATED':
            return Colors.blue;
          case 'IN_TRANSIT':
            return Colors.orange;
          case 'OUT_FOR_DELIVERY':
            return Colors.purple;
          case 'DELIVERED':
            return Colors.green;
          default:
            return Colors.grey;
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    // If no tracking info, don't show anything
    if (order.shipping?.trackingNumber == null &&
        order.shipping?.trackingUrl == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  color: Color(cfg.colorPrimary),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Order Tracking'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Carrier with Copy Button
            if (order.shipping?.carrierName != null) ...[
              Text(
                'Carrier'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      order.shipping!.carrierName!,
                      style: TextStyle(
                        fontSize: 14,
                        color: dark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyCarrierName(context),
                    icon: Icon(
                      Icons.content_copy_outlined,
                      size: 18,
                      color: Color(cfg.colorPrimary),
                    ),
                    tooltip: 'Copy carrier name'.tr(),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(0),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Tracking Number with Copy Button
            if (order.shipping?.trackingNumber != null) ...[
              Text(
                'Tracking Number'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      order.shipping!.trackingNumber!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(cfg.colorPrimary),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyTrackingNumber(context),
                    icon: Icon(
                      Icons.content_copy_outlined,
                      size: 18,
                      color: Color(cfg.colorPrimary),
                    ),
                    tooltip: 'Copy tracking number'.tr(),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(0),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Tracking URL with Open and Copy Buttons
            if (order.shipping?.trackingUrl != null) ...[
              Text(
                'Track Package'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openTrackingUrl(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Open tracking link'.tr(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(cfg.colorPrimary),
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.open_in_new_outlined,
                                size: 18,
                                color: Color(cfg.colorPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyTrackingUrl(context),
                    icon: Icon(
                      Icons.content_copy_outlined,
                      size: 18,
                      color: Color(cfg.colorPrimary),
                    ),
                    tooltip: 'Copy tracking URL'.tr(),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(0),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Status Badge
            if (order.shipping?.status != null) ...[
              Text(
                'Status'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor().withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _getStatusLabel().tr(),
                  style: TextStyle(
                    fontSize: 13,
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Last Updated
            if (order.shipping?.updatedAt != null) ...[
              Text(
                'Last Updated'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d, y • h:mm a').format(order.shipping!.updatedAt!).tr(),
                style: TextStyle(
                  fontSize: 13,
                  color: dark ? Colors.grey.shade300 : Colors.black87,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chip to show on order list items that have tracking
class ShippingTrackingChip extends StatelessWidget {
  const ShippingTrackingChip({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color(cfg.colorPrimary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_shipping,
            size: 14,
            color: Color(cfg.colorPrimary),
          ),
          const SizedBox(width: 4),
          Text(
            'Tracking'.tr(),
            style: TextStyle(
              fontSize: 11,
              color: Color(cfg.colorPrimary),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
