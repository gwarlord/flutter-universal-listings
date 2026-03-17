import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/listings_module/api/collaboration_repository.dart';
import 'package:caribtap/listings/model/collaboration_model.dart';

class CollaborationFirebase extends CollaborationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  final List<StreamSubscription> _subscriptions = [];

  String _buildCollaboratorDisplayName(
    Map<String, dynamic>? userData,
    String fallbackUid,
  ) {
    if (userData == null) return fallbackUid;

    final firstName = (userData['firstName'] ?? '').toString().trim();
    final lastName = (userData['lastName'] ?? '').toString().trim();
    final email = (userData['email'] ?? '').toString().trim();

    final fullName = [firstName, lastName]
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim();

    final normalizedName = fullName.toLowerCase();
    if (fullName.isNotEmpty && normalizedName != 'user') {
      return fullName;
    }

    if (email.isNotEmpty) {
      return email;
    }

    return fallbackUid;
  }

  // ========================================================================
  // COLLABORATOR MANAGEMENT
  // ========================================================================

  @override
  Future<String> addListingCollaborator({
    required String listingId,
    required String collaboratorEmailOrUid,
    required CollaboratorPermissions permissions,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('addListingCollaborator')
          .call({
        'listingId': listingId,
        'collaboratorEmailOrUid': collaboratorEmailOrUid,
        'permissions': permissions.toJson(),
      });

      final data = result.data as Map<String, dynamic>;
      return data['collaboratorUid'] as String;
    } catch (e, s) {
      debugPrint('CollaborationFirebase.addListingCollaborator error: $e $s');
      rethrow;
    }
  }

  @override
  Future<void> removeListingCollaborator({
    required String listingId,
    required String collaboratorUid,
  }) async {
    try {
      await _functions.httpsCallable('removeListingCollaborator').call({
        'listingId': listingId,
        'collaboratorUid': collaboratorUid,
      });
    } catch (e, s) {
      debugPrint('CollaborationFirebase.removeListingCollaborator error: $e $s');
      rethrow;
    }
  }

  @override
  Future<void> updateListingCollaboratorPermissions({
    required String listingId,
    required String collaboratorUid,
    required CollaboratorPermissions permissions,
  }) async {
    try {
      await _functions
          .httpsCallable('updateListingCollaboratorPermissions')
          .call({
        'listingId': listingId,
        'collaboratorUid': collaboratorUid,
        'permissions': permissions.toJson(),
      });
    } catch (e, s) {
      debugPrint(
        'CollaborationFirebase.updateListingCollaboratorPermissions error: $e $s',
      );
      rethrow;
    }
  }

  @override
  Future<List<CollaboratorModel>> getListingCollaborators({
    required String listingId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('collaborators')
          .where('isActive', isEqualTo: true)
          .get();

      final collaborators = <CollaboratorModel>[];
      for (var doc in snapshot.docs) {
        try {
          final userDoc = await _firestore.collection('users').doc(doc.id).get();
          collaborators.add(
            CollaboratorModel.fromJson(
              doc.id,
              doc.data(),
              displayName: _buildCollaboratorDisplayName(
                userDoc.data(),
                doc.id,
              ),
              profilePictureUrl: userDoc.data()?['profilePictureURL'],
            ),
          );
        } catch (e) {
          debugPrint('Error loading collaborator user data: $e');
          collaborators.add(
            CollaboratorModel.fromJson(doc.id, doc.data()),
          );
        }
      }

      return collaborators;
    } catch (e, s) {
      debugPrint('CollaborationFirebase.getListingCollaborators error: $e $s');
      return [];
    }
  }

  @override
  Stream<List<CollaboratorModel>> streamListingCollaborators({
    required String listingId,
  }) {
    final controller = StreamController<List<CollaboratorModel>>();

    final subscription = _firestore
        .collection('listings')
        .doc(listingId)
        .collection('collaborators')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) async {
        try {
          final collaborators = <CollaboratorModel>[];
          for (var doc in snapshot.docs) {
            try {
              final userDoc =
                  await _firestore.collection('users').doc(doc.id).get();
              collaborators.add(
                CollaboratorModel.fromJson(
                  doc.id,
                  doc.data(),
                  displayName: _buildCollaboratorDisplayName(
                    userDoc.data(),
                    doc.id,
                  ),
                  profilePictureUrl: userDoc.data()?['profilePictureURL'],
                ),
              );
            } catch (e) {
              collaborators.add(
                CollaboratorModel.fromJson(doc.id, doc.data()),
              );
            }
          }
          if (!controller.isClosed) {
            controller.add(collaborators);
          }
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
      onDone: () {
        controller.close();
      },
    );

    _subscriptions.add(subscription);
    return controller.stream;
  }

  // ========================================================================
  // ACTIVITY LOG
  // ========================================================================

  @override
  Future<List<ActivityLogEntry>> getActivityLog({
    required String listingId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('activity')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final entries = <ActivityLogEntry>[];
      for (var doc in snapshot.docs) {
        final entry = ActivityLogEntry.fromJson(doc.id, doc.data());

        // 1. Resolve Actor Name
        if (entry.actorName == null || entry.actorName!.isEmpty || entry.actorName == entry.actorUid) {
          try {
            final userDoc = await _firestore.collection('users').doc(entry.actorUid).get();
            entry.actorName = _buildCollaboratorDisplayName(userDoc.data(), entry.actorUid);
          } catch (_) {}
        }

        // 2. Resolve Target Name (if target is a collaborator/user)
        if (entry.targetType == 'COLLABORATOR' && (entry.targetName == null || entry.targetName!.isEmpty || entry.targetName == entry.targetId)) {
          try {
            final targetUserDoc = await _firestore.collection('users').doc(entry.targetId).get();
            entry.targetName = _buildCollaboratorDisplayName(targetUserDoc.data(), entry.targetId);
          } catch (_) {}
        }

        entries.add(entry);
      }
      return entries;
    } catch (e, s) {
      debugPrint('CollaborationFirebase.getActivityLog error: $e $s');
      return [];
    }
  }

  @override
  Stream<List<ActivityLogEntry>> streamActivityLog({
    required String listingId,
    int limit = 50,
  }) {
    final controller = StreamController<List<ActivityLogEntry>>();

    final subscription = _firestore
        .collection('listings')
        .doc(listingId)
        .collection('activity')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .listen(
      (snapshot) async {
        try {
          final activityLog = <ActivityLogEntry>[];
          for (var doc in snapshot.docs) {
            final entry = ActivityLogEntry.fromJson(doc.id, doc.data());

            // 1. Resolve Actor Name
            if (entry.actorName == null || entry.actorName!.isEmpty || entry.actorName == entry.actorUid) {
              try {
                final userDoc = await _firestore.collection('users').doc(entry.actorUid).get();
                entry.actorName = _buildCollaboratorDisplayName(userDoc.data(), entry.actorUid);
              } catch (_) {}
            }

            // 2. Resolve Target Name (if target is a collaborator/user)
            if (entry.targetType == 'COLLABORATOR' && (entry.targetName == null || entry.targetName!.isEmpty || entry.targetName == entry.targetId)) {
              try {
                final targetUserDoc = await _firestore.collection('users').doc(entry.targetId).get();
                entry.targetName = _buildCollaboratorDisplayName(targetUserDoc.data(), entry.targetId);
              } catch (_) {}
            }

            activityLog.add(entry);
          }
          if (!controller.isClosed) {
            controller.add(activityLog);
          }
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
      onDone: () {
        controller.close();
      },
    );

    _subscriptions.add(subscription);
    return controller.stream;
  }

  @override
  Future<void> logActivity({
    required String listingId,
    required String actorUid,
    String? actorName,
    required String actorRole,
    required String actionType,
    required String targetType,
    required String targetId,
    String? targetName,
    String? note,
  }) async {
    try {
      await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('activity')
          .add({
        'actorUid': actorUid,
        'actorName': actorName,
        'actorRole': actorRole,
        'actionType': actionType,
        'targetType': targetType,
        'targetId': targetId,
        if (targetName != null) 'targetName': targetName,
        'listingId': listingId,
        if (note != null) 'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, s) {
      debugPrint('CollaborationFirebase.logActivity error: $e $s');
    }
  }

  // ========================================================================
  // ASSIGNED LISTINGS
  // ========================================================================

  @override
  Future<List<AssignedListingModel>> getAssignedListings({
    required String userId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('assignedListings')
          .where('isActive', isEqualTo: true)
          .get();

      final listings = <AssignedListingModel>[];
      for (var doc in snapshot.docs) {
        try {
          final listingId = doc.id;
          // Fetch the listing title from the listings collection
          final listingDoc =
              await _firestore.collection('listings').doc(listingId).get();
          final title = listingDoc.data()?['title'] ?? 'Listing';

          listings.add(
            AssignedListingModel.fromJson(
              listingId,
              doc.data(),
              title: title,
            ),
          );
        } catch (e) {
          // If we can't fetch the title, use the listingId as fallback
          listings.add(AssignedListingModel.fromJson(doc.id, doc.data()));
        }
      }

      return listings;
    } catch (e, s) {
      debugPrint('CollaborationFirebase.getAssignedListings error: $e $s');
      return [];
    }
  }

  @override
  Stream<List<AssignedListingModel>> streamAssignedListings({
    required String userId,
  }) {
    final controller = StreamController<List<AssignedListingModel>>();

    final subscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('assignedListings')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) async {
        try {
          final listings = <AssignedListingModel>[];
          for (var doc in snapshot.docs) {
            try {
              final listingId = doc.id;
              // Fetch the listing title from the listings collection
              final listingDoc = await _firestore
                  .collection('listings')
                  .doc(listingId)
                  .get();
              final title = listingDoc.data()?['title'] ?? 'Listing';
              
              listings.add(
                AssignedListingModel.fromJson(
                  listingId,
                  doc.data(),
                  title: title,
                ),
              );
            } catch (e) {
              // If we can't fetch the title, use the listingId as fallback
              listings.add(
                AssignedListingModel.fromJson(doc.id, doc.data()),
              );
            }
          }
          if (!controller.isClosed) {
            controller.add(listings);
          }
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
      onDone: () {
        controller.close();
      },
    );

    _subscriptions.add(subscription);
    return controller.stream;
  }

  // ========================================================================
  // LISTING CHAT
  // ========================================================================

  @override
  Future<void> createListingChat({
    required String listingId,
    required String ownerUid,
    required List<String> participantUids,
  }) async {
    try {
      await _firestore
          .collection('listing_chats')
          .doc('listing_$listingId')
          .set({
        'listingId': listingId,
        'ownerUid': ownerUid,
        'participantUids': participantUids,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, s) {
      debugPrint('CollaborationFirebase.createListingChat error: $e $s');
      rethrow;
    }
  }

  @override
  Future<ListingChat?> getListingChat({
    required String listingId,
  }) async {
    try {
      final doc = await _firestore
          .collection('listing_chats')
          .doc('listing_$listingId')
          .get();

      if (!doc.exists) return null;
      return ListingChat.fromJson(doc.id, doc.data() ?? {});
    } catch (e, s) {
      debugPrint('CollaborationFirebase.getListingChat error: $e $s');
      return null;
    }
  }

  @override
  Stream<ListingChat?> streamListingChat({
    required String listingId,
  }) {
    final controller = StreamController<ListingChat?>();

    final subscription = _firestore
        .collection('listing_chats')
        .doc('listing_$listingId')
        .snapshots()
        .listen(
      (doc) {
        try {
          if (!doc.exists) {
            if (!controller.isClosed) {
              controller.add(null);
            }
          } else {
            if (!controller.isClosed) {
              controller.add(ListingChat.fromJson(doc.id, doc.data() ?? {}));
            }
          }
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
      onDone: () {
        controller.close();
      },
    );

    _subscriptions.add(subscription);
    return controller.stream;
  }

  // ========================================================================
  // ORDER CHAT
  // ========================================================================

  @override
  Future<void> createOrderChat({
    required String orderId,
    required String listingId,
    required String ownerUid,
    required String customerUid,
    required List<String> participantUids,
  }) async {
    try {
      await _firestore
          .collection('order_chats')
          .doc('order_$orderId')
          .set({
        'orderId': orderId,
        'listingId': listingId,
        'ownerUid': ownerUid,
        'customerUid': customerUid,
        'participantUids': participantUids,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, s) {
      debugPrint('CollaborationFirebase.createOrderChat error: $e $s');
      rethrow;
    }
  }

  @override
  Future<OrderChat?> getOrderChat({
    required String orderId,
  }) async {
    try {
      final doc = await _firestore
          .collection('order_chats')
          .doc('order_$orderId')
          .get();

      if (!doc.exists) return null;
      return OrderChat.fromJson(doc.id, doc.data() ?? {});
    } catch (e, s) {
      debugPrint('CollaborationFirebase.getOrderChat error: $e $s');
      return null;
    }
  }

  @override
  Stream<OrderChat?> streamOrderChat({
    required String orderId,
  }) {
    final controller = StreamController<OrderChat?>();

    final subscription = _firestore
        .collection('order_chats')
        .doc('order_$orderId')
        .snapshots()
        .listen(
      (doc) {
        try {
          if (!doc.exists) {
            if (!controller.isClosed) {
              controller.add(null);
            }
          } else {
            if (!controller.isClosed) {
              controller.add(OrderChat.fromJson(doc.id, doc.data() ?? {}));
            }
          }
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
      onDone: () {
        controller.close();
      },
    );

    _subscriptions.add(subscription);
    return controller.stream;
  }

  // ========================================================================
  // HELPER METHODS
  // ========================================================================

  @override
  Future<bool> canAccessListingCollaboration({
    required String listingId,
    required String userId,
  }) async {
    try {
      final listingDoc =
          await _firestore.collection('listings').doc(listingId).get();
      if (!listingDoc.exists) return false;

      final listing = listingDoc.data();
      if (listing?['authorID'] == userId) return true;

      // Check if user is active collaborator
      final collabDoc = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('collaborators')
          .doc(userId)
          .get();

      return collabDoc.exists && collabDoc.data()?['isActive'] == true;
    } catch (e) {
      debugPrint('CollaborationFirebase.canAccessListingCollaboration error: $e');
      return false;
    }
  }

  @override
  Future<CollaboratorPermissions?> getCollaboratorPermissions({
    required String listingId,
    required String collaboratorUid,
  }) async {
    try {
      final doc = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('collaborators')
          .doc(collaboratorUid)
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      // Check if collaborator is active (must match Firestore security rules)
      if (data['isActive'] != true) return null;

      return CollaboratorPermissions.fromJson(
        data['permissions'] ?? {},
      );
    } catch (e, s) {
      debugPrint('CollaborationFirebase.getCollaboratorPermissions error: $e $s');
      return null;
    }
  }

  @override
  Future<bool> isListingOwnerPremium({
    required String listingId,
  }) async {
    try {
      final listingDoc =
          await _firestore.collection('listings').doc(listingId).get();
      if (!listingDoc.exists) return false;

      final ownerId = listingDoc.data()?['authorID'];
      if (ownerId == null) return false;

      final userDoc = await _firestore.collection('users').doc(ownerId).get();
      return userDoc.data()?['hasPremium'] == true;
    } catch (e) {
      debugPrint('CollaborationFirebase.isListingOwnerPremium error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
