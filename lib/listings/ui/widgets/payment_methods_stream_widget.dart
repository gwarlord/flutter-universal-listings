import 'package:flutter/material.dart';
import 'package:caribtap/listings/model/payment_details_model.dart';
import 'package:caribtap/listings/services/payment_details_service.dart';
import 'package:caribtap/listings/ui/widgets/payment_methods_widget.dart';

/// Stream builder wrapper for displaying payment methods
/// Automatically fetches and displays public payment details if available
class PaymentMethodsStreamWidget extends StatelessWidget {
  final String userId;
  final String? listingId;
  final PaymentDetailsService? paymentDetailsService;

  const PaymentMethodsStreamWidget({
    super.key,
    required this.userId,
    this.listingId,
    this.paymentDetailsService,
  });

  @override
  Widget build(BuildContext context) {
    final service = paymentDetailsService ?? PaymentDetailsService();

    return StreamBuilder<PaymentDetailsPublic>(
      stream: service.streamPublic(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final paymentDetails = snapshot.data!;

        if (!paymentDetails.hasAnyPaymentMethod) {
          return const SizedBox.shrink();
        }

        if (listingId != null) {
          if (paymentDetails.displayMode != PaymentDisplayMode.publicListing) {
            return const SizedBox.shrink();
          }

          // Empty selection means legacy "show on all listings" behavior.
          if (paymentDetails.selectedListingIds.isNotEmpty &&
              !paymentDetails.selectedListingIds.contains(listingId)) {
            return const SizedBox.shrink();
          }
        } else if (paymentDetails.displayMode == PaymentDisplayMode.private) {
          return const SizedBox.shrink();
        }

        return PaymentMethodsWidget(paymentDetails: paymentDetails);
      },
    );
  }
}
