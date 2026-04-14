import 'dart:io';

import 'package:caribtap/listings/ui/photo_enhancement/cubit/cubit.dart';
import 'package:caribtap/listings/ui/photo_enhancement/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bottom sheet for initiating photo enhancement workflow
class PhotoEnhancementBottomSheet extends StatelessWidget {
  final String listingId;
  final String category;
  final String subscriptionTier;
  final String userId;
  final Function(String variantId)? onVariantSaved;

  const PhotoEnhancementBottomSheet({
    Key? key,
    required this.listingId,
    required this.category,
    required this.subscriptionTier,
    required this.userId,
    this.onVariantSaved,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocListener<PhotoEnhancementCubit, PhotoEnhancementState>(
      listener: (context, state) {
        if (state is SubscriptionRequired) {
          _showSubscriptionModal(context, state.requiredTier);
        } else if (state is QuotaExhausted) {
          _showQuotaExhaustedDialog(context, state);
        } else if (state is OfflineError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (state is EnhancementError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        } else if (state is VariantSaved) {
          onVariantSaved?.call(state.variant.id);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image enhancement saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (context, scrollController) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return BlocBuilder<PhotoEnhancementCubit, PhotoEnhancementState>(
            builder: (context, state) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.auto_fix_high, color: isDark ? Colors.blueAccent : Colors.blue),
                          const SizedBox(width: 12),
                          Text(
                            'AI Photo Enhancement',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                    // Content
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildContent(context, state),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, PhotoEnhancementState state) {
    if (state is PhotoEnhancementInitial || state is SelectingImage) {
      return _buildImageSelector(context);
    } else if (state is ImageSelected) {
      return _buildImageSelected(context, state);
    } else if (state is Processing) {
      return EnhancementProgressWidget(
        progress: state.progress,
        message: state.message,
      );
    } else if (state is ComparisonView) {
      return ComparisonViewWidget(
        enhancement: state.enhancement,
        originalImagePath: state.originalImagePath,
        appliedEnhancements: state.appliedEnhancements,
        isPreview: state.isPreview,
        onApprove: () => _approveEnhancement(context, state),
        onReject: () => _rejectEnhancement(context),
        userQuota: state.userQuota,
      );
    } else if (state is SavingVariant) {
      return EnhancementProgressWidget(
        progress: 0.8,
        message: state.message,
      );
    } else if (state is SubscriptionRequired) {
      return _buildSubscriptionRequired(context, state);
    } else if (state is QuotaExhausted) {
      return _buildQuotaExhausted(context, state);
    } else if (state is OfflineError) {
      return _buildOfflineError(context, state);
    } else if (state is EnhancementError) {
      return _buildError(context, state);
    }

    return const SizedBox.shrink();
  }

  Widget _buildImageSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ImageSelectorWidget(
      isDark: isDark,
      onImageSelected: (imagePath, category) async {
        await context.read<PhotoEnhancementCubit>().selectImageForEnhancement(
          imagePath: imagePath,
          listingId: listingId,
          category: category,
          subscriptionTier: subscriptionTier,
        );
      },
      onCancel: () => Navigator.pop(context),
    );
  }

  Widget _buildImageSelected(BuildContext context, ImageSelected state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(state.imagePath),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (state.quota != null)
          QuotaIndicatorWidget(
            quota: state.quota!,
            showDetails: true,
          ),
        const SizedBox(height: 16),
        Text(
          'Category: ${state.category}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.read<PhotoEnhancementCubit>().reset(),
                child: const Text('Change Image'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => context.read<PhotoEnhancementCubit>().startEnhancement(
                  listingId: listingId,
                  imagePath: state.imagePath,
                  category: state.category,
                  subscriptionTier: subscriptionTier,
                  userId: userId,
                ),
                child: const Text('Enhance Now'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubscriptionRequired(
    BuildContext context,
    SubscriptionRequired state,
  ) {
    return TierUpgradeModalWidget(
      currentTier: subscriptionTier,
      requiredTier: state.requiredTier,
      onUpgrade: () {
        // Navigate to subscription upgrade screen
        Navigator.pop(context);
      },
      onDismiss: () => Navigator.pop(context),
    );
  }

  Widget _buildQuotaExhausted(BuildContext context, QuotaExhausted state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 64, color: Colors.red[600]),
          const SizedBox(height: 16),
          const Text(
            'Monthly Quota Exceeded',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ve used all 10 enhancements for this listing this month.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Text(
            'Resets on: ${state.resetDate.toString().split(' ')[0]}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, EnhancementError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[600]),
          const SizedBox(height: 16),
          const Text(
            'Enhancement Failed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      context.read<PhotoEnhancementCubit>().reset(),
                  child: const Text('Try Again'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineError(BuildContext context, OfflineError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 64, color: Colors.orange[700]),
          const SizedBox(height: 16),
          Text(
            'Offline'.toUpperCase(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      context.read<PhotoEnhancementCubit>().reset(),
                  child: const Text('Try Again'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSubscriptionModal(BuildContext context, String requiredTier) {
    showDialog(
      context: context,
      builder: (context) => TierUpgradeModalWidget(
        currentTier: subscriptionTier,
        requiredTier: requiredTier,
        onUpgrade: () => Navigator.pop(context),
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }

  void _showQuotaExhaustedDialog(
    BuildContext context,
    QuotaExhausted state,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quota Limit Reached'),
        content: Text(
          'You\'ve already used all 10 enhancements for this listing this month. Quota resets on ${state.resetDate.toString().split(' ')[0]}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _approveEnhancement(
    BuildContext context,
    ComparisonView state,
  ) {
    context.read<PhotoEnhancementCubit>().approveAndSaveVariant(
      enhancement: state.enhancement,
      listingId: listingId,
      userId: userId,
      originalImagePath: state.originalImagePath,
      isPreview: state.isPreview,
      originalRequest: state.request,
    );
  }

  void _rejectEnhancement(BuildContext context) {
    context.read<PhotoEnhancementCubit>().reset();
  }
}
