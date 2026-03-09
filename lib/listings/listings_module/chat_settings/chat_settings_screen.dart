import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/listings_module/api/listings_repository.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/utils/opening_hours_editor.dart';

class ChatSettingsScreen extends StatefulWidget {
  final ListingsUser currentUser;
  final ListingsRepository listingsRepository;

  const ChatSettingsScreen({
    super.key,
    required this.currentUser,
    required this.listingsRepository,
  });

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  List<ListingModel> _myListings = [];
  bool _isLoading = true;
  Map<String, bool> _chatEnabledStates = {};

  @override
  void initState() {
    super.initState();
    _loadMyListings();
  }

  Future<void> _loadMyListings() async {
    setState(() => _isLoading = true);
    try {
      final listings = await widget.listingsRepository.getMyListings(
        currentUserID: widget.currentUser.userID,
        favListingsIDs: widget.currentUser.likedListingsIDs,
      );
      
      // Initialize chat enabled states
      final states = <String, bool>{};
      for (var listing in listings) {
        states[listing.id] = listing.chatEnabled;
      }
      
      setState(() {
        _myListings = listings;
        _chatEnabledStates = states;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showAlertDialog(context, 'Error'.tr(), 'Failed to load listings: $e');
      }
    }
  }

  Future<void> _toggleChatEnabled(ListingModel listing, bool enabled) async {
    setState(() {
      _chatEnabledStates[listing.id] = enabled;
    });

    try {
      final updatedListing = listing.copyWith(chatEnabled: enabled);
      await widget.listingsRepository.postListing(
        newListing: updatedListing,
      );
      setState(() {
        _myListings = _myListings
            .map((item) => item.id == listing.id ? updatedListing : item)
            .toList();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled 
                ? 'Chat enabled for "${listing.title}"'.tr()
                : 'Chat disabled for "${listing.title}"'.tr(),
            ),
            backgroundColor: enabled ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _chatEnabledStates[listing.id] = !enabled;
      });
      
      if (mounted) {
        showAlertDialog(context, 'Error'.tr(), 'Failed to update chat settings: $e');
      }
    }
  }

  Future<void> _editChatHours(ListingModel listing) async {
    final result = await OpeningHoursEditorSheet.show(
      context,
      initialValue: listing.chatAvailabilityHours,
    );
    if (result == null) return;

    final updatedListing =
        listing.copyWith(chatAvailabilityHours: result.trim());

    try {
      await widget.listingsRepository.postListing(
        newListing: updatedListing,
      );

      if (!mounted) return;
      setState(() {
        _myListings = _myListings
            .map((item) => item.id == listing.id ? updatedListing : item)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat hours updated'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      showAlertDialog(context, 'Error'.tr(), 'Failed to update chat hours: $e');
    }
  }

  String _hoursSummary(String chatAvailabilityHours) {
    final trimmed = chatAvailabilityHours.trim();
    if (trimmed.isEmpty) return 'Always available'.tr();
    final lines = trimmed
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return 'Always available'.tr();
    if (lines.length <= 2) return lines.join('\n');
    return '${lines[0]}\n${lines[1]}\n...';
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Settings'.tr()),
        backgroundColor: Color(cfg.colorPrimary),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myListings.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.grey.withOpacity(0.3),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Listings Yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ).tr(),
                        const SizedBox(height: 12),
                        Text(
                          'Create a listing to manage chat settings',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ).tr(),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMyListings,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Manage chat availability and hours for each listing',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ).tr(),
                      ),
                      ..._myListings.map((listing) => _buildListingCard(listing, dark)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildListingCard(ListingModel listing, bool dark) {
    final isEnabled = _chatEnabledStates[listing.id] ?? listing.chatEnabled;
    final hoursSummary = _hoursSummary(listing.chatAvailabilityHours);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: dark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Listing thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: listing.photo.isNotEmpty
                  ? displayCircleImage(listing.photo, 60, false)
                  : Container(
                      width: 60,
                      height: 60,
                      color: dark ? Colors.grey.shade800 : Colors.grey[300],
                      child: Icon(
                        Icons.image_not_supported,
                        color: dark ? Colors.grey.shade600 : Colors.grey[600],
                        size: 30,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            
            // Listing info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white : Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEnabled ? 'Chat enabled'.tr() : 'Chat disabled'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isEnabled 
                        ? Colors.green 
                        : (dark ? Colors.grey.shade400 : Colors.grey),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hoursSummary,
                    style: TextStyle(
                      fontSize: 12,
                      color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _editChatHours(listing),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.centerLeft,
                    ),
                    icon: const Icon(Icons.schedule, size: 16),
                    label: Text('Edit Chat Hours'.tr()),
                  ),
                ],
              ),
            ),
            
            // Toggle switch
            Switch(
              value: isEnabled,
              activeColor: Color(cfg.colorPrimary),
              activeTrackColor: Color(cfg.colorPrimary).withOpacity(0.5),
              inactiveThumbColor: dark ? Colors.grey.shade600 : Colors.grey.shade400,
              inactiveTrackColor: dark ? Colors.grey.shade800 : Colors.grey.shade300,
              onChanged: (value) => _toggleChatEnabled(listing, value),
            ),
          ],
        ),
      ),
    );
  }
}
