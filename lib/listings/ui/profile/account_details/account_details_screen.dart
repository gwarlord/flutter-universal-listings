import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/utils/caribbean_countries.dart';
import 'package:caribtap/listings/utils/country_search_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/core/utils/phone_number_utils.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/ui/auth/reauth_user/reauth_user_bloc.dart';
import 'package:caribtap/listings/ui/auth/reauth_user/reauth_user_screen.dart';
import 'package:caribtap/core/ui/loading/loading_cubit.dart';
import 'package:caribtap/listings/ui/profile/account_details/account_details_bloc.dart';
import 'package:caribtap/listings/ui/profile/api/profile_api_manager.dart';

class AccountDetailsWrapperWidget extends StatelessWidget {
  final ListingsUser user;

  const AccountDetailsWrapperWidget({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AccountDetailsBloc(
        profileRepository: profileApiManager,
        currentUser: user,
      ),
      child: AccountDetailsScreen(user: user),
    );
  }
}

class AccountDetailsScreen extends StatefulWidget {
  final ListingsUser user;

  const AccountDetailsScreen({super.key, required this.user});

  @override
  State<AccountDetailsScreen> createState() {
    return _AccountDetailsScreenState();
  }
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  late ListingsUser user;
  final GlobalKey<FormState> _key = GlobalKey();
  final TextEditingController _phoneController = TextEditingController();
  AutovalidateMode _validate = AutovalidateMode.disabled;
  String? firstName, email, mobile, lastName;
  String? _countryCode;
  String? validateCountry(String? code) {
    if (code == null || code.trim().isEmpty) {
      return 'Country is required';
    }
    return null;
  }

  String? _validateAccountPhoneInput(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Mobile is required'.tr();
    }

    final digitCount = digitsOnly(trimmed).length;
    if (digitCount < 7 || digitCount > 15) {
      return 'Enter a valid phone number.'.tr();
    }

    return null;
  }

  String _phoneFieldGuidance() {
    return phoneGuidanceMessage(_countryCode ?? user.countryCode);
  }

  String _countryDisplayName() {
    return CaribbeanCountries.all
        .firstWhere(
          (c) => c.code == _countryCode,
          orElse: () => const CaribbeanCountry(code: '', name: ''),
        )
        .name;
  }

  @override
  void initState() {
    super.initState();
    user = widget.user;
    _countryCode = user.countryCode.isEmpty ? null : user.countryCode;
    _syncPhoneDisplayText();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _syncPhoneDisplayText() async {
    final rawPhone = user.phoneNumber.trim();
    final isoCode = (_countryCode ?? user.countryCode).trim();

    if (rawPhone.isEmpty || isoCode.isEmpty) {
      _phoneController.text = rawPhone;
      return;
    }

    final formatted = await formatPhoneForDisplay(rawPhone, isoCode);
    if (!mounted) return;
    _phoneController.text = formatted;
  }

  Future<void> _refreshUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(user.userID)
          .get(const GetOptions(source: Source.server));

      if (!doc.exists) return;
      final freshUser = ListingsUser.fromJson(doc.data()!);
      if (!mounted) return;
      setState(() => user = freshUser);
      await _syncPhoneDisplayText();
      if (!mounted) return;
      context.read<AuthenticationBloc>().add(UpdateAuthUserEvent(freshUser));
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Failed to refresh account details'.tr());
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
        title: Text('Account Details'.tr()),
        centerTitle: true,
      ),
      body: BlocConsumer<AccountDetailsBloc, AccountDetailsState>(
        listener: (_, state) async {
          if (state is AccountFieldsRequiredState) {
            showSnackBar(this.context, 'Some fields are required.'.tr());
            _validate = AutovalidateMode.onUserInteraction;
          } else if (state is AccountValidationErrorState) {
            showSnackBar(this.context, state.message);
            _validate = AutovalidateMode.onUserInteraction;
          } else if (state is ValidFieldsState) {
            this.context.read<AccountDetailsBloc>().add(TryToSubmitDataEvent(
                  firstName: firstName!,
                  lastName: lastName!,
                  emailAddress: email!,
                  phoneNumber: mobile!,
                  countryCode: _countryCode ?? '',
                ));
          } else if (state is ReauthRequiredState) {
            final authState = this.context.read<AuthenticationBloc>().state;
            final currentEmail = authState.user?.email;
            bool result = await showDialog(
              context: this.context,
              builder: (context) => ReAuthUserScreen(
                provider: state.authProvider,
                phoneNumber: state.authProvider == AuthProviders.phone
                    ? state.data
                    : null,
                newEmail: state.authProvider == AuthProviders.password
                    ? state.data
                    : null,
                currentEmail: state.authProvider == AuthProviders.password
                    ? currentEmail
                    : null,
                isDeleteUser: false,
              ),
            );

            if (!mounted) return;
            if (result == true) {
              this.context.read<LoadingCubit>().showLoading(
                    this.context,
                    'Saving details...'.tr(),
                    false,
                    Color(colorPrimary),
                  );
              this.context.read<AccountDetailsBloc>().add(UpdateUserDataEvent(
                    firstName: firstName!,
                    lastName: lastName!,
                    emailAddress: email!,
                    phoneNumber: mobile!,
                    countryCode: _countryCode ?? '',
                  ));
            }
          } else if (state is UpdatingDataState) {
            this.context.read<LoadingCubit>().showLoading(
                  this.context,
                  'Saving details...'.tr(),
                  false,
                  Color(colorPrimary),
                );
          } else if (state is UserDataUpdatedState) {
            this.context.read<LoadingCubit>().hideLoading();
            if (!mounted) return;
            setState(() => user = state.updatedUser);
            await _syncPhoneDisplayText();
            if (!mounted) return;
            this.context.read<AuthenticationBloc>().user = state.updatedUser;
            showSnackBar(this.context, 'Details saved successfully'.tr());
          }
        },
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: _refreshUserData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Form(
                key: _key,
                autovalidateMode: _validate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text('SUBSCRIPTION'.tr(), style: titleStyle),
                  const SizedBox(height: 12),
                  Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            context,
                            'Current Tier'.tr(),
                            user.isAdmin ? 'ADMIN' : user.subscriptionTier.toUpperCase(),
                            icon: Icons.star_border,
                            valueColor: user.isAdmin ? Colors.green : Color(colorPrimary),
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            context,
                            'Status'.tr(),
                            user.isSubscriptionActive ? 'Active'.tr() : 'Expired'.tr(),
                            icon: Icons.check_circle_outline,
                            valueColor: user.isSubscriptionActive ? Colors.green : Colors.red,
                          ),
                          if (user.subscriptionExpiresAt != null) ...[
                            const Divider(height: 24),
                            _buildDetailRow(
                              context,
                              'Renews / Expires'.tr(),
                              DateFormat.yMMMMd().format(user.subscriptionExpiresAt!),
                              icon: Icons.calendar_today,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('PUBLIC INFORMATION'.tr(), style: titleStyle),
                  const SizedBox(height: 12),
                  Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Country select
                          GestureDetector(
                            onTap: () async {
                              final selected = await showCountrySearchDialog(context, _countryCode);
                              if (selected != null) setState(() => _countryCode = selected);
                            },
                            child: AbsorbPointer(
                              child: TextFormField(
                                initialValue: _countryDisplayName(),
                                validator: (_) => validateCountry(_countryCode),
                                decoration: InputDecoration(
                                  labelText: 'Country'.tr(),
                                  prefixIcon: Icon(Icons.public, color: Color(colorPrimary)),
                                  filled: true,
                                  fillColor: isDark ? Colors.grey[900] : Colors.white,
                                  hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Color(colorPrimary), width: 2),
                                  ),
                                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                                ),
                                readOnly: true,
                              ),
                            ),
                          ),
                          const Divider(height: 24),
                          _buildTextField(
                            context,
                            label: 'First Name'.tr(),
                            initialValue: user.firstName,
                            onSaved: (val) => firstName = val,
                            validator: validateName,
                            icon: Icons.person_outline,
                          ),
                          const Divider(height: 24),
                          _buildTextField(
                            context,
                            label: 'Last Name'.tr(),
                            initialValue: user.lastName,
                            onSaved: (val) => lastName = val,
                            validator: validateName,
                            icon: Icons.person_outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('PRIVATE DETAILS'.tr(), style: titleStyle),
                  const SizedBox(height: 12),
                  Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildTextField(
                            context,
                            label: 'Email Address'.tr(),
                            initialValue: user.email,
                            onSaved: (val) => email = val,
                            validator: validateEmail,
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const Divider(height: 24),
                          _buildTextField(
                            context,
                            label: 'Phone Number'.tr(),
                            controller: _phoneController,
                            initialValue: '',
                            onSaved: (val) => mobile = val?.trim(),
                            validator: _validateAccountPhoneInput,
                            icon: Icons.phone_outlined,
                            helperText: _phoneFieldGuidance(),
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
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
                      onPressed: () => context
                          .read<AccountDetailsBloc>()
                          .add(ValidateFieldsEvent(_key)),
                      child: Text(
                        'Save Changes'.tr(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {required IconData icon, Color? valueColor}) {
    final isDark = isDarkMode(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black54),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isDark ? Colors.white : Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required String label,
    required String initialValue,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
    required IconData icon,
    TextEditingController? controller,
    String? helperText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = isDarkMode(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              TextFormField(
                controller: controller,
                initialValue: controller == null ? initialValue : null,
                onSaved: onSaved,
                validator: validator,
                keyboardType: keyboardType,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                ),
              ),
              if (helperText != null && helperText.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  helperText,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
