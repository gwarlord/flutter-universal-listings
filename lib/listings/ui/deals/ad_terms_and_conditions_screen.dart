import 'package:flutter/material.dart';

class AdTermsAndConditionsScreen extends StatefulWidget {
  final VoidCallback onAccepted;
  const AdTermsAndConditionsScreen({Key? key, required this.onAccepted}) : super(key: key);

  @override
  State<AdTermsAndConditionsScreen> createState() => _AdTermsAndConditionsScreenState();
}

class _AdTermsAndConditionsScreenState extends State<AdTermsAndConditionsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolledToEnd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If content fits without scrolling, enable button
      if (_scrollController.position.maxScrollExtent == 0) {
        setState(() {
          _scrolledToEnd = true;
        });
      }
    });
    _scrollController.addListener(() {
      if (_scrollController.offset >= _scrollController.position.maxScrollExtent && !_scrollController.position.outOfRange) {
        setState(() {
          _scrolledToEnd = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ad Terms & Conditions')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () {
                  // If not scrollable, allow tap to enable button
                  if (_scrollController.position.maxScrollExtent == 0 && !_scrolledToEnd) {
                    setState(() {
                      _scrolledToEnd = true;
                    });
                  }
                },
                child: Scrollbar(
                  controller: _scrollController,
                  child: ListView(
                    controller: _scrollController,
                    children: const [
                      Text('''\
1. All ads must comply with CaribTap community guidelines.\n\n2. No illegal, offensive, or misleading content.\n\n3. Ads are subject to approval and may be rejected without refund if they violate terms.\n\n4. Payment is required before ad review.\n\n5. CaribTap reserves the right to remove ads at any time.\n\n6. By posting, you agree to all terms and conditions.\n'''),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), // Extra bottom padding for button
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _scrolledToEnd ? widget.onAccepted : null,
                child: const Text('Accept & Continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
