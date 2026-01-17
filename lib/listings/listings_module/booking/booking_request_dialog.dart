import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/listings_module/api/booking_api_manager.dart';
import 'package:instaflutter/listings/listings_module/booking/booking_bloc.dart';
import 'package:instaflutter/listings/listings_module/booking/booking_event.dart';
import 'package:instaflutter/listings/listings_module/booking/booking_state.dart';
import 'package:instaflutter/listings/listings_module/booking/widgets/date_range_picker.dart';
import 'package:instaflutter/listings/model/booking_model.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';

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
  final TextEditingController _notesController = TextEditingController();
  List<DateTime> _bookedDates = [];
  
  // ✅ Track selected services
  final List<ServiceItem> _selectedServices = [];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _calculatedTotal {
    double total = 0;
    for (var service in _selectedServices) {
      total += service.price;
    }
    return total;
  }

  void _submitBooking() {
    if (_selectedDateRange == null) {
      showAlertDialog(context, 'Select dates'.tr(), 'Please select check-in and check-out dates.'.tr());
      return;
    }

    // Build description of selected services
    String servicesNotes = '';
    if (_selectedServices.isNotEmpty) {
      servicesNotes = '\n\nSelected Services:\n' + 
          _selectedServices.map((s) => '- ${s.name} (${s.price} ${widget.listing.currencyCode})').join('\n');
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
      totalPrice: _calculatedTotal, 
      currency: widget.listing.currencyCode,
    );

    context.read<BookingBloc>().add(CreateBookingEvent(booking: booking));
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
                        final isSelected = _selectedServices.contains(service);
                        return CheckboxListTile(
                          dense: true,
                          activeColor: Color(colorPrimary),
                          title: Text(service.name, style: TextStyle(color: dark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
                          subtitle: service.duration.isNotEmpty ? Text(service.duration, style: const TextStyle(fontSize: 12)) : null,
                          secondary: Text(
                            '${service.price} ${widget.listing.currencyCode}',
                            style: TextStyle(color: Color(colorPrimary), fontWeight: FontWeight.bold),
                          ),
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedServices.add(service);
                              } else {
                                _selectedServices.remove(service);
                              }
                            });
                          },
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
                            setState(() => _selectedDateRange = dateRange);
                          }
                        },
                      );
                    },
                  ),
                ),
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
                      icon: const Icon(Icons.remove),
                      onPressed: _numberOfGuests > 1
                          ? () => setState(() => _numberOfGuests--)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _numberOfGuests.toString(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => _numberOfGuests++),
                    ),
                  ],
                ),
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
                  decoration: InputDecoration(
                    hintText: 'Any special requests...'.tr(),
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
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
                        Text('Total Amount:'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                            child: Text('Cancel'.tr()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading || _selectedDateRange == null
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
}
