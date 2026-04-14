import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/listings_module/events/event_details_screen.dart';
import 'package:caribtap/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:caribtap/listings/model/event_model.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';

class DemoListingsScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const DemoListingsScreen({super.key, required this.currentUser});

  @override
  State<DemoListingsScreen> createState() => _DemoListingsScreenState();
}

class _DemoListingsScreenState extends State<DemoListingsScreen> {
  List<ListingModel> _listings = [];
  List<EventModel> _events = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDemoListings();
  }

  Future<void> _loadDemoListings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final firestore = FirebaseFirestore.instance;
      final listingsFuture = firestore
          .collection(cfg.listingsCollection)
          .where('isDemo', isEqualTo: true)
          .get();
      final eventsFuture = firestore
          .collection('events')
          .where('isDemo', isEqualTo: true)
          .get();

      final results = await Future.wait([listingsFuture, eventsFuture]);
      final listingSnap = results[0];
      final eventSnap = results[1];

      final listings = listingSnap.docs
          .map((d) => ListingModel.fromJson(d.data()..['id'] = d.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final events = eventSnap.docs
          .map((d) => EventModel.fromJson(d.data()..['id'] = d.id))
          .toList()
        ..sort((a, b) => b.createdAtSeconds.compareTo(a.createdAtSeconds));
      if (mounted) {
        setState(() {
          _listings = listings;
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode(context);
    final Color primary = Color(cfg.colorPrimary);

    return Scaffold(
      appBar: AppBar(
        title: Text('Demo Listings'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Informational banner
          Container(
            color: primary.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'These are sample listings and events that show how features are configured. Open any demo item to explore how it is set up.'
                        .tr(),
                    style: TextStyle(
                      fontSize: 13,
                      color: dark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Listings body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _error != null
                    ? _buildError()
                    : _listings.isEmpty && _events.isEmpty
                        ? _buildEmpty(dark, primary)
                        : RefreshIndicator(
                            onRefresh: _loadDemoListings,
                            child: ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 60),
                              children: [
                                if (_listings.isNotEmpty) ...[
                                  _SectionHeader(title: 'Listings'.tr()),
                                  const SizedBox(height: 8),
                                  ..._listings.map(
                                    (listing) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _DemoListingRow(
                                        listing: listing,
                                        currentUser: widget.currentUser,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (_events.isNotEmpty) ...[
                                  _SectionHeader(title: 'Events'.tr()),
                                  const SizedBox(height: 8),
                                  ..._events.map(
                                    (event) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _DemoEventRow(event: event),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text('Could not load demo listings.'.tr(),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDemoListings,
              child: Text('Retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool dark, Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 56, color: primary),
            const SizedBox(height: 16),
            Text(
              'No demo listings or events yet.'.tr(),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add demo items from listings or events to populate this section.'
                  .tr(),
              style: TextStyle(
                  fontSize: 13,
                  color: dark ? Colors.white54 : Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: dark ? Colors.white : const Color(0xFF1B1B1B),
      ),
    );
  }
}

class _DemoListingRow extends StatelessWidget {
  final ListingModel listing;
  final ListingsUser currentUser;

  const _DemoListingRow({
    required this.listing,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode(context);
    final Color primary = Color(cfg.colorPrimary);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        push(
          context,
          ListingDetailsWrappingWidget(
            listing: listing,
            currentUser: currentUser,
          ),
        );
      },
      child: Container(
        height: MediaQuery.of(context).size.height / 8,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail with Demo badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width / 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: displayImage(listing.photo),
                  ),
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'DEMO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: dark
                            ? Colors.white
                            : const Color(0xFF1B1B1B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listing.categoryTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      listing.place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: dark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tap hint arrow
            Icon(
              Icons.chevron_right_rounded,
              color: dark ? Colors.white38 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoEventRow extends StatelessWidget {
  final EventModel event;

  const _DemoEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode(context);
    final Color primary = Color(cfg.colorPrimary);
    final startDate = DateTime.fromMillisecondsSinceEpoch(event.startAtSeconds * 1000);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        push(
          context,
          EventDetailsScreen(event: event),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: dark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: dark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: event.posterImageUrl.trim().isNotEmpty
                        ? Image.network(event.posterImageUrl, fit: BoxFit.cover)
                        : Container(
                            color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                            child: Icon(Icons.event, color: primary),
                          ),
                  ),
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DEMO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: dark ? Colors.white : const Color(0xFF1B1B1B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEE, MMM d • h:mm a').format(startDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dark ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.venueName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dark ? Colors.white60 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: dark ? Colors.white54 : Colors.black45),
          ],
        ),
      ),
    );
  }
}
