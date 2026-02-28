import 'package:flutter/material.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listing_activity.dart';
import 'package:caribtap/listings/services/listing_activity_service.dart';
import 'package:caribtap/listings/widgets/freshness_indicators.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Comprehensive dashboard for listers to manage freshness
class ListingFreshnessDashboard extends StatefulWidget {
  final List<ListingModel> listings;
  final Function(ListingModel) onRefreshListing;
  final Function(List<ListingModel>) onRefreshMultiple;

  const ListingFreshnessDashboard({
    Key? key,
    required this.listings,
    required this.onRefreshListing,
    required this.onRefreshMultiple,
  }) : super(key: key);

  @override
  State<ListingFreshnessDashboard> createState() =>
      _ListingFreshnessDashboardState();
}

class _ListingFreshnessDashboardState
    extends State<ListingFreshnessDashboard> {
  final ListingActivityService _activityService = ListingActivityService();
  final Set<String> _selectedListings = {};
  bool _selectMode = false;
  Map<String, ListingActivityScore> _activityScores = {};
  bool _loadingScores = true;

  @override
  void initState() {
    super.initState();
    _loadActivityScores();
  }

  Future<void> _loadActivityScores() async {
    setState(() => _loadingScores = true);
    
    final listingIds = widget.listings.map((l) => l.id).toList();
    final scores = await _activityService.batchCalculateScores(listingIds);
    
    setState(() {
      _activityScores = scores;
      _loadingScores = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _getUrgentListings();
    final warning = _getWarningListings();
    final fresh = _getFreshListings();
    final hidden = _getHiddenListings();
    final exempt = _getExemptListings();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing Freshness'),
        actions: [
          if (_selectMode)
            TextButton.icon(
              onPressed: _cancelSelection,
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _enterSelectMode,
              tooltip: 'Select multiple',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivityScores,
            tooltip: 'Reload scores',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadActivityScores,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCard(urgent, warning, fresh, hidden, exempt),
            const SizedBox(height: 16),
            if (_selectMode) _buildBulkActionBar(),
            const SizedBox(height: 8),
            if (urgent.isNotEmpty) ...[
              _buildSection(
                'Urgent Attention',
                urgent,
                Colors.red,
                'These listings will hide soon. Take action now!',
                Icons.error,
              ),
              const SizedBox(height: 16),
            ],
            if (warning.isNotEmpty) ...[
              _buildSection(
                'Needs Refresh Soon',
                warning,
                Colors.orange,
                'Plan to refresh these listings soon.',
                Icons.warning,
              ),
              const SizedBox(height: 16),
            ],
            if (fresh.isNotEmpty) ...[
              _buildSection(
                'Active & Fresh',
                fresh,
                Colors.green,
                'These listings are in good standing.',
                Icons.check_circle,
              ),
              const SizedBox(height: 16),
            ],
            if (exempt.isNotEmpty) ...[
              _buildSection(
                'Never Expire',
                exempt,
                Colors.blue,
                'These listings are exempt from automatic hiding.',
                Icons.stars,
              ),
              const SizedBox(height: 16),
            ],
            if (hidden.isNotEmpty) ...[
              _buildSection(
                'Hidden Listings',
                hidden,
                Colors.grey,
                'Refresh to make these visible again.',
                Icons.visibility_off,
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: urgent.isNotEmpty || warning.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _refreshUrgentListings(urgent, warning),
              icon: const Icon(Icons.refresh),
              label: Text(
                'Refresh All Urgent (${urgent.length + warning.length})',
              ),
            )
          : null,
    );
  }

  Widget _buildSummaryCard(
    List<ListingModel> urgent,
    List<ListingModel> warning,
    List<ListingModel> fresh,
    List<ListingModel> hidden,
    List<ListingModel> exempt,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryTile(
                    'Urgent',
                    urgent.length,
                    Colors.red,
                    Icons.error,
                  ),
                ),
                Expanded(
                  child: _buildSummaryTile(
                    'Warning',
                    warning.length,
                    Colors.orange,
                    Icons.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryTile(
                    'Fresh',
                    fresh.length,
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: _buildSummaryTile(
                    'Hidden',
                    hidden.length,
                    Colors.grey,
                    Icons.visibility_off,
                  ),
                ),
              ],
            ),
            if (exempt.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSummaryTile(
                'Exempt (Never Expire)',
                exempt.length,
                Colors.blue,
                Icons.stars,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTile(
    String label,
    int count,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActionBar() {
    final selectedCount = _selectedListings.length;
    
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(
              '$selectedCount selected',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const Spacer(),
            if (selectedCount > 0) ...[
              ElevatedButton.icon(
                onPressed: _refreshSelected,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _deselectAll,
                child: const Text('Deselect All'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<ListingModel> listings,
    Color color,
    String description,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                listings.length.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        ...listings.map((listing) => _buildListingCard(listing, color)),
      ],
    );
  }

  Widget _buildListingCard(ListingModel listing, Color sectionColor) {
    final isSelected = _selectedListings.contains(listing.id);
    final activityScore = _activityScores[listing.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected
            ? BorderSide(color: Colors.blue.shade700, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _selectMode ? _toggleSelection(listing.id) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_selectMode)
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(listing.id),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          listing.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (listing.categoryID.isNotEmpty)
                          Text(
                            listing.categoryTitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  FreshnessStatusBadge(listing: listing, compact: true),
                ],
              ),
              const SizedBox(height: 12),
              FreshnessProgressBar(listing: listing),
              if (activityScore != null && !_loadingScores) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    ActivityLevelBadge(
                      activityLevel: activityScore.activityLevel,
                      score: activityScore.score30Days,
                    ),
                    const Spacer(),
                    if (activityScore.qualifiesForAutoRefresh)
                      Chip(
                        label: const Text(
                          'Auto-Refresh Eligible',
                          style: TextStyle(fontSize: 11),
                        ),
                        avatar: const Icon(Icons.auto_awesome, size: 16),
                        backgroundColor: Colors.purple.shade50,
                        labelStyle: TextStyle(color: Colors.purple.shade700),
                      ),
                  ],
                ),
              ],
              if (!_selectMode) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!listing.hidden && !(listing.freshness?.exempt ?? false))
                      TextButton.icon(
                        onPressed: () => widget.onRefreshListing(listing),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh Now'),
                      ),
                    if (listing.hidden)
                      ElevatedButton.icon(
                        onPressed: () => widget.onRefreshListing(listing),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('Make Visible'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<ListingModel> _getUrgentListings() {
    return widget.listings
        .where((l) =>
            !l.hidden &&
            !(l.freshness?.exempt ?? false) &&
            (l.freshness?.daysRemaining ?? 999) <= 10)
        .toList()
      ..sort((a, b) => (a.freshness?.daysRemaining ?? 999)
          .compareTo(b.freshness?.daysRemaining ?? 999));
  }

  List<ListingModel> _getWarningListings() {
    return widget.listings
        .where((l) =>
            !l.hidden &&
            !(l.freshness?.exempt ?? false) &&
            (l.freshness?.daysRemaining ?? 999) > 10 &&
            (l.freshness?.daysRemaining ?? 999) <= 30)
        .toList()
      ..sort((a, b) => (a.freshness?.daysRemaining ?? 999)
          .compareTo(b.freshness?.daysRemaining ?? 999));
  }

  List<ListingModel> _getFreshListings() {
    return widget.listings
        .where((l) =>
            !l.hidden &&
            !(l.freshness?.exempt ?? false) &&
            (l.freshness?.daysRemaining ?? 999) > 30)
        .toList();
  }

  List<ListingModel> _getHiddenListings() {
    return widget.listings.where((l) => l.hidden).toList();
  }

  List<ListingModel> _getExemptListings() {
    return widget.listings
        .where((l) => !l.hidden && (l.freshness?.exempt ?? false))
        .toList();
  }

  void _enterSelectMode() {
    setState(() => _selectMode = true);
  }

  void _cancelSelection() {
    setState(() {
      _selectMode = false;
      _selectedListings.clear();
    });
  }

  void _toggleSelection(String listingId) {
    setState(() {
      if (_selectedListings.contains(listingId)) {
        _selectedListings.remove(listingId);
      } else {
        _selectedListings.add(listingId);
      }
    });
  }

  void _deselectAll() {
    setState(() => _selectedListings.clear());
  }

  void _refreshSelected() {
    final listings = widget.listings
        .where((l) => _selectedListings.contains(l.id))
        .toList();
    
    widget.onRefreshMultiple(listings);
    
    setState(() {
      _selectMode = false;
      _selectedListings.clear();
    });
  }

  void _refreshUrgentListings(
    List<ListingModel> urgent,
    List<ListingModel> warning,
  ) {
    final allUrgent = [...urgent, ...warning];
    widget.onRefreshMultiple(allUrgent);
  }
}
