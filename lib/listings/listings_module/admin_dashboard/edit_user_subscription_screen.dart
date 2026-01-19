import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/listings_user.dart';

class EditUserSubscriptionScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const EditUserSubscriptionScreen({super.key, required this.currentUser});

  @override
  State<EditUserSubscriptionScreen> createState() => _EditUserSubscriptionScreenState();
}

class _EditUserSubscriptionScreenState extends State<EditUserSubscriptionScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;
  ListingsUser? _loadedUser;
  String _selectedTier = 'free';
  String? _error;

  final List<String> _tiers = ['free', 'pro', 'premium', 'business'];

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() {
        _error = 'Enter an email to load user.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final query = await FirebaseFirestore.instance
          .collection(usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        setState(() {
          _loadedUser = null;
          _error = 'No user found for that email.';
          _isLoading = false;
        });
        return;
      }
      final doc = query.docs.first;
      final data = doc.data();
      data['id'] = data['id'] ?? data['userID'] ?? doc.id;
      final user = ListingsUser.fromJson(data);
      setState(() {
        _loadedUser = user;
        _selectedTier = (user.subscriptionTier.isNotEmpty ? user.subscriptionTier : 'free').toLowerCase();
        if (!_tiers.contains(_selectedTier)) {
          _selectedTier = 'free';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load user.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTier() async {
    if (_loadedUser == null) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      print('💾 Updating subscription for ${_loadedUser!.userID} to $_selectedTier');
      
      await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(_loadedUser!.userID)
          .set({'subscriptionTier': _selectedTier}, SetOptions(merge: true));
      
      print('✅ Subscription updated successfully');
      
      setState(() {
        _loadedUser = _loadedUser!..subscriptionTier = _selectedTier;
        _isSaving = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subscription updated to $_selectedTier'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error updating subscription: $e');
      print('📋 Stack trace: ${StackTrace.current}');
      setState(() {
        _error = 'Failed to update subscription: ${e.toString()}';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit User Subscription'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'User email',
                labelStyle: TextStyle(
                  color: isDarkMode(context) ? Colors.white70 : null,
                ),
                suffixIcon: IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  onPressed: _isLoading ? null : _loadUser,
                ),
              ),
              onSubmitted: (_) => _loadUser(),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            if (_loadedUser != null) ...[
              Card(
                margin: const EdgeInsets.only(top: 12),
                color: isDarkMode(context) ? Colors.grey.shade900 : null,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loadedUser!.fullName(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode(context) ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _loadedUser!.email,
                        style: TextStyle(
                          color: isDarkMode(context) ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Subscription tier:',
                            style: TextStyle(
                              color: isDarkMode(context) ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _selectedTier,
                            dropdownColor: isDarkMode(context) ? Colors.grey.shade800 : null,
                            items: _tiers
                                .map(
                                  (t) => DropdownMenuItem<String>(
                                    value: t,
                                    child: Text(
                                      t.toUpperCase(),
                                      style: TextStyle(
                                        color: isDarkMode(context) ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _isSaving
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() => _selectedTier = value);
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveTier,
                          child: _isSaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
