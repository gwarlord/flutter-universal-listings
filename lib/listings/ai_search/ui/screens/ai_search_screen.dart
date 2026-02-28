import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:caribtap/listings/ai_search/blocs/ai_search_cubit.dart';
import 'package:caribtap/listings/ai_search/blocs/ai_search_state.dart';
import 'package:caribtap/listings/ai_search/ui/widgets/ai_search_bar.dart';
import 'package:caribtap/listings/ai_search/ui/widgets/search_result_card.dart';
import 'package:caribtap/listings/ai_search/ui/widgets/rate_limit_dialog.dart';
import 'package:caribtap/listings/ai_search/utils/search_helpers.dart';
import 'package:caribtap/listings/ai_search/utils/search_constants.dart';
import 'package:caribtap/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';

/// Main AI-assisted search screen
class AiSearchScreen extends StatefulWidget {
  final String userId;

  const AiSearchScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends State<AiSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late AiSearchCubit _searchCubit;

  @override
  void initState() {
    super.initState();
    _searchCubit = AiSearchCubit(userId: widget.userId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchCubit.close();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _searchCubit.search(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _searchCubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text('AI Search'.tr()),
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmark_border),
              tooltip: 'Saved Searches'.tr(),
              onPressed: () {
                Navigator.pushNamed(context, '/saved_searches');
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: AiSearchBar(
                controller: _searchController,
                onSearch: (query) {
                  _searchController.text = query;
                  _performSearch();
                },
              ),
            ),

            // Results
            Expanded(
              child: BlocConsumer<AiSearchCubit, AiSearchState>(
                listener: (context, state) {
                  if (state is AiSearchRateLimitExceeded) {
                    showDialog(
                      context: context,
                      builder: (context) => RateLimitDialog(
                        message: state.message,
                        upgradeMessage: state.upgradeMessage,
                        onKeywordSearch: () {
                          Navigator.pop(context);
                          // Fallback to keyword search
                          SearchHelpers.showInfo(
                            context,
                            'Using basic keyword search'.tr(),
                          );
                        },
                        onUpgrade: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/subscription');
                        },
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is AiSearchInitial) {
                    return _buildInitialState();
                  } else if (state is AiSearchLoading) {
                    return _buildLoadingState(state.message);
                  } else if (state is AiSearchLoaded) {
                    return _buildLoadedState(state);
                  } else if (state is AiSearchError) {
                    return _buildErrorState(state);
                  } else if (state is AiSearchRateLimitExceeded) {
                    return _buildRateLimitState(state);
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.grey[400] : Colors.grey[500];
    final textColor = isDark ? Colors.grey[400] : Colors.grey[600];
    
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Icon(
            Icons.search,
            size: 80,
            color: iconColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Search with AI'.tr(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Type naturally: "best pizza near me" or "gyms open now"'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Try these:'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: SearchConstants.exampleQueries.map((query) {
              return ActionChip(
                label: Text(query),
                onPressed: () {
                  _searchController.text = query;
                  _performSearch();
                },
              );
            }).toList(),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(String? message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadedState(AiSearchLoaded state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.grey[400] : Colors.grey[500];
    final textColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final containerBg = isDark ? Colors.grey[850] : SearchConstants.aiIndicatorColor.withOpacity(0.1);
    final containerTextColor = isDark ? Colors.grey[200] : Colors.black87;
    
    if (state.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: iconColor),
            const SizedBox(height: 16),
            Text(
              'No results found'.tr(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or filters'.tr(),
              style: TextStyle(color: textColor),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text('Try Again'.tr()),
              onPressed: () {
                _performSearch();
              },
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // AI interpretation summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: containerBg,
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, 
                  size: 20, 
                  color: SearchConstants.aiIndicatorColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.interpretation.naturalLanguageSummary,
                  style: TextStyle(fontWeight: FontWeight.w500, color: containerTextColor),
                ),
              ),
            ],
          ),
        ),

        // Results count
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                '${'Found'.tr()} ${state.results.length} ${'results'.tr()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.tune, size: 18),
                label: Text('Refine'.tr()),
                onPressed: () {
                  // Show refine dialog
                  _showRefineDialog(state);
                },
              ),
            ],
          ),
        ),

        // Results list
        Expanded(
          child: ListView.builder(
            itemCount: state.results.length,
            itemBuilder: (context, index) {
              final result = state.results[index];
              return SearchResultCard(
                result: result,
                onTap: () {
                  if (result.listing != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ListingDetailsWrappingWidget(
                          listing: result.listing!,
                          currentUser: context.read<AuthenticationBloc>().state.user!,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(AiSearchError state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey[400] : Colors.grey[600];
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 80, color: SearchConstants.errorColor),
                    const SizedBox(height: 16),
                    Text(
                      'Oops!'.tr(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor),
                    ),
                    if (state.canRetry) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: Text('Try Again'.tr()),
                        onPressed: () {
                          _searchCubit.retry();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRateLimitState(AiSearchRateLimitExceeded state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, size: 80, color: SearchConstants.warningColor),
                    const SizedBox(height: 16),
                    Text(
                      'Limit Reached'.tr(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                    ),
                    if (state.upgradeMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        state.upgradeMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRefineDialog(AiSearchLoaded state) {
    // Simple refine dialog - could be expanded
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Refine Search'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: Text('Open Now'.tr()),
              value: state.interpretation.filters.openNow ?? false,
              onChanged: (value) {
                Navigator.pop(context);
                _searchCubit.refine(openNow: value);
              },
            ),
            CheckboxListTile(
              title: Text('Delivery Available'.tr()),
              value: state.interpretation.filters.delivery ?? false,
              onChanged: (value) {
                Navigator.pop(context);
                _searchCubit.refine(delivery: value);
              },
            ),
            CheckboxListTile(
              title: Text('Verified Only'.tr()),
              value: state.interpretation.filters.verified ?? false,
              onChanged: (value) {
                Navigator.pop(context);
                _searchCubit.refine(verified: value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Close'.tr()),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}