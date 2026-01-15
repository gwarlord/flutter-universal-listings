import 'dart:io';

import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/ui/profile/api/profile_repository.dart';

class ProfileCustomBackendUtils extends ProfileRepository {
  @override
  updateCurrentUser(ListingsUser currentUser) {
    // TODO: implement updateCurrentUser
    throw UnimplementedError();
  }

  @override
  Future<String> uploadUserImageToServer(
      {required File image, required String userID}) {
    // TODO: implement uploadUserImageToServer
    throw UnimplementedError();
  }

  @override
  deleteImageFromStorage(String imageURL) {
    // TODO: implement deleteImageFromStorage
    throw UnimplementedError();
  }

  @override
  deleteUser({required ListingsUser user}) {
    // TODO: implement deleteUser
    throw UnimplementedError();
  }

  @override
  Future<List<ListingsUser>> getSuspendedUsers() {
    // TODO: implement getSuspendedUsers
    throw UnimplementedError();
  }

  @override
  Future<void> suspendUser({required ListingsUser user}) {
    // TODO: implement suspendUser
    throw UnimplementedError();
  }

  @override
  Future<void> unsuspendUser({required ListingsUser user}) {
    // TODO: implement unsuspendUser
    throw UnimplementedError();
  }

  @override
  Future<List<ListingsUser>> getAllUsers({String? searchQuery}) {
    // TODO: implement getAllUsers
    throw UnimplementedError();
  }
}
