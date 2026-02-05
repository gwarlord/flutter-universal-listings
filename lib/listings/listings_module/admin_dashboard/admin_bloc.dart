import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/model/suspension_info.dart';
import 'package:instaflutter/listings/listings_module/api/listings_repository.dart';
import 'package:instaflutter/listings/ui/profile/api/profile_repository.dart';

part 'admin_event.dart';

part 'admin_state.dart';

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final ListingsRepository listingsRepository;
  final ProfileRepository profileRepository;
  final ListingsUser currentUser;
  List<ListingsUser> suspendedUsers = [];
  List<ListingsUser> allUsers = [];
  List<ListingModel> suspendedListings = [];
  List<ListingModel> allListings = [];

  AdminBloc({
    required this.listingsRepository,
    required this.currentUser,
    required this.profileRepository,
  }) : super(AdminInitial()) {
    on<GetSuspendedUsersEvent>((event, emit) async {
      suspendedUsers = await profileRepository.getSuspendedUsers();
      emit(SuspendedUsersState(suspendedUsers: suspendedUsers));
    });

    on<GetAllUsersEvent>((event, emit) async {
      allUsers = await profileRepository.getAllUsers(searchQuery: event.searchQuery);
      emit(AllUsersState(users: allUsers));
    });

    on<GetSuspendedListingsEvent>((event, emit) async {
      suspendedListings = await listingsRepository.getSuspendedListings();
      emit(SuspendedListingsState(suspendedListings: suspendedListings));
    });

    on<GetAllListingsEvent>((event, emit) async {
      allListings = await listingsRepository.getListings(favListingsIDs: currentUser.likedListingsIDs);
      emit(AllListingsState(listings: allListings));
    });

    on<SuspendUserEvent>((event, emit) async {
      await profileRepository.suspendUser(
        user: event.user,
        suspensionInfo: event.suspensionInfo,
        adminId: currentUser.userID,
      );
      if (!suspendedUsers.any((u) => u.userID == event.user.userID)) {
        suspendedUsers.add(event.user);
      }
      allUsers.removeWhere((u) => u.userID == event.user.userID);
      emit(AllUsersState(users: allUsers));
    });

    on<UnsuspendUserEvent>((event, emit) async {
      await profileRepository.unsuspendUser(
        user: event.user,
        adminId: currentUser.userID,
      );
      suspendedUsers.removeWhere((u) => u.userID == event.user.userID);
      if (!allUsers.any((u) => u.userID == event.user.userID)) {
        allUsers.add(event.user);
      }
      emit(SuspendedUsersState(suspendedUsers: suspendedUsers));
    });

    on<SuspendListingEvent>((event, emit) async {
      try {
        debugPrint('[AdminBloc] SuspendListingEvent START: ${event.listing.id}');
        await listingsRepository.suspendListing(
          listing: event.listing,
          suspensionInfo: event.suspensionInfo,
          adminId: currentUser.userID,
        );
        debugPrint('[AdminBloc] SuspendListingEvent: Firestore update completed');
        event.listing.suspensionInfo = event.suspensionInfo;
        // Update the listing's suspended property
        event.listing.suspended = true;
        if (!suspendedListings.any((l) => l.id == event.listing.id)) {
          suspendedListings.add(event.listing);
        }
        allListings.removeWhere((l) => l.id == event.listing.id);
        debugPrint('[AdminBloc] SuspendListingEvent: Emitting AllListingsState');
        emit(AllListingsState(listings: allListings));
        debugPrint('[AdminBloc] SuspendListingEvent COMPLETE: ${event.listing.id}');
      } catch (e, stackTrace) {
        debugPrint('[AdminBloc] SuspendListingEvent ERROR: $e');
        debugPrint('[AdminBloc] Stack trace: $stackTrace');
      }
    });

    on<UnsuspendListingEvent>((event, emit) async {
      try {
        debugPrint('[AdminBloc] UnsuspendListingEvent START: ${event.listing.id}');
        await listingsRepository.unsuspendListing(
          listing: event.listing,
          adminId: currentUser.userID,
        );
        debugPrint('[AdminBloc] UnsuspendListingEvent: Firestore update completed');
        if (event.listing.suspensionInfo != null) {
          event.listing.suspensionInfo = event.listing.suspensionInfo!.copyWith(
            isSuspended: false,
            unsuspendedAt: DateTime.now(),
            unsuspendedBy: currentUser.userID,
          );
        }
        // Update the listing's suspended property
        event.listing.suspended = false;
        suspendedListings.removeWhere((l) => l.id == event.listing.id);
        if (!allListings.any((l) => l.id == event.listing.id)) {
          allListings.add(event.listing);
        }
        debugPrint('[AdminBloc] UnsuspendListingEvent: Emitting AllListingsState');
        emit(AllListingsState(listings: allListings));
        debugPrint('[AdminBloc] UnsuspendListingEvent COMPLETE: ${event.listing.id}');
      } catch (e, stackTrace) {
        debugPrint('[AdminBloc] UnsuspendListingEvent ERROR: $e');
        debugPrint('[AdminBloc] Stack trace: $stackTrace');
      }
    });

    on<LoadingEvent>((event, emit) => emit(LoadingState()));
  }
}
