import 'package:flutter/material.dart';
import '../../model/listing_model.dart';
import '../../model/rental_config.dart';
import '../../model/rental_unit.dart';
import '../../model/rental_booking.dart';
import '../../services/rental_service.dart';

class RentalRequestScreen extends StatefulWidget {
  final ListingModel listing;
  final RentalConfig rentalConfig;

  const RentalRequestScreen({
    Key? key,
    required this.listing,
    required this.rentalConfig,
  }) : super(key: key);

  @override
  State<RentalRequestScreen> createState() => _RentalRequestScreenState();
}

class _RentalRequestScreenState extends State<RentalRequestScreen> {
  final RentalService _rentalService = RentalService();
  
  DateTime? _startTime;
  DateTime? _endTime;
  RentalUnit? _selectedUnit;
  List<RentalUnit> _availableUnits = [];
  bool _isLoadingUnits = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Rental'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Listing info
          _buildListingCard(),
          const SizedBox(height: 24),

          // Date/time selection
          _buildDateTimeSection(),
          const SizedBox(height: 24),

          // Available units
          if (_startTime != null && _endTime != null) ...[
            _buildAvailableUnitsSection(),
            const SizedBox(height: 24),
          ],

          // Pricing summary
          if (_selectedUnit != null) ...[
            _buildPricingSummary(),
            const SizedBox(height: 24),
          ],

          // Terms and conditions
          if (widget.rentalConfig.termsAndConditions != null) ...[
            _buildTermsSection(),
            const SizedBox(height: 24),
          ],

          // Submit button
          if (_selectedUnit != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Rental Request'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (widget.listing.photo.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.listing.photo,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: Icon(Icons.image, color: Colors.grey[500]),
                    );
                  },
                ),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.listing.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${widget.rentalConfig.basePrice.toStringAsFixed(2)} per ${widget.rentalConfig.defaultPricingUnit.toString().split('.').last}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
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

  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rental Period',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Start Date & Time'),
                  subtitle: Text(
                    _startTime != null
                        ? _formatDateTime(_startTime!)
                        : 'Not selected',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _selectDateTime(isStart: true),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.event),
                  title: const Text('End Date & Time'),
                  subtitle: Text(
                    _endTime != null ? _formatDateTime(_endTime!) : 'Not selected',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _startTime != null
                      ? () => _selectDateTime(isStart: false)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableUnitsSection() {
    if (_isLoadingUnits) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Unit',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (_availableUnits.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No units available for selected dates',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...._availableUnits.map((unit) => _buildUnitCard(unit)),
      ],
    );
  }

  Widget _buildUnitCard(RentalUnit unit) {
    final isSelected = _selectedUnit?.id == unit.id;

    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      child: InkWell(
        onTap: () {
          setState(() => _selectedUnit = unit);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (unit.photoUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    unit.photoUrls.first,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: Icon(Icons.image, color: Colors.grey[500]),
                      );
                    },
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.unitName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (unit.description != null)
                      Text(
                        unit.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingSummary() {
    final quantity = _rentalService.calculateQuantity(
      startTime: _startTime!,
      endTime: _endTime!,
      pricingUnit: widget.rentalConfig.defaultPricingUnit,
    );

    final subtotal = quantity * widget.rentalConfig.basePrice;
    final deposit = widget.rentalConfig.requiresDeposit
        ? (widget.rentalConfig.depositAmount ?? 0.0)
        : 0.0;
    final total = subtotal + deposit;

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(),
            _buildPriceRow(
              'Unit Price',
              '\$${widget.rentalConfig.basePrice.toStringAsFixed(2)}',
            ),
            _buildPriceRow(
              'Quantity',
              '$quantity ${widget.rentalConfig.defaultPricingUnit.toString().split('.').last}(s)',
            ),
            _buildPriceRow('Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
            if (widget.rentalConfig.requiresDeposit)
              _buildPriceRow('Security Deposit', '\$${deposit.toStringAsFixed(2)}'),
            const Divider(),
            _buildPriceRow(
              'Total',
              '\$${total.toStringAsFixed(2)}',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isTotal ? FontWeight.bold : null,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isTotal ? FontWeight.bold : null,
                  fontSize: isTotal ? 18 : null,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms & Conditions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.rentalConfig.termsAndConditions!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateTime({required bool isStart}) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startTime ?? DateTime.now())
          : (_endTime ?? _startTime ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null && mounted) {
        final selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if (selectedDateTime.isBefore(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select a future time'.tr())),
          );
          return;
        }

        setState(() {
          if (isStart) {
            _startTime = selectedDateTime;
            // Reset end time if it's before start time
            if (_endTime != null && _endTime!.isBefore(_startTime!)) {
              _endTime = null;
            }
            _selectedUnit = null;
            _availableUnits.clear();
          } else {
            if (_startTime != null && selectedDateTime.isBefore(_startTime!)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('End time must be after start time'.tr())),
              );
              return;
            }
            _endTime = selectedDateTime;
            _selectedUnit = null;
          }
        });

        // Load available units if both dates are selected
        if (_startTime != null && _endTime != null) {
          _loadAvailableUnits();
        }
      }
    }
  }

  Future<void> _loadAvailableUnits() async {
    setState(() => _isLoadingUnits = true);

    try {
      final units = await _rentalService.getAvailableUnits(
        listingId: widget.listing.id,
        startTime: _startTime!,
        endTime: _endTime!,
        bufferMinutes: widget.rentalConfig.bufferMinutes,
      );

      if (mounted) {
        setState(() {
          _availableUnits = units;
          _isLoadingUnits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUnits = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading units: $e')),
        );
      }
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedUnit == null || _startTime == null || _endTime == null) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final quantity = _rentalService.calculateQuantity(
        startTime: _startTime!,
        endTime: _endTime!,
        pricingUnit: widget.rentalConfig.defaultPricingUnit,
      );

      final subtotal = quantity * widget.rentalConfig.basePrice;
      final deposit = widget.rentalConfig.requiresDeposit
          ? (widget.rentalConfig.depositAmount ?? 0.0)
          : 0.0;
      final total = subtotal + deposit;

      final booking = RentalBooking(
        id: '',
        listingId: widget.listing.id,
        rentalUnitId: _selectedUnit!.id,
        customerId: 'current_user_id', // TODO: Get from auth
        listerId: widget.listing.authorID,
        startTime: _startTime!,
        endTime: _endTime!,
        pricingUnit: widget.rentalConfig.defaultPricingUnit,
        unitPrice: widget.rentalConfig.basePrice,
        quantity: quantity,
        subtotal: subtotal,
        depositAmount: deposit,
        totalAmount: total,
        status: RentalBookingStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _rentalService.createRentalBooking(booking);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rental request submitted successfully!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final date = MaterialLocalizations.of(context).formatMediumDate(dateTime);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(dateTime),
      alwaysUse24HourFormat: false,
    );
    return '$date at $time';
  }
}
