part of 'admin_bloc.dart';

abstract class AdminEvent {}

class GetSuspendedUsersEvent extends AdminEvent {}

class GetAllUsersEvent extends AdminEvent {
  String? searchQuery;
  
  GetAllUsersEvent({this.searchQuery});
}

class GetSuspendedListingsEvent extends AdminEvent {}

class GetReportedListingsEvent extends AdminEvent {}

class GetAllListingsEvent extends AdminEvent {}

class LoadingEvent extends AdminEvent {}

class SuspendUserEvent extends AdminEvent {
  ListingsUser user;
  SuspensionInfo? suspensionInfo;

  SuspendUserEvent({required this.user, this.suspensionInfo});
}

class UnsuspendUserEvent extends AdminEvent {
  ListingsUser user;

  UnsuspendUserEvent({required this.user});
}

class SuspendListingEvent extends AdminEvent {
  ListingModel listing;
  SuspensionInfo? suspensionInfo;

  SuspendListingEvent({required this.listing, this.suspensionInfo});
}

class UnsuspendListingEvent extends AdminEvent {
  ListingModel listing;

  UnsuspendListingEvent({required this.listing});
}
