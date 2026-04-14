import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/blocked_booking_user.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/blocked_user_repository.dart';

class BlockedUsersScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const BlockedUsersScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final BlockedUserRepository _blockedUserRepository = BlockedUserRepository();

  Future<Map<String, dynamic>?> _loadUser(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(userId)
          .get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmUnblock(BlockedBookingUser blockedUser) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unblock user?'.tr()),
        content: Text('This user will be able to contact you again.'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Unblock'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _blockedUserRepository.unblockUser(
        listerId: widget.currentUser.userID,
        blockedUserId: blockedUser.blockedUserId,
      );
      if (!mounted) return;
      showSnackBar(context, 'User unblocked successfully.'.tr());
    } catch (_) {
      if (!mounted) return;
      showSnackBar(context, 'Failed to unblock user. Please try again.'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text('Blocked Users'.tr()),
      ),
      body: StreamBuilder<List<BlockedBookingUser>>(
        stream: _blockedUserRepository.streamBlockedUsers(widget.currentUser.userID),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final blockedUsers = snapshot.data ?? const <BlockedBookingUser>[];
          if (blockedUsers.isEmpty) {
            return Center(
              child: Text(
                'No blocked users'.tr(),
                style: TextStyle(
                  color: dark ? Colors.white70 : Colors.black54,
                  fontSize: 16,
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: blockedUsers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final blocked = blockedUsers[index];

              return FutureBuilder<Map<String, dynamic>?>(
                future: _loadUser(blocked.blockedUserId),
                builder: (context, userSnapshot) {
                  final userData = userSnapshot.data;
                  final firstName = (userData?['firstName'] ?? '').toString();
                  final lastName = (userData?['lastName'] ?? '').toString();
                  final displayName = '$firstName $lastName'.trim();
                  final subtitleParts = <String>[
                    if (blocked.reason != null && blocked.reason!.trim().isNotEmpty)
                      '${'Reason'.tr()}: ${blocked.reason!.trim()}',
                    '${'Blocked on'.tr()}: ${DateFormat('MMM dd, yyyy').format(blocked.blockedAt)}',
                  ];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                      child: Icon(Icons.person_off, color: dark ? Colors.white70 : Colors.black54),
                    ),
                    title: Text(
                      displayName.isEmpty ? blocked.blockedUserId : displayName,
                      style: TextStyle(color: dark ? Colors.white : Colors.black87),
                    ),
                    subtitle: Text(
                      subtitleParts.join('\n'),
                      style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                    ),
                    isThreeLine: subtitleParts.length > 1,
                    trailing: TextButton(
                      onPressed: () => _confirmUnblock(blocked),
                      child: Text('Unblock'.tr()),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
