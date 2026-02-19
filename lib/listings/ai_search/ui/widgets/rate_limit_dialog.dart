import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:caribtap/listings/ai_search/utils/search_constants.dart';

/// Dialog shown when rate limit is exceeded
class RateLimitDialog extends StatelessWidget {
  final String message;
  final String? upgradeMessage;
  final VoidCallback? onKeywordSearch;
  final VoidCallback? onUpgrade;

  const RateLimitDialog({
    Key? key,
    required this.message,
    this.upgradeMessage,
    this.onKeywordSearch,
    this.onUpgrade,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.block, color: SearchConstants.warningColor),
          const SizedBox(width: 8),
          Text('Search Limit Reached'.tr()),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (upgradeMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SearchConstants.primarySearchColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: SearchConstants.primarySearchColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium,
                      color: SearchConstants.primarySearchColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      upgradeMessage!,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'You can still use basic keyword search (unlimited)'.tr(),
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        if (onKeywordSearch != null)
          TextButton(
            child: Text('Use Keyword Search'.tr()),
            onPressed: onKeywordSearch,
          ),
        if (upgradeMessage != null && onUpgrade != null)
          ElevatedButton.icon(
            icon: const Icon(Icons.workspace_premium, size: 18),
            label: Text('Upgrade Now'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: SearchConstants.primarySearchColor,
              foregroundColor: Colors.white,
            ),
            onPressed: onUpgrade,
          ),
        TextButton(
          child: Text('Close'.tr()),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
