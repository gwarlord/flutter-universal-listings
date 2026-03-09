import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/payment_details_model.dart';
import 'package:caribtap/listings/services/payment_details_service.dart';
import 'package:caribtap/listings/services/entitlement_service.dart';
import 'package:caribtap/listings/ui/profile/payment_details/payment_details_cubit.dart';
import 'package:caribtap/listings/ui/subscription/pro_upgrade_screen.dart';

class PaymentDetailsScreen extends StatelessWidget {
  final ListingsUser user;

  const PaymentDetailsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PaymentDetailsCubit(
        paymentDetailsService: PaymentDetailsService(),
        entitlementService: EntitlementService(),
        userId: user.userID,
        isAdmin: user.isAdmin,
      )..loadOnce(),
      child: _PaymentDetailsScreenContent(user: user),
    );
  }
}

class _PaymentDetailsScreenContent extends StatefulWidget {
  final ListingsUser user;

  const _PaymentDetailsScreenContent({required this.user});

  @override
  State<_PaymentDetailsScreenContent> createState() => _PaymentDetailsScreenContentState();
}

class _PaymentDetailsScreenContentState extends State<_PaymentDetailsScreenContent> {
  bool _isProUser = false;
  bool _isCheckingAccess = true;
  bool _showBankExpanded = false;
  late final Future<List<_OwnedListingOption>> _ownedListingsFuture;

  @override
  void initState() {
    super.initState();
    _ownedListingsFuture = _loadOwnedListings();
    _checkProAccess();
  }

  Future<List<_OwnedListingOption>> _loadOwnedListings() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('listings')
        .where('authorID', isEqualTo: widget.user.userID)
        .get();

    final listings = snapshot.docs
        .map(
          (doc) => _OwnedListingOption(
            id: doc.id,
            title: (doc.data()['title'] as String?)?.trim().isNotEmpty == true
                ? (doc.data()['title'] as String).trim()
                : 'Untitled Listing'.tr(),
          ),
        )
        .toList();

    listings.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return listings;
  }

  Future<void> _checkProAccess() async {
    final cubit = context.read<PaymentDetailsCubit>();
    final hasAccess = await cubit.checkProAccess();
    if (mounted) {
      setState(() {
        _isProUser = hasAccess;
        _isCheckingAccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Details'.tr()),
        centerTitle: true,
      ),
      body: BlocConsumer<PaymentDetailsCubit, PaymentDetailsState>(
        listener: (context, state) {
          if (state is PaymentDetailsSaved) {
            showSnackBar(context, '✅ Payment details saved successfully'.tr());
          } else if (state is PaymentDetailsError) {
            showSnackBar(context, state.message);
          }
        },
        builder: (context, state) {
          if (_isCheckingAccess || state is PaymentDetailsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!_isProUser) {
            return _buildUpsellView(context);
          }

          final profile = state is PaymentDetailsLoaded
              ? state.profile
              : state is PaymentDetailsSaving
                  ? state.profile
                  : state is PaymentDetailsSaved
                      ? state.profile
                      : state is PaymentDetailsError && state.profile != null
                          ? state.profile!
                          : const PaymentDetailsProfile();

          return _buildEditableView(context, profile, isDark, state is PaymentDetailsSaving);
        },
      ),
    );
  }

  Widget _buildUpsellView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Payment Details'.tr(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Store your payment information to make it easy for customers to pay you. Available with Professional tier and above.'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProUpgradeScreen(currentUser: widget.user)),
                );
              },
              icon: const Icon(Icons.workspace_premium),
              label: Text('Upgrade to Professional'.tr()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableView(BuildContext context, PaymentDetailsProfile profile, bool isDark, bool isSaving) {
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Card(
            color: Colors.blue.withOpacity(0.1),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add payment details so customers can pay you. Control what\'s visible.'.tr(),
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Enable toggle
          Card(
            color: cardColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor),
            ),
            child: SwitchListTile(
              title: Text(
                'Enable Payment Details'.tr(),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Allow customers to access payment options'.tr(),
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              value: profile.isEnabled,
              activeColor: Colors.white,
              activeTrackColor: Colors.blue[700],
              inactiveTrackColor: isDark ? Colors.grey[700] : Colors.grey[300],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onChanged: (value) {
                context.read<PaymentDetailsCubit>().updateField(
                      (p) => p.copyWith(isEnabled: value),
                    );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Display mode
          if (profile.isEnabled) ...[
            Text(
              'VISIBILITY'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Where should payment details be shown?'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...PaymentDisplayMode.values.map((mode) {
                      return RadioListTile<PaymentDisplayMode>(
                        title: Text(
                          mode.displayText.tr(),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        ),
                        subtitle: Text(
                          _getDisplayModeDescription(mode).tr(),
                          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        value: mode,
                        groupValue: profile.displayMode,
                        onChanged: (value) {
                          if (value != null) {
                            context.read<PaymentDetailsCubit>().updateField(
                                  (p) => p.copyWith(
                                    displayMode: value,
                                    selectedListingIds: value == PaymentDisplayMode.publicListing
                                        ? p.selectedListingIds
                                        : const [],
                                  ),
                                );
                          }
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                    if (profile.displayMode == PaymentDisplayMode.publicListing) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Choose which listings should show these payment details.'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildListingSelector(context, profile),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bank Transfer
            Text(
              'BANK TRANSFER'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Enable Bank Transfer'.tr(),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: profile.bankTransfer.enabled,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.blue[700],
                    inactiveTrackColor: isDark ? Colors.grey[700] : Colors.grey[300],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onChanged: (value) {
                      context.read<PaymentDetailsCubit>().updateField(
                            (p) => p.copyWith(

                              bankTransfer: p.bankTransfer.copyWith(enabled: value),
                            ),
                          );
                    },
                  ),
                  if (profile.bankTransfer.enabled) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildTextField(
                            label: 'Bank Name'.tr(),
                            value: profile.bankTransfer.bankName,
                            onChanged: (value) {
                              context.read<PaymentDetailsCubit>().updateField(
                                    (p) => p.copyWith(
                                      bankTransfer: p.bankTransfer.copyWith(bankName: value),
                                    ),
                                  );
                            },
                            required: true,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            label: 'Account Name'.tr(),
                            value: profile.bankTransfer.accountName,
                            onChanged: (value) {
                              context.read<PaymentDetailsCubit>().updateField(
                                    (p) => p.copyWith(
                                      bankTransfer: p.bankTransfer.copyWith(accountName: value),
                                    ),
                                  );
                            },
                            required: true,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            label: 'Account Number'.tr(),
                            value: profile.bankTransfer.accountNumber,
                            onChanged: (value) {
                              context.read<PaymentDetailsCubit>().updateField(
                                    (p) => p.copyWith(
                                      bankTransfer: p.bankTransfer.copyWith(accountNumber: value),
                                    ),
                                  );
                            },
                            required: true,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            label: 'Branch'.tr(),
                            value: profile.bankTransfer.branch,
                            onChanged: (value) {
                              context.read<PaymentDetailsCubit>().updateField(
                                    (p) => p.copyWith(
                                      bankTransfer: p.bankTransfer.copyWith(branch: value),
                                    ),
                                  );
                            },
                          ),
                          const SizedBox(height: 16),
                          // Expandable section for optional fields
                          InkWell(
                            onTap: () {
                              setState(() => _showBankExpanded = !_showBankExpanded);
                            },
                            child: Row(
                              children: [
                                Icon(
                                  _showBankExpanded ? Icons.expand_less : Icons.expand_more,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Optional Fields'.tr(),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_showBankExpanded) ...[
                            const SizedBox(height: 12),
                            _buildTextField(
                              label: 'SWIFT/BIC'.tr(),
                              value: profile.bankTransfer.swiftBic,
                              onChanged: (value) {
                                context.read<PaymentDetailsCubit>().updateField(
                                      (p) => p.copyWith(
                                        bankTransfer: p.bankTransfer.copyWith(swiftBic: value),
                                      ),
                                    );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              label: 'IBAN'.tr(),
                              value: profile.bankTransfer.iban,
                              onChanged: (value) {
                                context.read<PaymentDetailsCubit>().updateField(
                                      (p) => p.copyWith(
                                        bankTransfer: p.bankTransfer.copyWith(iban: value),
                                      ),
                                    );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              label: 'Currency'.tr(),
                              value: profile.bankTransfer.currency,
                              onChanged: (value) {
                                context.read<PaymentDetailsCubit>().updateField(
                                      (p) => p.copyWith(
                                        bankTransfer: p.bankTransfer.copyWith(currency: value),
                                      ),
                                    );
                              },
                              hint: 'TTD, USD, etc.'.tr(),
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              label: 'Instructions'.tr(),
                              value: profile.bankTransfer.instructions,
                              onChanged: (value) {
                                context.read<PaymentDetailsCubit>().updateField(
                                      (p) => p.copyWith(
                                        bankTransfer: p.bankTransfer.copyWith(instructions: value),
                                      ),
                                    );
                              },
                              hint: 'e.g., Use invoice number as reference'.tr(),
                              maxLines: 2,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '⚠️ Only share details you\'re comfortable sharing publicly'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Apps
            Text(
              'PAYMENT APPS'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor),
              ),
              child: Column(
                children: [
                  ...profile.paymentApps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final app = entry.value;
                    return _buildPaymentApp(context, app, index, profile);
                  }),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddPaymentAppDialog(context, profile),
                      icon: const Icon(Icons.add),
                      label: Text('Add Payment App'.tr()),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Notes
            Text(
              'CUSTOMER NOTES'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildTextField(
                  label: 'Additional Notes'.tr(),
                  value: profile.notes,
                  onChanged: (value) {
                    context.read<PaymentDetailsCubit>().updateField(
                          (p) => p.copyWith(notes: value),
                        );
                  },
                  hint: 'Optional notes for customers (no sensitive data)'.tr(),
                  maxLines: 3,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () {
                        if (_validateProfile(profile)) {
                          context.read<PaymentDetailsCubit>().saveProfile(profile);
                        } else {
                          showSnackBar(
                            context,
                            profile.displayMode == PaymentDisplayMode.publicListing &&
                                    profile.selectedListingIds.isEmpty
                                ? 'Select at least one listing to show payment details on.'.tr()
                                : 'Please fill in all required fields for enabled payment methods'.tr(),
                          );
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Save Payment Details'.tr(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentApp(BuildContext context, PaymentApp app, int index, PaymentDetailsProfile profile) {
    return Column(
      children: [
        if (index > 0) const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      app.label.isNotEmpty ? app.label : app.type.displayText,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDarkMode(context) ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Switch(
                    value: app.enabled,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.blue[700],
                    inactiveTrackColor: isDarkMode(context) ? Colors.grey[700] : Colors.grey[300],
                    onChanged: (value) {
                      final updatedApps = List<PaymentApp>.from(profile.paymentApps);
                      updatedApps[index] = app.copyWith(enabled: value);
                      context.read<PaymentDetailsCubit>().updateField(
                            (p) => p.copyWith(paymentApps: updatedApps),
                          );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      final updatedApps = List<PaymentApp>.from(profile.paymentApps)..removeAt(index);
                      context.read<PaymentDetailsCubit>().updateField(
                            (p) => p.copyWith(paymentApps: updatedApps),
                          );
                    },
                  ),
                ],
              ),
              if (app.enabled) ...[
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Handle/Email/Phone'.tr(),
                  value: app.handle,
                  onChanged: (value) {
                    final updatedApps = List<PaymentApp>.from(profile.paymentApps);
                    updatedApps[index] = app.copyWith(handle: value);
                    context.read<PaymentDetailsCubit>().updateField(
                          (p) => p.copyWith(paymentApps: updatedApps),
                        );
                  },
                  required: true,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Link (Optional)'.tr(),
                  value: app.url,
                  onChanged: (value) {
                    final updatedApps = List<PaymentApp>.from(profile.paymentApps);
                    updatedApps[index] = app.copyWith(url: value);
                    context.read<PaymentDetailsCubit>().updateField(
                          (p) => p.copyWith(paymentApps: updatedApps),
                        );
                  },
                  keyboardType: TextInputType.url,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListingSelector(BuildContext context, PaymentDetailsProfile profile) {
    final isDark = isDarkMode(context);

    return FutureBuilder<List<_OwnedListingOption>>(
      future: _ownedListingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Unable to load your listings right now.'.tr(),
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
          );
        }

        final listings = snapshot.data ?? const <_OwnedListingOption>[];
        if (listings.isEmpty) {
          return Text(
            'You do not have any listings yet.'.tr(),
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
          );
        }

        final selectedIds = profile.selectedListingIds.toSet();

        return Column(
          children: listings.map((listing) {
            return CheckboxListTile(
              value: selectedIds.contains(listing.id),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(
                listing.title,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              onChanged: (value) {
                final updatedIds = List<String>.from(profile.selectedListingIds);
                if (value == true) {
                  if (!updatedIds.contains(listing.id)) {
                    updatedIds.add(listing.id);
                  }
                } else {
                  updatedIds.remove(listing.id);
                }

                context.read<PaymentDetailsCubit>().updateField(
                      (p) => p.copyWith(selectedListingIds: updatedIds),
                    );
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _showAddPaymentAppDialog(BuildContext context, PaymentDetailsProfile profile) {
    final isDark = isDarkMode(context);
    final dialogBgColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBgColor,
          title: Text(
            'Add Payment App'.tr(),
            style: TextStyle(color: textColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: PaymentAppType.values.map((type) {
                return ListTile(
                  title: Text(
                    type.displayText,
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () {
                    final newApp = PaymentApp(type: type, label: type.displayText);
                    final updatedApps = [...profile.paymentApps, newApp];
                    context.read<PaymentDetailsCubit>().updateField(
                          (p) => p.copyWith(paymentApps: updatedApps),
                        );
                    Navigator.pop(dialogContext);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    String? hint,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final isDark = isDarkMode(context);
    final labelColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final inputColor = isDark ? Colors.white : Colors.black87;
    
    return TextField(
      controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
      onChanged: onChanged,
      style: TextStyle(color: inputColor),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: TextStyle(color: labelColor),
        hintText: hint,
        hintStyle: TextStyle(color: hintColor),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
    );
  }

  String _getDisplayModeDescription(PaymentDisplayMode mode) {
    switch (mode) {
      case PaymentDisplayMode.private:
        return 'Only visible to you';
      case PaymentDisplayMode.invoiceOnly:
        return 'Show on invoices and quotes';
      case PaymentDisplayMode.publicListing:
        return 'Show on listings and invoices';
    }
  }

  bool _validateProfile(PaymentDetailsProfile profile) {
    if (!profile.isEnabled) return true;

    if (profile.displayMode == PaymentDisplayMode.publicListing &&
        profile.selectedListingIds.isEmpty) {
      return false;
    }

    if (profile.bankTransfer.enabled) {
      if (profile.bankTransfer.bankName.isEmpty ||
          profile.bankTransfer.accountName.isEmpty ||
          profile.bankTransfer.accountNumber.isEmpty) {
        return false;
      }
    }

    for (final app in profile.paymentApps) {
      if (app.enabled && app.handle.isEmpty && app.url.isEmpty) {
        return false;
      }
    }

    return true;
  }
}

class _OwnedListingOption {
  final String id;
  final String title;

  const _OwnedListingOption({
    required this.id,
    required this.title,
  });
}
