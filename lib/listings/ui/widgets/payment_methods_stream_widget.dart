import 'package:flutter/material.dart';
import 'package:caribtap/listings/model/payment_details_model.dart';
import 'package:caribtap/listings/services/payment_details_service.dart';
import 'package:caribtap/listings/ui/widgets/payment_methods_widget.dart';

/// Stream builder wrapper for displaying payment methods
/// Automatically fetches and displays public payment details if available
class PaymentMethodsStreamWidget extends StatelessWidget {
  final String userId;
  final PaymentDetailsService? paymentDetailsService;

  const PaymentMethodsStreamWidget({
    super.key,
    required this.userId,
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
        
        // Only show if there are payment methods available
        if (!paymentDetails.hasAnyPaymentMethod) {
          return const SizedBox.shrink();
        }

        return PaymentMethodsWidget(paymentDetails: paymentDetails);
      },
    );
  }
}
