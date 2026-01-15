import 'package:bloc/bloc.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
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
      await profileRepository.suspendUser(user: event.user);
      if (!suspendedUsers.any((u) => u.userID == event.user.userID)) {
        suspendedUsers.add(event.user);
      }
      allUsers.removeWhere((u) => u.userID == event.user.userID);
      emit(AllUsersState(users: allUsers));
    });

    on<UnsuspendUserEvent>((event, emit) async {
      await profileRepository.unsuspendUser(user: event.user);
      suspendedUsers.removeWhere((u) => u.userID == event.user.userID);
      if (!allUsers.any((u) => u.userID == event.user.userID)) {
        allUsers.add(event.user);
      }
      emit(SuspendedUsersState(suspendedUsers: suspendedUsers));
    });

    on<SuspendListingEvent>((event, emit) async {
      await listingsRepository.suspendListing(listing: event.listing);
      if (!suspendedListings.any((l) => l.id == event.listing.id)) {
        suspendedListings.add(event.listing);
      }
      allListings.removeWhere((l) => l.id == event.listing.id);
      emit(AllListingsState(listings: allListings));
    });

    on<UnsuspendListingEvent>((event, emit) async {
      await listingsRepository.unsuspendListing(listing: event.listing);
      suspendedListings.removeWhere((l) => l.id == event.listing.id);
      emit(SuspendedListingsState(suspendedListings: suspendedListings));
    });

    on<LoadingEvent>((event, emit) => emit(LoadingState()));
  }
}
