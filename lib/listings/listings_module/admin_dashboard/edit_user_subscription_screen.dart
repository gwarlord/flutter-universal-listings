import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
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

  final List<String> _tiers = ['free', 'professional', 'premium', 'business'];

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _error = 'Enter an email to load user.'.tr());
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _loadedUser = null;
    });
    try {
      final query = await FirebaseFirestore.instance
          .collection(usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        setState(() {
          _error = 'No user found for that email.'.tr();
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
        _error = 'Failed to load user.'.tr();
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
      await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(_loadedUser!.userID)
          .set({'subscriptionTier': _selectedTier}, SetOptions(merge: true));
      
      setState(() {
        _loadedUser!.subscriptionTier = _selectedTier;
        _isSaving = false;
      });
      if (!mounted) return;
      showSnackBar(context, 'Subscription updated to'.tr() + ' ${_selectedTier.toUpperCase()}');
    } catch (e) {
      setState(() {
        _error = 'Failed to update subscription.'.tr();
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.grey[400] : Colors.grey[600],
      letterSpacing: 1.2,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Subscriptions'.tr()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SEARCH USER'.tr(), style: titleStyle),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'Enter user email'.tr(),
                  hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.search, color: Color(colorPrimary)),
                    onPressed: _isLoading ? null : _loadUser,
                  ),
                ),
                onSubmitted: (_) => _loadUser(),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            if (_loadedUser != null) ...[
              const SizedBox(height: 32),
              Text('USER INFORMATION'.tr(), style: titleStyle),
              const SizedBox(height: 12),
              Card(
                color: cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Color(colorPrimary).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.person_outline, color: Color(colorPrimary)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _loadedUser!.fullName(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  _loadedUser!.email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Current Tier'.tr(),
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(colorPrimary).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _loadedUser!.subscriptionTier.toUpperCase(),
                              style: TextStyle(
                                color: Color(colorPrimary),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text('SELECT NEW TIER'.tr(), style: titleStyle),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tiers.map((tier) {
                  final isSelected = _selectedTier == tier;
                  return ChoiceChip(
                    label: Text(tier.toUpperCase()),
                    selected: isSelected,
                    onSelected: _isSaving ? null : (selected) {
                      if (selected) setState(() => _selectedTier = tier);
                    },
                    selectedColor: Color(colorPrimary),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(colorPrimary),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _saveTier,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Update Subscription'.tr(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
