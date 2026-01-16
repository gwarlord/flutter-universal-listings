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
  final List<DateTime> bookedDates;

  const BookingRequestDialog({
    super.key,
    required this.listing,
    required this.currentUser,
    this.bookedDates = const [],
  });

  @override
  State<BookingRequestDialog> createState() => _BookingRequestDialogState();
}

class _BookingRequestDialogState extends State<BookingRequestDialog> {
  DateRange? _selectedDateRange;
  int _numberOfGuests = 1;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _submitBooking() {
    if (_selectedDateRange == null) {
      showAlertDialog(context, 'Select dates'.tr(), 'Please select check-in and check-out dates.'.tr());
      return;
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
      guestNotes: _notesController.text.trim(),
      totalPrice: 0, // To be calculated by lister or admin
      currency: widget.listing.currencyCode,
    );

    context.read<BookingBloc>().add(CreateBookingEvent(booking: booking));
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return BlocListener<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is BookingCreatedState) {
          Navigator.pop(context, true);
          showAlertDialog(
            context,
            'Booking sent'.tr(),
            'Your booking request has been sent to the lister. You will be notified once they respond.'.tr(),
          );
        } else if (state is BookingErrorState) {
          showAlertDialog(context, 'Error'.tr(), state.errorMessage);
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
                  'Request booking'.tr(),
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
                  child: DateRangePickerWidget(
                    bookedDates: widget.bookedDates,
                    onDateRangeSelected: (dateRange) {
                      setState(() => _selectedDateRange = dateRange);
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
                                : Text('Request booking'.tr()),
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
