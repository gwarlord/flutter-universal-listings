import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:caribtap/listings/model/payment_details_model.dart';
import 'package:caribtap/listings/services/payment_details_service.dart';
import 'package:caribtap/listings/services/entitlement_service.dart';

part 'payment_details_state.dart';

class PaymentDetailsCubit extends Cubit<PaymentDetailsState> {
  final PaymentDetailsService paymentDetailsService;
  final EntitlementService entitlementService;
  final String userId;
  final bool isAdmin;

  StreamSubscription<PaymentDetailsProfile>? _profileStreamSub;

  PaymentDetailsCubit({
    required this.paymentDetailsService,
    required this.entitlementService,
    required this.userId,
    this.isAdmin = false,
  }) : super(const PaymentDetailsState.initial());

  /// Start listening to payment details updates
  void startListening() {
    debugPrint('🔊 PaymentDetailsCubit: Starting to listen');
    _profileStreamSub?.cancel();

    _profileStreamSub = paymentDetailsService.streamProfile(userId).listen(
      (profile) {
        debugPrint('📨 PaymentDetailsCubit received update');
        emit(PaymentDetailsState.loaded(profile));
      },
      onError: (error, stackTrace) {
        debugPrint('❌ Error in payment details stream: $error\n$stackTrace');
        emit(PaymentDetailsState.error(error.toString()));
      },
    );
  }

  /// Stop listening to updates
  void stopListening() {
    debugPrint('🔇 PaymentDetailsCubit: Stopping listener');
    _profileStreamSub?.cancel();
  }

  /// Load payment details once
  Future<void> loadOnce() async {
    debugPrint('🔄 PaymentDetailsCubit: Loading once');
    emit(const PaymentDetailsState.loading());

    try {
      final profile = await paymentDetailsService.getProfile(userId);
      emit(PaymentDetailsState.loaded(profile));
    } catch (e) {
      debugPrint('❌ Error loading payment details: $e');
      emit(PaymentDetailsState.error(e.toString()));
    }
  }

  /// Save payment details profile
  Future<void> saveProfile(PaymentDetailsProfile profile) async {
    debugPrint('💾 PaymentDetailsCubit: Saving profile');
    emit(PaymentDetailsState.saving(profile));

    try {
      // Check entitlement
      final entitlement = await entitlementService.fetchEntitlement(userId);
      final isPro = entitlement?.isActive == true && (entitlement?.tier ?? 0) >= 2;

      if (!isPro) {
        emit(PaymentDetailsState.error(
          'Payment details feature requires Professional tier or higher',
          profile,
        ));
        return;
      }

      await paymentDetailsService.saveProfile(userId, profile);
      debugPrint('✅ PaymentDetailsCubit: Profile saved successfully');
      emit(PaymentDetailsState.saved(profile));
    } catch (e) {
      debugPrint('❌ Error saving payment details: $e');
      emit(PaymentDetailsState.error(e.toString(), profile));
    }
  }

  /// Check if user has Pro tier access
  /// Admins automatically have access to all features
  Future<bool> checkProAccess() async {
    if (isAdmin) {
      debugPrint('✅ Admin user has automatic access to payment details');
      return true;
    }
    
    try {
      final entitlement = await entitlementService.fetchEntitlement(userId);
      return entitlement?.isActive == true && (entitlement?.tier ?? 0) >= 2;
    } catch (e) {
      debugPrint('❌ Error checking entitlement: $e');
      return false;
    }
  }

  /// Update a specific field in the current profile
  void updateField(PaymentDetailsProfile Function(PaymentDetailsProfile) updater) {
    final currentState = state;
    if (currentState is PaymentDetailsLoaded) {
      final updatedProfile = updater(currentState.profile);
      emit(PaymentDetailsState.loaded(updatedProfile));
    }
  }

  @override
  Future<void> close() {
    debugPrint('🚫 PaymentDetailsCubit: Closing');
    _profileStreamSub?.cancel();
    return super.close();
  }
}
