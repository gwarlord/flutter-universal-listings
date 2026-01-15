part of 'admin_bloc.dart';

abstract class AdminState {}

class AdminInitial extends AdminState {}

class SuspendedUsersState extends AdminState {
  List<ListingsUser> suspendedUsers;

  SuspendedUsersState({required this.suspendedUsers});
}

class AllUsersState extends AdminState {
  List<ListingsUser> users;

  AllUsersState({required this.users});
}

class SuspendedListingsState extends AdminState {
  List<ListingModel> suspendedListings;

  SuspendedListingsState({required this.suspendedListings});
}

class AllListingsState extends AdminState {
  List<ListingModel> listings;

  AllListingsState({required this.listings});
}

class LoadingState extends AdminState {}
