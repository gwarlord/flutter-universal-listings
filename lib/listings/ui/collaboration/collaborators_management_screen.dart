import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_module/api/collaboration_api_manager.dart';
import 'package:caribtap/listings/model/collaboration_model.dart';

class CollaboratorsManagementScreen extends StatefulWidget {
  final String listingId;
  final String listingOwnerId;
  final String currentUserId;
  final bool isOwner;
  final bool hasPremium;

  const CollaboratorsManagementScreen({
    Key? key,
    required this.listingId,
    required this.listingOwnerId,
    required this.currentUserId,
    required this.isOwner,
    required this.hasPremium,
  }) : super(key: key);

  @override
  State<CollaboratorsManagementScreen> createState() =>
      _CollaboratorsManagementScreenState();
}

class _CollaboratorsManagementScreenState
    extends State<CollaboratorsManagementScreen> {
  late List<CollaboratorModel> collaborators = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCollaborators();
  }

  String _friendlyError(Object error) {
    if (error is FirebaseFunctionsException) {
      if ((error.message ?? '').trim().isNotEmpty) {
        return error.message!.trim();
      }
      switch (error.code) {
        case 'not-found':
          return 'User not found';
        case 'invalid-argument':
          return 'Please enter a valid collaborator email or UID';
        case 'permission-denied':
          return 'You do not have permission for this action';
        default:
          return 'Action failed. Please try again.';
      }
    }
    return error.toString();
  }

  void _loadCollaborators() async {
    try {
      setState(() => isLoading = true);
      final collab = await collaborationApiManager.getListingCollaborators(
        listingId: widget.listingId,
      );
      setState(() {
        collaborators = collab;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _showAddCollaboratorDialog() {
    if (!widget.isOwner || !widget.hasPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium required to manage collaborators')),
      );
      return;
    }

    final emailController = TextEditingController();
    final permissionsFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AddCollaboratorDialog(
        onAddCollaborator: (email, permissions) async {
          try {
            final uid = await collaborationApiManager.addListingCollaborator(
              listingId: widget.listingId,
              collaboratorEmailOrUid: email,
              permissions: permissions,
            );
            // Log activity (fire-and-forget)
            collaborationApiManager.logActivity(
              listingId: widget.listingId,
              actorUid: widget.currentUserId,
              actorRole: 'OWNER',
              actionType: 'COLLABORATOR_ADDED',
              targetType: 'COLLABORATOR',
              targetId: uid,
              targetName: email,
            );
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Collaborator added successfully')),
              );
              _loadCollaborators();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${_friendlyError(e)}')),
              );
            }
          }
        },
      ),
    );
  }

  void _updateCollaboratorPermissions(
    CollaboratorModel collaborator,
    CollaboratorPermissions newPermissions,
  ) async {
    try {
      await collaborationApiManager.updateListingCollaboratorPermissions(
        listingId: widget.listingId,
        collaboratorUid: collaborator.uid,
        permissions: newPermissions,
      );

      // Log activity (fire-and-forget)
      collaborationApiManager.logActivity(
        listingId: widget.listingId,
        actorUid: widget.currentUserId,
        actorRole: 'OWNER',
        actionType: 'COLLABORATOR_PERMISSIONS_UPDATED',
        targetType: 'COLLABORATOR',
        targetId: collaborator.uid,
        targetName: collaborator.displayName ?? collaborator.uid,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions updated')),
      );
      _loadCollaborators();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${_friendlyError(e)}')),
      );
    }
  }

  void _removeCollaborator(CollaboratorModel collaborator) async {
    final isDark = isDarkMode(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Remove Collaborator',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${collaborator.displayName ?? collaborator.uid}?',
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.black54,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await collaborationApiManager.removeListingCollaborator(
          listingId: widget.listingId,
          collaboratorUid: collaborator.uid,
        );

        // Log activity (fire-and-forget)
        collaborationApiManager.logActivity(
          listingId: widget.listingId,
          actorUid: widget.currentUserId,
          actorRole: 'OWNER',
          actionType: 'COLLABORATOR_REMOVED',
          targetType: 'COLLABORATOR',
          targetId: collaborator.uid,
          targetName: collaborator.displayName ?? collaborator.uid,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Collaborator removed')),
          );
          _loadCollaborators();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${_friendlyError(e)}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collaborators'),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Text('Error: $errorMessage'),
                )
              : Column(
                  children: [
                    if (!widget.hasPremium)
                      Container(
                        color: Colors.orange[100],
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.lock, color: Colors.orange[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Premium Feature',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Upgrade to Premium to manage collaborators',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: collaborators.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Collaborators Yet',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add collaborators to manage this listing',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: collaborators.length,
                              itemBuilder: (context, index) {
                                final collab = collaborators[index];
                                return CollaboratorTile(
                                  collaborator: collab,
                                  onPermissionsChanged: (permissions) {
                                    _updateCollaboratorPermissions(
                                      collab,
                                      permissions,
                                    );
                                  },
                                  onRemove: () {
                                    _removeCollaborator(collab);
                                  },
                                  canManage:
                                      widget.isOwner && widget.hasPremium,
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: widget.isOwner && widget.hasPremium
          ? FloatingActionButton.extended(
              onPressed: _showAddCollaboratorDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Collaborator'),
            )
          : null,
    );
  }

  @override
  void dispose() {
    collaborationApiManager.dispose();
    super.dispose();
  }
}

// ============================================================================
// ADD COLLABORATOR DIALOG
// ============================================================================

class AddCollaboratorDialog extends StatefulWidget {
  final Function(String email, CollaboratorPermissions permissions)
      onAddCollaborator;

  const AddCollaboratorDialog({
    Key? key,
    required this.onAddCollaborator,
  }) : super(key: key);

  @override
  State<AddCollaboratorDialog> createState() => _AddCollaboratorDialogState();
}

class _AddCollaboratorDialogState extends State<AddCollaboratorDialog> {
  final emailController = TextEditingController();
  late CollaboratorPermissions permissions =
      CollaboratorPermissions.defaultPermissions();
  bool isLoading = false;

  void _submit() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      await widget.onAddCollaborator(email, permissions);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    
    return Dialog(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      surfaceTintColor: Colors.transparent,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Collaborator',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: emailController,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter email or UID',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  prefixIcon: Icon(
                    Icons.email,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.blue[400]! : Colors.blue[600]!,
                      width: 2,
                    ),
                  ),
                ),
                enabled: !isLoading,
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Permissions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PermissionToggle(
                label: 'Manage Orders',
                value: permissions.manageOrders,
                onChanged: (value) {
                  setState(() {
                    permissions =
                        permissions.copyWith(manageOrders: value);
                  });
                },
              ),
              _PermissionToggle(
                label: 'Manage Bookings',
                value: permissions.manageBookings,
                onChanged: (value) {
                  setState(() {
                    permissions =
                        permissions.copyWith(manageBookings: value);
                  });
                },
              ),
              _PermissionToggle(
                label: 'Manage Rentals',
                value: permissions.manageRentals,
                onChanged: (value) {
                  setState(() {
                    permissions =
                        permissions.copyWith(manageRentals: value);
                  });
                },
              ),
              _PermissionToggle(
                label: 'Manage Chats',
                value: permissions.manageChats,
                onChanged: (value) {
                  setState(() {
                    permissions =
                        permissions.copyWith(manageChats: value);
                  });
                },
              ),
              _PermissionToggle(
                label: 'Edit Listing',
                value: permissions.editListing,
                onChanged: (value) {
                  setState(() {
                    permissions =
                        permissions.copyWith(editListing: value);
                  });
                },
              ),
              _PermissionToggle(
                label: 'Change Order Status',
                value: permissions.changeOrderStatus,
                onChanged: (value) {
                  setState(() {
                    permissions =
                        permissions.copyWith(changeOrderStatus: value);
                  });
                },
              ),
              _PermissionToggle(
                label: 'Change Fulfillment',
                value: permissions.changeFulfillment,
                onChanged: (value) {
                  setState(() {
                    permissions =
                        permissions.copyWith(changeFulfillment: value);
                  });
                },
              ),
              _PermissionToggle(
                label: 'Manage Table Mode',
                value: permissions.manageTableMode,
                onChanged: (value) {
                  setState(() {
                    permissions =
                        permissions.copyWith(manageTableMode: value);
                  });
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
}

// ============================================================================
// COLLABORATOR TILE
// ============================================================================

class CollaboratorTile extends StatefulWidget {
  final CollaboratorModel collaborator;
  final Function(CollaboratorPermissions) onPermissionsChanged;
  final VoidCallback onRemove;
  final bool canManage;

  const CollaboratorTile({
    Key? key,
    required this.collaborator,
    required this.onPermissionsChanged,
    required this.onRemove,
    required this.canManage,
  }) : super(key: key);

  @override
  State<CollaboratorTile> createState() => _CollaboratorTileState();
}

class _CollaboratorTileState extends State<CollaboratorTile> {
  late CollaboratorPermissions permissions = widget.collaborator.permissions;
  bool isExpanded = false;

  void _updatePermission(
    String permissionName,
    bool value,
  ) {
    late CollaboratorPermissions updated;
    switch (permissionName) {
      case 'manageOrders':
        updated = permissions.copyWith(manageOrders: value);
        break;
      case 'manageBookings':
        updated = permissions.copyWith(manageBookings: value);
        break;
      case 'manageRentals':
        updated = permissions.copyWith(manageRentals: value);
        break;
      case 'manageChats':
        updated = permissions.copyWith(manageChats: value);
        break;
      case 'editListing':
        updated = permissions.copyWith(editListing: value);
        break;
      case 'changeOrderStatus':
        updated = permissions.copyWith(changeOrderStatus: value);
        break;
      case 'changeFulfillment':
        updated = permissions.copyWith(changeFulfillment: value);
        break;
      case 'manageTableMode':
        updated = permissions.copyWith(manageTableMode: value);
        break;
      default:
        return;
    }

    setState(() => permissions = updated);
    widget.onPermissionsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? Colors.grey[900] : Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: widget.collaborator.profilePictureUrl != null &&
                      widget.collaborator.profilePictureUrl!.isNotEmpty
                  ? NetworkImage(widget.collaborator.profilePictureUrl!)
                  : null,
              child: widget.collaborator.profilePictureUrl == null ||
                      widget.collaborator.profilePictureUrl!.isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(
              widget.collaborator.displayName ?? widget.collaborator.uid,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              '${permissions.enabledPermissions.length} permissions',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            trailing: Theme(
              data: Theme.of(context).copyWith(
                popupMenuTheme: PopupMenuThemeData(
                  color: isDark ? Colors.grey[800] : Colors.white,
                  surfaceTintColor: Colors.transparent,
                  textStyle: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              child: PopupMenuButton<String>(
                enabled: widget.canManage,
                onSelected: (value) {
                  if (value == 'remove') {
                    widget.onRemove();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(
                      'Remove',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
                child: Icon(
                  Icons.more_vert,
                  color: widget.canManage
                      ? (isDark ? Colors.grey[400] : Colors.grey[600])
                      : Colors.grey,
                ),
              ),
            ),
            onTap: widget.canManage
                ? () => setState(() => isExpanded = !isExpanded)
                : null,
          ),
          if (isExpanded && widget.canManage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _PermissionToggle(
                    label: 'Manage Orders',
                    value: permissions.manageOrders,
                    onChanged: (value) =>
                        _updatePermission('manageOrders', value),
                  ),
                  _PermissionToggle(
                    label: 'Manage Bookings',
                    value: permissions.manageBookings,
                    onChanged: (value) =>
                        _updatePermission('manageBookings', value),
                  ),
                  _PermissionToggle(
                    label: 'Manage Rentals',
                    value: permissions.manageRentals,
                    onChanged: (value) =>
                        _updatePermission('manageRentals', value),
                  ),
                  _PermissionToggle(
                    label: 'Manage Chats',
                    value: permissions.manageChats,
                    onChanged: (value) =>
                        _updatePermission('manageChats', value),
                  ),
                  _PermissionToggle(
                    label: 'Edit Listing',
                    value: permissions.editListing,
                    onChanged: (value) =>
                        _updatePermission('editListing', value),
                  ),
                  _PermissionToggle(
                    label: 'Change Order Status',
                    value: permissions.changeOrderStatus,
                    onChanged: (value) =>
                        _updatePermission('changeOrderStatus', value),
                  ),
                  _PermissionToggle(
                    label: 'Change Fulfillment',
                    value: permissions.changeFulfillment,
                    onChanged: (value) =>
                        _updatePermission('changeFulfillment', value),
                  ),
                  _PermissionToggle(
                    label: 'Manage Table Mode',
                    value: permissions.manageTableMode,
                    onChanged: (value) =>
                        _updatePermission('manageTableMode', value),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// PERMISSION TOGGLE WIDGET
// ============================================================================

class _PermissionToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionToggle({
    Key? key,
    required this.label,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
