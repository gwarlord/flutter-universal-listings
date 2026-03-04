import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/rental_config.dart';
import 'package:caribtap/screens/rentals/rental_item_models.dart';
import 'package:caribtap/screens/rentals/rental_browse_service.dart';
import 'package:caribtap/screens/rentals/rental_cart_storage.dart';
import 'package:intl/intl.dart';

/// Rental checkout screen - Review cart and complete booking
class RentalCheckoutScreen extends StatefulWidget {
  final ListingModel listing;
  final RentalConfig rentalConfig;
  final List<RentalCartItem> cartItems;
  final ListingsUser? currentUser;
  final VoidCallback onCheckoutComplete;

  const RentalCheckoutScreen({
    Key? key,
    required this.listing,
    required this.rentalConfig,
    required this.cartItems,
    this.currentUser,
    required this.onCheckoutComplete,
  }) : super(key: key);

  @override
  State<RentalCheckoutScreen> createState() => _RentalCheckoutScreenState();
}

class _RentalCheckoutScreenState extends State<RentalCheckoutScreen> {
  final RentalBrowseService _rentalService = RentalBrowseService();
  final TextEditingController _notesController = TextEditingController();
  bool _agreedToTerms = false;
  bool _isProcessing = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return widget.cartItems.fold<double>(0, (sum, item) => sum + item.totalPrice);
  }

  double get _deposit {
    return widget.rentalConfig.depositAmount ?? 0.0;
  }

  double get _total {
    return _subtotal + _deposit;
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final primaryColor = Color(cfg.colorPrimary);

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          'Review Rental Booking'.tr(),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rental items
              Text(
                'Rental Items'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...widget.cartItems.map((item) => _buildCartItemTile(item, dark)),
              const SizedBox(height: 24),

              // Lister information
              Text(
                'Lister Information'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildListerCard(dark),
              const SizedBox(height: 24),

              // Rental terms
              Text(
                'Rental Terms'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: dark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pricing Unit: ${widget.rentalConfig.defaultPricingUnit.toString().split('.').last}'.tr(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (widget.rentalConfig.requiresDeposit)
                      Text(
                        'Deposit Required: \$${widget.rentalConfig.depositAmount?.toStringAsFixed(2) ?? '0.00'}'.tr(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    const SizedBox(height: 8),
                    if (widget.rentalConfig.termsAndConditions != null) ...[
                      Text(
                        'Terms & Conditions:'.tr(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.rentalConfig.termsAndConditions!,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Customer notes
              Text(
                'Additional Notes'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'Any special requests or notes...'.tr(),
                  hintStyle: TextStyle(color: dark ? Colors.white54 : Colors.black45),
                  filled: true,
                  fillColor: dark ? Colors.grey.shade800 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: dark ? Colors.grey.shade700 : Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Price breakdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: dark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal'.tr()),
                        Text('\$${_subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (widget.rentalConfig.requiresDeposit) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Deposit'.tr()),
                          Text('\$${_deposit.toStringAsFixed(2)}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '\$${_total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Terms agreement
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'I agree to the rental terms and conditions'.tr(),
                  style: const TextStyle(fontSize: 12),
                ),
                value: _agreedToTerms,
                onChanged: (value) {
                  setState(() => _agreedToTerms = value ?? false);
                },
              ),

              const SizedBox(height: 24),

              // Complete booking button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (!_agreedToTerms || widget.currentUser == null || _isProcessing)
                          ? null
                          : _completeBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text('Complete Booking'.tr()),
                ),
              ),

              if (widget.currentUser == null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Please log in to complete your booking'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],

              SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItemTile(RentalCartItem item, bool dark) {
    return Card(
      color: dark ? Colors.grey.shade900 : Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image
            if (item.photoUrl != null)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(item.photoUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
                child: Icon(
                  Icons.image_not_supported,
                  color: dark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.unitName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('MMM dd').format(item.startDate)} - ${DateFormat('MMM dd').format(item.endDate)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.durationDays} days × \$${item.pricePerDay.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${item.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Remove button
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                setState(() {
                  widget.cartItems.remove(item);
                });
                await RentalCartStorage.saveCart(widget.listing.id, widget.cartItems);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListerCard(bool dark) {
    // Use authorProfilePic for avatar, fallback to listing photo
    final avatarUrl = widget.listing.authorProfilePic.isNotEmpty 
        ? widget.listing.authorProfilePic 
        : (widget.listing.photo ?? '');
    
    // Use authorName, fallback to title owner
    final displayName = widget.listing.authorName.isNotEmpty 
        ? widget.listing.authorName 
        : '${widget.listing.title} Owner'.tr();
    
    return Card(
      color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 24)
                  : null,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.listing.title,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeBooking() async {
    if (widget.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to continue'.tr())),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final bookingIds = await _rentalService.createRentalBooking(
        listingId: widget.listing.id,
        customerId: widget.currentUser!.userID,
        listerId: widget.listing.authorID,
        cartItems: widget.cartItems,
        totalAmount: _total,
        depositAmount: widget.rentalConfig.requiresDeposit ? _deposit : null,
        customerNotes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (bookingIds.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Booking requests submitted successfully!'.tr()),
              backgroundColor: Colors.green,
            ),
          );

          // Delay to show success message
          await Future.delayed(const Duration(seconds: 1));
          widget.onCheckoutComplete();
        }
      } else {
        throw Exception('Failed to create booking');
      }
    } catch (e) {
      debugPrint('Error completing booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing booking: ${e.toString()}'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}

void debugPrint(String message) {
  print(message);
}
