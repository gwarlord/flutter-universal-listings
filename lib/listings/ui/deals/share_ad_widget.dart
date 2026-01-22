import 'package:flutter/material.dart';

class ShareAdWidget extends StatelessWidget {
  final String adTitle;
  final String adUrl;
  const ShareAdWidget({Key? key, required this.adTitle, required this.adUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share),
      onPressed: () {
        // TODO: Implement share logic (e.g., using share_plus package)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Share functionality coming soon!')),
        );
      },
      tooltip: 'Share',
    );
  }
}
