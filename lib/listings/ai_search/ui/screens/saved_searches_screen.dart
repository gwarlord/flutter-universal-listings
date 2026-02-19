import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:caribtap/listings/ai_search/blocs/ai_search_cubit.dart';
import 'package:caribtap/listings/ai_search/blocs/ai_search_state.dart';
import 'package:caribtap/listings/ai_search/models/saved_search.dart';

/// Screen for managing saved searches
class SavedSearchesScreen extends StatefulWidget {
  final String userId;

  const SavedSearchesScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<SavedSearchesScreen> createState() => _SavedSearchesScreenState();
}

class _SavedSearchesScreenState extends State<SavedSearchesScreen> {
  late SavedSearchesCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = SavedSearchesCubit(userId: widget.userId);
    _cubit.loadSavedSearches();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Saved Searches'.tr()),
        ),
        body: BlocBuilder<SavedSearchesCubit, SavedSearchesState>(
          builder: (context, state) {
            if (state is SavedSearchesLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is SavedSearchesLoaded) {
              if (state.searches.isEmpty) {
                return _buildEmptyState();
              }
              return _buildSearchList(state.searches);
            } else if (state is SavedSearchesError) {
              return _buildErrorState(state.message);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Saved Searches'.tr(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Save searches to quickly access them later'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchList(List<SavedSearch> searches) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: searches.length,
      itemBuilder: (context, index) {
        final search = searches[index];
        return _buildSearchCard(search);
      },
    );
  }

  Widget _buildSearchCard(SavedSearch search) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.bookmark, color: Colors.blue),
        title: Text(
          search.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              search.originalQuery,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Last run: ${_formatDate(search.lastRunAt)}'.tr(),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'run':
                _runSearch(search);
                break;
              case 'notifications':
                _toggleNotifications(search);
                break;
              case 'delete':
                _deleteSearch(search);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'run',
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20),
                  const SizedBox(width: 8),
                  Text('Run Search'.tr()),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'notifications',
              child: Row(
                children: [
                  Icon(
                    search.notificationsEnabled
                        ? Icons.notifications_off
                        : Icons.notifications,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(search.notificationsEnabled
                      ? 'Turn Off Notifications'.tr()
                      : 'Turn On Notifications'.tr()),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Delete'.tr(), style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _runSearch(search),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error'.tr(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text('Try Again'.tr()),
              onPressed: () {
                _cubit.loadSavedSearches();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today'.tr();
    } else if (difference.inDays == 1) {
      return 'Yesterday'.tr();
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago'.tr();
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  void _runSearch(SavedSearch search) {
    // Navigate back to search screen and run the saved search
    Navigator.pop(context, search);
  }

  void _toggleNotifications(SavedSearch search) {
    _cubit.toggleNotifications(
      search.id,
      !search.notificationsEnabled,
    );
  }

  void _deleteSearch(SavedSearch search) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Search?'.tr()),
        content: Text('Are you sure you want to delete "${search.name}"?'.tr()),
        actions: [
          TextButton(
            child: Text('Cancel'.tr()),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'.tr()),
            onPressed: () {
              Navigator.pop(context);
              _cubit.deleteSavedSearch(search.id);
            },
          ),
        ],
      ),
    );
  }
}
