import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/listings_user.dart';

class EditUserSubscriptionScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const EditUserSubscriptionScreen({super.key, required this.currentUser});

  @override
  State<EditUserSubscriptionScreen> createState() =>
      _EditUserSubscriptionScreenState();
}

class _EditUserSubscriptionScreenState
    extends State<EditUserSubscriptionScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingSuggestions = false;
  ListingsUser? _loadedUser;
  String? _loadedUserDocId;
  String _selectedTier = 'free';
  String? _error;
  Timer? _suggestionDebounce;
  int _suggestionRequestId = 0;
  List<_UserSuggestion> _suggestions = const [];
  bool _showSuggestions = false;
  bool _ignoreNextEmailChange = false;

  final List<String> _tiers = ['free', 'professional', 'premium'];

  int _tierNumberFromName(String tierName) {
    switch (tierName.trim().toLowerCase()) {
      case 'premium':
        return 3;
      case 'professional':
      case 'pro':
        return 2;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    if (_ignoreNextEmailChange) {
      _ignoreNextEmailChange = false;
      return;
    }
    _suggestionDebounce?.cancel();
    final query = _emailController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _suggestions = const [];
        _isLoadingSuggestions = false;
        _showSuggestions = false;
      });
      return;
    }
    _suggestionDebounce = Timer(const Duration(milliseconds: 250), () {
      _loadSuggestions(query);
    });
  }

  Future<void> _loadSuggestions(String query) async {
    final requestId = ++_suggestionRequestId;
    setState(() {
      _isLoadingSuggestions = true;
      _showSuggestions = true;
    });
    try {
      final result = await FirebaseFirestore.instance
          .collection(usersCollection)
          .orderBy('email')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(8)
          .get();

      if (!mounted || requestId != _suggestionRequestId) return;

      setState(() {
        _suggestions = result.docs
            .map((doc) {
              final data = doc.data();
              final email = (data['email'] ?? '').toString();
              final firstName = (data['firstName'] ?? '').toString();
              final lastName = (data['lastName'] ?? '').toString();
              final fullName = '$firstName $lastName'.trim();
              return _UserSuggestion(
                docId: doc.id,
                email: email,
                fullName: fullName,
                subscriptionTier:
                    (data['subscriptionTier'] ?? 'free').toString(),
              );
            })
            .where((entry) => entry.email.isNotEmpty)
            .toList();
        _isLoadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted || requestId != _suggestionRequestId) return;
      setState(() {
        _suggestions = const [];
        _isLoadingSuggestions = false;
      });
    }
  }

  void _setLoadedUser(String docId, Map<String, dynamic> data) {
    data['id'] = data['id'] ?? data['userID'] ?? docId;
    final user = ListingsUser.fromJson(data);
    setState(() {
      _loadedUser = user;
      _loadedUserDocId = docId;
      _selectedTier =
          (user.subscriptionTier.isNotEmpty ? user.subscriptionTier : 'free')
              .toLowerCase();
      if (!_tiers.contains(_selectedTier)) {
        _selectedTier = 'free';
      }
      _isLoading = false;
    });
  }

  Future<void> _loadUserByDocId(String docId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _loadedUser = null;
      _showSuggestions = false;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(docId)
          .get();
      if (!doc.exists || doc.data() == null) {
        setState(() {
          _error = 'No user found for that email.'.tr();
          _isLoading = false;
        });
        return;
      }
      _setLoadedUser(doc.id, doc.data()!);
    } catch (_) {
      setState(() {
        _error = 'Failed to load user.'.tr();
        _isLoading = false;
      });
    }
  }

  void _selectSuggestion(_UserSuggestion suggestion) {
    _ignoreNextEmailChange = true;
    _emailController.text = suggestion.email;
    _emailController.selection =
        TextSelection.collapsed(offset: _emailController.text.length);
    setState(() {
      _showSuggestions = false;
      _suggestions = const [];
      _error = null;
    });
    _loadUserByDocId(suggestion.docId);
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
      _showSuggestions = false;
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
      _setLoadedUser(doc.id, doc.data());
    } catch (_) {
      setState(() {
        _error = 'Failed to load user.'.tr();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTier() async {
    if (_loadedUser == null || _loadedUserDocId == null) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final previousTier = _loadedUser!.subscriptionTier.toLowerCase();
      // Update user's subscription tier and expiration
      final isPaidTier = _selectedTier != 'free';
      final updateData = <String, dynamic>{
        'subscriptionTier': _selectedTier,
        'isSubscriptionActive': isPaidTier,
        // Set far future expiration for paid tiers (100 years), null for free
        'subscriptionExpiresAt': isPaidTier
            ? Timestamp.fromDate(
                DateTime.now().add(const Duration(days: 36500)))
            : null,
      };
      final firestore = FirebaseFirestore.instance;

      // Update all listings owned by this user with new tier snapshot.
      // Some records use Firestore doc ID while others use model userID.
      final authorIds = <String>{_loadedUserDocId!};
      if (_loadedUser!.userID.isNotEmpty) {
        authorIds.add(_loadedUser!.userID);
      }

      final listingDocsById =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final authorId in authorIds) {
        final listingsQuery = await firestore
            .collection('listings')
            .where('authorID', isEqualTo: authorId)
            .get();
        for (final doc in listingsQuery.docs) {
          listingDocsById[doc.id] = doc;
        }
      }

      final batch = firestore.batch();
      final userRef =
          firestore.collection(usersCollection).doc(_loadedUserDocId);
      batch.set(userRef, updateData, SetOptions(merge: true));

      final entitlementRef = userRef
          .collection('entitlements')
          .doc('subscription');
      batch.set(entitlementRef, {
        'platform': 'admin_manual',
        'productId': 'manual_${_selectedTier}_tier',
        'tier': _tierNumberFromName(_selectedTier),
        'status': isPaidTier ? 'active' : 'inactive',
        'expiresAt': updateData['subscriptionExpiresAt'],
        'willRenew': false,
        'lastVerifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (final doc in listingDocsById.values) {
        batch.update(doc.reference, {
          'listerTierSnapshot': _selectedTier,
          'updatedAt': Timestamp.now(),
        });
      }

      final auditRef =
          firestore.collection('admin_subscription_audit_logs').doc();
      batch.set(auditRef, {
        'action': 'edit_user_subscription',
        'targetUserDocId': _loadedUserDocId,
        'targetUserId': _loadedUser!.userID,
        'targetEmail': _loadedUser!.email.toLowerCase(),
        'previousTier': previousTier,
        'newTier': _selectedTier,
        'listingsUpdatedCount': listingDocsById.length,
        'adminUserId': widget.currentUser.userID,
        'adminEmail': widget.currentUser.email.toLowerCase(),
        'authorIdsChecked': authorIds.toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      setState(() {
        _loadedUser!.subscriptionTier = _selectedTier;
        _isSaving = false;
      });
      if (!mounted) return;
      showSnackBar(
          context,
          'Subscription updated to ${_selectedTier.toUpperCase()} (${listingDocsById.length} listings updated)'
              .tr());
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
                border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'Enter user email'.tr(),
                  hintStyle: TextStyle(
                      color: isDark ? Colors.grey[600] : Colors.grey[400]),
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
            if (_showSuggestions) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                ),
                child: _isLoadingSuggestions
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Center(
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : _suggestions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              'No matching users found.'.tr(),
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600]),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[200],
                            ),
                            itemBuilder: (context, index) {
                              final suggestion = _suggestions[index];
                              final hasName = suggestion.fullName.isNotEmpty;
                              return ListTile(
                                dense: true,
                                onTap: () => _selectSuggestion(suggestion),
                                title: Text(
                                  suggestion.email,
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87),
                                ),
                                subtitle:
                                    hasName ? Text(suggestion.fullName) : null,
                                trailing: Text(
                                  suggestion.subscriptionTier.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
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
                  side: BorderSide(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
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
                            child: Icon(Icons.person_outline,
                                color: Color(colorPrimary)),
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
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  _loadedUser!.email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
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
                            style: TextStyle(
                                color:
                                    isDark ? Colors.white70 : Colors.black54),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
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
                    onSelected: _isSaving
                        ? null
                        : (selected) {
                            if (selected) setState(() => _selectedTier = tier);
                          },
                    selectedColor: Color(colorPrimary),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor:
                        isDark ? Colors.grey[800] : Colors.grey[200],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _saveTier,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Update Subscription'.tr(),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
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

class _UserSuggestion {
  final String docId;
  final String email;
  final String fullName;
  final String subscriptionTier;

  const _UserSuggestion({
    required this.docId,
    required this.email,
    required this.fullName,
    required this.subscriptionTier,
  });
}
