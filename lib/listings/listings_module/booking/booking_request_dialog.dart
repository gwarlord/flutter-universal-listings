import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/listings_module/api/booking_api_manager.dart';
import 'package:caribtap/listings/listings_module/booking/booking_bloc.dart';
import 'package:caribtap/listings/listings_module/booking/booking_event.dart';
import 'package:caribtap/listings/listings_module/booking/booking_state.dart';
import 'package:caribtap/listings/listings_module/booking/widgets/date_range_picker.dart';
import 'package:caribtap/listings/model/booking_model.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/ui/phone_verification/booking_phone_gate.dart';

class BookingRequestDialog extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser currentUser;

  const BookingRequestDialog({
    super.key,
    required this.listing,
    required this.currentUser,
  });

  @override
  State<BookingRequestDialog> createState() => _BookingRequestDialogState();
}

class _BookingRequestDialogState extends State<BookingRequestDialog> {
  DateRange? _selectedDateRange;
  int _numberOfGuests = 1;
  late TextEditingController _guestsController;
  late TextEditingController _guestsInputController;
  final TextEditingController _notesController = TextEditingController();
  List<DateTime> _bookedDates = [];
  String? _selectedTimeBlock; // ✅ Selected time block
  List<String> _availableTimeBlocks = []; // ✅ Available time blocks for selected date
  final Map<String, TextEditingController> _questionControllers = {}; // ✅ Answers for custom questions
  final Map<ServiceItem, TextEditingController> _serviceQuantityControllers = {}; // ✅ Quantity input controllers for each service
  
  // ✅ Track selected services with quantities
  final Map<ServiceItem, int> _selectedServicesQuantity = {};

  // Guard to prevent double-submission (e.g. double-tap during async guard)
  bool _isSubmitting = false;

  @override
  void dispose() {
    _guestsController.dispose();
    _guestsInputController.dispose();
    _questionControllers.values.forEach((c) => c.dispose());
    _serviceQuantityControllers.values.forEach((c) => c.dispose());
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _guestsController = TextEditingController(text: _numberOfGuests.toString());
    _guestsInputController = TextEditingController(text: _numberOfGuests.toString());
    _initQuestionControllers();
    context
        .read<BookingBloc>()
        .add(GetBookedDatesEvent(listingId: widget.listing.id));
  }

  void _initQuestionControllers() {
    _questionControllers.clear();
    if (widget.listing.enableCustomQuestions && widget.listing.customQuestions.isNotEmpty) {
      for (final q in widget.listing.customQuestions) {
        _questionControllers[q] = TextEditingController();
      }
    }
  }

  double get _calculatedTotal {
    double total = 0;
    _selectedServicesQuantity.forEach((service, quantity) {
      total += service.price * quantity;
    });
    return total;
  }

  void _submitBooking() {
    if (_isSubmitting) return;
    if (_selectedDateRange == null) {
      showAlertDialog(context, 'Select dates'.tr(), 'Please select check-in and check-out dates.'.tr());
      return;
    }

    // Check if time block is required but not selected
    if (widget.listing.useTimeBlocks && _selectedTimeBlock == null) {
      showAlertDialog(context, 'Select time block'.tr(), 'Please select a time slot for your booking.'.tr());
      return;
    }

    setState(() => _isSubmitting = true);
    // Run the booking access guard before submitting.
    _runGuardThenSubmit();
  }

  Future<void> _runGuardThenSubmit() async {
    final allowed = await checkAndHandleBookingAccess(
      context: context,
      listerId: widget.listing.authorID,
    );
    if (!allowed || !mounted) {
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }
    _doSubmitBooking();
  }

  void _doSubmitBooking() {

    // Build description of selected services
    String servicesNotes = '';
    if (_selectedServicesQuantity.isNotEmpty) {
      servicesNotes = '\n\nSelected Services:\n' + 
          _selectedServicesQuantity.entries.map((e) => '- ${e.value}x ${e.key.name} (${e.key.price} ${widget.listing.currencyCode} each)').join('\n');
    }

    final booking = BookingModel(
      listingId: widget.listing.id,
      listingTitle: widget.listing.title,
      listingPhoto: widget.listing.photo,
      listersUserId: widget.listing.authorID,
      listersName: widget.listing.authorName,
      listersEmail: widget.listing.email,
      customerId: widget.currentUser.userID,
      customerName: widget.currentUser.fullName(),
      customerEmail: widget.currentUser.email,
      customerPhone: widget.currentUser.phoneNumber ?? '',
      checkInDate: _selectedDateRange!.checkIn,
      checkOutDate: _selectedDateRange!.checkOut,
      numberOfGuests: _numberOfGuests,
      guestNotes: _notesController.text.trim() + servicesNotes,
      timeBlock: _selectedTimeBlock ?? '', // ✅ Include selected time block
      totalPrice: _calculatedTotal,
      currency: widget.listing.currencyCode,
      customAnswers: widget.listing.enableCustomQuestions
          ? _questionControllers.map((k, v) => MapEntry(k, v.text.trim()))
          : {},
        listingAcceptsProofOfPayment:
          widget.listing.payments['acceptProofOfPayment'] == true,
      requesterPhoneVerified: widget.currentUser.phoneVerified,
    );

    context.read<BookingBloc>().add(CreateBookingEvent(booking: booking));
  }

  void _loadAvailableTimeBlocks(DateTime date) async {
    // Start with all configured time blocks
    List<String> available = List.from(widget.listing.timeBlocks);

    // Filter out past time blocks when selecting today's date
    final today = DateUtils.dateOnly(DateTime.now());
    final selectedDate = DateUtils.dateOnly(date);
    if (selectedDate == today) {
      final now = DateTime.now();
      available = available.where((block) {
        final startTime = _parseTimeBlockStart(block, selectedDate);
        if (startTime == null) {
          return true;
        }
        return !startTime.isBefore(now);
      }).toList();
    }

    // TODO: Fetch bookings for this date and remove booked time blocks
    // This would require a backend query to get bookings for the specific date
    // For now, we'll show all time blocks
    // In a real implementation, you'd query bookings for this date and filter out booked slots

    setState(() {
      _availableTimeBlocks = available;
    });
  }

  DateTime? _parseTimeBlockStart(String block, DateTime date) {
    try {
      final parts = block.split('-');
      if (parts.isEmpty) {
        return null;
      }
      final time = parts.first.trim();
      final timeParts = time.split(':');
      if (timeParts.length < 2) {
        return null;
      }
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return BlocListener<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is BookedDatesLoadedState) {
          if (mounted) {
            setState(() {
              _bookedDates = state.bookedDates;
            });
          }
        } else if (state is BookingCreatedState) {
          if (mounted) {
            Navigator.pop(context, true);
            showAlertDialog(
              context,
              'Booking sent'.tr(),
              'Your booking request has been sent to the lister. You will be notified once they respond.'.tr(),
            );
          }
        } else if (state is BookingErrorState) {
          if (mounted) {
            showAlertDialog(context, 'Error'.tr(), state.errorMessage);
          }
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book Appointment'.tr(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.listing.title,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(colorPrimary),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                // ✅ Service Menu Section
                if (widget.listing.services.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Select Services'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: dark ? Colors.black26 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: dark ? Colors.grey.shade800 : Colors.grey.shade200),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.listing.services.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: dark ? Colors.grey.shade800 : Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final service = widget.listing.services[index];
                        final isSelected = _selectedServicesQuantity.containsKey(service);
                        final quantity = _selectedServicesQuantity[service] ?? 1;
                        final maxQuantity = service.quantity > 0
                            ? service.quantity
                            : 1;
                        
                        return Container(
                          color: isSelected ? (dark ? Colors.grey.shade800.withOpacity(0.5) : Colors.blue.shade50) : Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Column(
                            children: [
                              // Service info row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Checkbox
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedServicesQuantity[service] = 1;
                                        } else {
                                          _selectedServicesQuantity.remove(service);
                                        }
                                      });
                                    },
                                    activeColor: Color(colorPrimary),
                                    checkColor: Colors.white,
                                    side: BorderSide(
                                      color: dark ? Colors.grey.shade600 : Colors.grey.shade400,
                                      width: 2,
                                    ),
                                  ),
                                  // Service name, duration, price
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            service.name,
                                            style: TextStyle(
                                              color: dark ? Colors.white : Colors.black87,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (service.duration.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              '${service.duration} • ${service.price} ${widget.listing.currencyCode}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ] else
                                            Text(
                                              '${service.price} ${widget.listing.currencyCode}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Quantity controls row (if selected and quantity enabled)
                              if (isSelected && widget.listing.allowQuantitySelection) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      '${'Qty'.tr()}: ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: quantity > 1 ? () {
                                          setState(() {
                                            _selectedServicesQuantity[service] = quantity - 1;
                                            _serviceQuantityControllers[service]?.text = (quantity - 1).toString();
                                          });
                                        } : null,
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.remove,
                                            size: 14,
                                            color: quantity > 1 ? Color(colorPrimary) : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 48,
                                      child: TextFormField(
                                        controller: _serviceQuantityControllers.putIfAbsent(service, () => TextEditingController(text: quantity.toString())),
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                          isDense: true,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: dark ? Colors.white : Colors.black,
                                        ),
                                        onChanged: (value) {
                                          if (value.isNotEmpty) {
                                            int? newValue = int.tryParse(value);
                                            if (newValue != null && newValue > 0 && newValue <= maxQuantity) {
                                              setState(() {
                                                _selectedServicesQuantity[service] = newValue;
                                              });
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: quantity < maxQuantity ? () {
                                          setState(() {
                                            _selectedServicesQuantity[service] = quantity + 1;
                                            _serviceQuantityControllers[service]?.text = (quantity + 1).toString();
                                          });
                                        } : null,
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.add,
                                            size: 14,
                                            color: quantity < maxQuantity ? Color(colorPrimary) : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '${'Subtotal'.tr()}: ${(service.price * quantity).toStringAsFixed(2)} ${widget.listing.currencyCode} • ${'Max'.tr()}: $maxQuantity',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(colorPrimary),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                Text(
                  'Select dates'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: dark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: BlocBuilder<BookingBloc, BookingState>(
                    builder: (context, state) {
                      if (state is BookingLoading && _bookedDates.isEmpty) {
                        return const SizedBox(
                          height: 300,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      return DateRangePickerWidget(
                        bookedDates: _bookedDates,
                        onDateRangeSelected: (dateRange) {
                          if (mounted) {
                            setState(() {
                              _selectedDateRange = dateRange;
                              // Reset time block when date changes
                              _selectedTimeBlock = null;
                              // Load available time blocks for this date if using time blocks
                              if (widget.listing.useTimeBlocks) {
                                _loadAvailableTimeBlocks(dateRange.checkIn);
                              }
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
                if (widget.listing.useTimeBlocks && _selectedDateRange != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Select time slot'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_availableTimeBlocks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'No time slots available for this date'.tr(),
                        style: TextStyle(
                          color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableTimeBlocks.map((block) {
                        final isSelected = _selectedTimeBlock == block;
                        return ChoiceChip(
                          label: Text(_formatTimeBlockForDisplay(block)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedTimeBlock = selected ? block : null;
                            });
                          },
                          selectedColor: Color(colorPrimary).withOpacity(0.3),
                          backgroundColor: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Color(colorPrimary)
                                : (dark ? Colors.white : Colors.black87),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Number of guests'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, color: dark ? Colors.white : Colors.black),
                      onPressed: _numberOfGuests > 1
                          ? () => setState(() {
                                _numberOfGuests--;
                                _guestsInputController.text = _numberOfGuests.toString();
                              })
                          : null,
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _guestsInputController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: dark ? Colors.white : Colors.black,
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            int? newValue = int.tryParse(value);
                            if (newValue != null && newValue > 0) {
                              setState(() {
                                _numberOfGuests = newValue;
                              });
                            }
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, color: dark ? Colors.white : Colors.black),
                      onPressed: () => setState(() {
                            _numberOfGuests++;
                            _guestsInputController.text = _numberOfGuests.toString();
                          }),
                    ),
                  ],
                ),
                if (widget.listing.enableCustomQuestions && widget.listing.customQuestions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Custom questions'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.listing.customQuestions.map((q) {
                    final controller = _questionControllers[q]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: dark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: controller,
                            maxLines: 2,
                            style: TextStyle(color: dark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              hintText: 'Type your answer'.tr(),
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: dark ? Colors.grey.shade700 : Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: dark ? Colors.grey.shade800 : Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
                const SizedBox(height: 20),
                Text(
                  'Notes for the lister'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Any special requests...'.tr(),
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: dark ? Colors.grey.shade700 : Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: dark ? Colors.grey.shade800 : Colors.grey.shade50,
                  ),
                ),
                
                // ✅ Total Price Summary
                if (_calculatedTotal > 0) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(colorPrimary).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Amount:'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: dark ? Colors.white : Colors.black)),
                        Text(
                          '${_calculatedTotal.toStringAsFixed(2)} ${widget.listing.currencyCode}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(colorPrimary), fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                BlocBuilder<BookingBloc, BookingState>(
                  builder: (context, state) {
                    final isLoading = state is BookingLoading;
                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isLoading ? null : () => Navigator.pop(context),
                            child: Text('Cancel'.tr(), style: TextStyle(color: dark ? Colors.white : Colors.black)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading || _isSubmitting || _selectedDateRange == null
                                ? null
                                : _submitBooking,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(colorPrimary),
                              foregroundColor: Colors.white,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : Text('Confirm'.tr()),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeBlockForDisplay(String block) {
    try {
      final parts = block.split('-');
      if (parts.length != 2) return block;

      String formatTime(String value) {
        final timeParts = value.trim().split(':');
        if (timeParts.length < 2) return value;

        final hour24 = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final period = hour24 >= 12 ? 'PM' : 'AM';
        final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
        return '$hour12:${minute.toString().padLeft(2, '0')} $period';
      }

      return '${formatTime(parts[0])} - ${formatTime(parts[1])}';
    } catch (_) {
      return block;
    }
  }
}
