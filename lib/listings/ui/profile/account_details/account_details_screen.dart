import 'package:instaflutter/listings/utils/caribbean_countries.dart';
import 'package:instaflutter/listings/utils/country_search_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:instaflutter/listings/ui/auth/reauth_user/reauth_user_bloc.dart';
import 'package:instaflutter/listings/ui/auth/reauth_user/reauth_user_screen.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:instaflutter/listings/ui/profile/account_details/account_details_bloc.dart';
import 'package:instaflutter/listings/ui/profile/api/profile_api_manager.dart';

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
  AutovalidateMode _validate = AutovalidateMode.disabled;
  String? firstName, email, mobile, lastName;
  String? _countryCode;
  String? validateCountry(String? code) {
    if (code == null || code.trim().isEmpty) {
      return 'Country is required';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    user = widget.user;
    _countryCode = user.countryCode.isEmpty ? null : user.countryCode;
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
        listener: (context, state) async {
          if (state is AccountFieldsRequiredState) {
            showSnackBar(context, 'Some fields are required.'.tr());
            _validate = AutovalidateMode.onUserInteraction;
          } else if (state is ValidFieldsState) {
            context.read<AccountDetailsBloc>().add(TryToSubmitDataEvent(
                  firstName: firstName!,
                  lastName: lastName!,
                  emailAddress: email!,
                  phoneNumber: mobile!,
                  countryCode: _countryCode ?? '',
                ));
          } else if (state is ReauthRequiredState) {
            bool result = await showDialog(
              context: context,
              builder: (context) => ReAuthUserScreen(
                provider: state.authProvider,
                phoneNumber: state.authProvider == AuthProviders.phone
                    ? state.data
                    : null,
                newEmail: state.authProvider == AuthProviders.password
                    ? state.data
                    : null,
                currentEmail: state.authProvider == AuthProviders.password
                    ? context.read<AuthenticationBloc>().user!.email
                    : null,
                isDeleteUser: false,
              ),
            );

            if (result == true) {
              if (!mounted) return;
              context.read<LoadingCubit>().showLoading(
                    context,
                    'Saving details...'.tr(),
                    false,
                    Color(colorPrimary),
                  );
              context.read<AccountDetailsBloc>().add(UpdateUserDataEvent(
                    firstName: firstName!,
                    lastName: lastName!,
                    emailAddress: email!,
                    phoneNumber: mobile!,
                    countryCode: _countryCode ?? '',
                  ));
            }
          } else if (state is UpdatingDataState) {
            context.read<LoadingCubit>().showLoading(
                  context,
                  'Saving details...'.tr(),
                  false,
                  Color(colorPrimary),
                );
          } else if (state is UserDataUpdatedState) {
            context.read<LoadingCubit>().hideLoading();
            user = state.updatedUser;
            context.read<AuthenticationBloc>().user = state.updatedUser;
            showSnackBar(context, 'Details saved successfully'.tr());
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
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
                                controller: TextEditingController(
                                  text: CaribbeanCountries.all.firstWhere(
                                    (c) => c.code == _countryCode,
                                    orElse: () => CaribbeanCountry(code: '', name: ''),
                                  ).name,
                                ),
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
                            initialValue: user.phoneNumber,
                            onSaved: (val) => mobile = val,
                            validator: validateMobile,
                            icon: Icons.phone_outlined,
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
                initialValue: initialValue,
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
            ],
          ),
        ),
      ],
    );
  }
}
