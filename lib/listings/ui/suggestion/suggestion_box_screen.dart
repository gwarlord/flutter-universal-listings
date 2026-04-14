import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/model/listings_user.dart';

class SuggestionBoxScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const SuggestionBoxScreen({super.key, required this.currentUser});

  @override
  State<SuggestionBoxScreen> createState() => _SuggestionBoxScreenState();
}

class _SuggestionBoxScreenState extends State<SuggestionBoxScreen> {
  static const _categories = [
    'Look & Feel',
    'Listing Feature',
    'General App Feature',
    'Search & Discovery',
    'Performance & Reliability',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _suggestionController = TextEditingController();
  String _selectedCategory = 'General App Feature';
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _suggestionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final user = widget.currentUser;
      await FirebaseFirestore.instance.collection('app_suggestions').add({
        'suggestion': _suggestionController.text.trim(),
        'category': _selectedCategory,
        'userName': user.fullName(),
        'userEmail': user.email,
        'userId': user.userID,
        'createdAt': FieldValue.serverTimestamp(),
        'archived': false,
      });

      if (!mounted) return;
      setState(() {
        _submitted = true;
        _submitting = false;
      });
    } catch (e, stack) {
      debugPrint('SuggestionBox submit error: $e\n$stack');
      if (!mounted) return;
      setState(() => _submitting = false);
      showSnackBar(context, 'Failed to submit suggestion. Please try again.'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final primary = Color(cfg.colorPrimary);

    return Scaffold(
      appBar: AppBar(
        title: Text('Suggestion Box'.tr()),
      ),
      body: _submitted ? _buildSuccessState(dark, primary) : _buildForm(dark, primary),
    );
  }

  Widget _buildSuccessState(bool dark, Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: primary.withOpacity(0.12),
              child: Icon(Icons.check_rounded, size: 40, color: primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Thank you!'.tr(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: dark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your suggestion has been submitted. We review all feedback and use it to improve the app.'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: dark ? Colors.white70 : Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _submitted = false;
                  _suggestionController.clear();
                  _selectedCategory = 'General App Feature';
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary.withOpacity(0.5)),
              ),
              child: Text('Submit another'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool dark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primary.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Have an idea to improve the app? We\'d love to hear it!'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: dark ? Colors.white70 : Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Category picker
            Text(
              'Category'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              dropdownColor: dark ? Colors.grey.shade900 : Colors.white,
              items: _categories.map((cat) => DropdownMenuItem(
                value: cat,
                child: Text(cat.tr(), style: TextStyle(color: dark ? Colors.white : Colors.black87)),
              )).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 20),

            // Suggestion text
            Text(
              'Your suggestion'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _suggestionController,
              minLines: 5,
              maxLines: 10,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Describe your idea or feedback in as much detail as you like...'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
              validator: (val) {
                if (val == null || val.trim().length < 10) {
                  return 'Please enter at least 10 characters.'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_submitting ? 'Submitting...'.tr() : 'Submit Suggestion'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Submissions are anonymous to other users and reviewed only by the app team.'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: dark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
