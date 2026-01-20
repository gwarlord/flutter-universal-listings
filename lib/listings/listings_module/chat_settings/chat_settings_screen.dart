import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/listings/listings_module/api/listings_repository.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/core/utils/helper.dart';

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
                          'Manage chat availability for your listings',
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
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
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
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[600],
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEnabled ? 'Chat enabled'.tr() : 'Chat disabled'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isEnabled ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Toggle switch
            Switch(
              value: isEnabled,
              activeColor: Color(cfg.colorPrimary),
              onChanged: (value) => _toggleChatEnabled(listing, value),
            ),
          ],
        ),
      ),
    );
  }
}
