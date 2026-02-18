import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:caribtap/listings/model/rental_config.dart';
import 'package:caribtap/listings/model/rental_booking.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/core/utils/helper.dart';

class RentalBookingDialog extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser currentUser;
  final RentalConfig rentalConfig;

  const RentalBookingDialog({
    Key? key,
    required this.listing,
    required this.currentUser,
    required this.rentalConfig,
  }) : super(key: key);

  @override
  State<RentalBookingDialog> createState() => _RentalBookingDialogState();
}

class _RentalBookingDialogState extends State<RentalBookingDialog> {
  
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  
  bool _isChecking = false;
  bool _isAvailable = false;
  double _totalPrice = 0.0;
  String? _errorMessage;
  
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkAvailability() async {
    if (_startDate == null || _endDate == null) {
      setState(() {
        _errorMessage = 'Please select start and end dates';
        _isAvailable = false;
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final startDateTime = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        _startTime?.hour ?? 0,
        _startTime?.minute ?? 0,
      );

      final endDateTime = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        _endTime?.hour ?? 23,
        _endTime?.minute ?? 59,
      );

      if (endDateTime.isBefore(startDateTime)) {
        setState(() {
          _errorMessage = 'End date/time must be after start date/time';
          _isAvailable = false;
          _isChecking = false;
        });
        return;
      }

      // For now, just calculate price (availability checking requires rental unit)
      // In production, you'd select a specific rental unit first
      final duration = endDateTime.difference(startDateTime);
      double price = 0.0;
      
      switch (widget.rentalConfig.defaultPricingUnit) {
        case RentalPricingUnit.hourly:
          final hours = duration.inHours;
          price = widget.rentalConfig.basePrice * hours;
          break;
        case RentalPricingUnit.daily:
          final days = (duration.inDays > 0) ? duration.inDays : 1;
          price = widget.rentalConfig.basePrice * days;
          break;
        case RentalPricingUnit.weekly:
          final weeks = (duration.inDays / 7).ceil();
          price = widget.rentalConfig.basePrice * weeks;
          break;
        case RentalPricingUnit.monthly:
          final months = (duration.inDays / 30).ceil();
          price = widget.rentalConfig.basePrice * months;
          break;
      }

      final available = true; // Simplified for now

      if (available) {

        setState(() {
          _isAvailable = true;
          _totalPrice = price;
          _isChecking = false;
        });
      } else {
        setState(() {
          _isAvailable = false;
          _errorMessage = 'This item is not available for the selected dates';
          _isChecking = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking availability: $e';
        _isAvailable = false;
        _isChecking = false;
      });
    }
  }

  Future<void> _submitBooking() async {
    if (!_isAvailable || _startDate == null || _endDate == null) return;

    final startDateTime = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime?.hour ?? 0,
      _startTime?.minute ?? 0,
    );

    final endDateTime = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endTime?.hour ?? 23,
      _endTime?.minute ?? 59,
    );

    try {
      // Save booking to Firestore using a simplified structure
      final now = DateTime.now();
      final duration = endDateTime.difference(startDateTime);
      int quantity = 1;
      
      switch (widget.rentalConfig.defaultPricingUnit) {
        case RentalPricingUnit.hourly:
          quantity = duration.inHours;
          break;
        case RentalPricingUnit.daily:
          quantity = (duration.inDays > 0) ? duration.inDays : 1;
          break;
        case RentalPricingUnit.weekly:
          quantity = (duration.inDays / 7).ceil();
          break;
        case RentalPricingUnit.monthly:
          quantity = (duration.inDays / 30).ceil();
          break;
      }

      final depositAmt = widget.rentalConfig.requiresDeposit 
          ? (widget.rentalConfig.depositAmount ?? 0.0) 
          : 0.0;

      await FirebaseFirestore.instance.collection('rental_bookings').add({
        'listingId': widget.listing.id,
        'rentalUnitId': 'general', // Would be selected in production
        'customerId': widget.currentUser.userID,
        'listerId': widget.listing.authorID,
        'startTime': Timestamp.fromDate(startDateTime),
        'endTime': Timestamp.fromDate(endDateTime),
        'pricingUnit': widget.rentalConfig.defaultPricingUnit.toString().split('.').last,
        'unitPrice': widget.rentalConfig.basePrice,
        'quantity': quantity,
        'subtotal': _totalPrice,
        'depositAmount': depositAmt,
        'totalAmount': _totalPrice + depositAmt,
        'status': RentalBookingStatus.pending.toString().split('.').last,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rental request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final primaryColor = Theme.of(context).primaryColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Book Rental',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.listing.title,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pricing Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.attach_money, color: primaryColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Base Price',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  '\$${widget.rentalConfig.basePrice.toStringAsFixed(2)} per ${widget.rentalConfig.defaultPricingUnit.toString().split('.').last}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Date Selection
                    const Text(
                      'Rental Period',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Start Date
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _startDate = date;
                            if (_endDate != null && _endDate!.isBefore(_startDate!)) {
                              _endDate = null;
                            }
                            _isAvailable = false;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: primaryColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Start Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(
                                    _startDate != null
                                        ? DateFormat('MMM dd, yyyy').format(_startDate!)
                                        : 'Select date',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // End Date
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? (_startDate ?? DateTime.now()),
                          firstDate: _startDate ?? DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _endDate = date;
                            _isAvailable = false;
                          });
                          _checkAvailability();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event, color: primaryColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('End Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(
                                    _endDate != null
                                        ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                        : 'Select date',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Notes
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Additional Notes (Optional)',
                        hintText: 'Any special requirements or questions...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Availability Status
                    if (_isChecking)
                      Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: primaryColor),
                            const SizedBox(height: 12),
                            const Text('Checking availability...'),
                          ],
                        ),
                      )
                    else if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_isAvailable)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green.shade700),
                                const SizedBox(width: 12),
                                Text(
                                  'Available!',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Price:', style: TextStyle(fontSize: 16)),
                                Text(
                                  '\$${_totalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            if (widget.rentalConfig.requiresDeposit) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Deposit:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                  Text(
                                    '\$${widget.rentalConfig.depositAmount?.toStringAsFixed(2) ?? '0.00'}',
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isAvailable ? _submitBooking : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Submit Request',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
