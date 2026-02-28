import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:caribtap/listings/ai_search/utils/search_constants.dart';

/// AI-powered search bar widget
class AiSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final String? hintPrompt;

  const AiSearchBar({
    Key? key,
    required this.controller,
    required this.onSearch,
    this.hintPrompt,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey[100] : Colors.black87;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: hintPrompt ?? 'Search with AI...'.tr(),
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.auto_awesome, 
              color: SearchConstants.aiIndicatorColor),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    controller.clear();
                  },
                ),
              IconButton(
                icon: const Icon(Icons.search),
                color: SearchConstants.primarySearchColor,
                onPressed: () => onSearch(controller.text),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: onSearch,
      ),
    );
  }
}
