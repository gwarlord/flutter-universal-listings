import 'package:flutter/material.dart';

class AdFormatGuidanceScreen extends StatelessWidget {
  const AdFormatGuidanceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ad Format Guidance'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Image & Video Requirements',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const Text('- Images: JPG, PNG, 1080x1080px minimum'),
            const Text('- Videos: MP4, MOV, max 30 seconds, 1080p'),
            const Text('- No watermarks or offensive content'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
