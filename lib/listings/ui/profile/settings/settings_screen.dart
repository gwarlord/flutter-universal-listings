import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:instaflutter/listings/ui/profile/api/profile_api_manager.dart';
import 'package:instaflutter/listings/ui/profile/settings/settings_bloc.dart';
import 'package:instaflutter/listings/ui/auth/reset_password/reset_password_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  final ListingsUser user;

  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ListingsUser user;
  late bool _allowPushNotifications;

  @override
  void initState() {
    super.initState();
    user = widget.user;
    _allowPushNotifications = user.settings.allowPushNotifications;
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

    return BlocProvider(
      create: (context) => SettingsBloc(profileRepository: profileApiManager),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Settings'.tr()),
              centerTitle: true,
            ),
            body: BlocConsumer<SettingsBloc, SettingsState>(
              listener: (context, state) {
                if (state is SettingsSavedState) {
                  context.read<LoadingCubit>().hideLoading();
                  BlocProvider.of<AuthenticationBloc>(context).user = user;
                  showSnackBar(context, 'Settings saved successfully'.tr());
                }
              },
              builder: (context, state) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NOTIFICATIONS'.tr(), style: titleStyle),
                      const SizedBox(height: 12),
                      Card(
                        color: cardColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildSettingSwitch(
                              context,
                              title: 'Push Notifications'.tr(),
                              subtitle: 'Receive alerts for new listings and messages'.tr(),
                              icon: Icons.notifications_none_outlined,
                              value: _allowPushNotifications,
                              onChanged: (bool newValue) {
                                setState(() => _allowPushNotifications = newValue);
                                context.read<SettingsBloc>().add(SettingsChangedEvent());
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text('ACCOUNT SECURITY'.tr(), style: titleStyle),
                      const SizedBox(height: 12),
                      Card(
                        color: cardColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildSettingTile(
                              context,
                              title: 'Password & Security'.tr(),
                              icon: Icons.lock_outline,
                              onTap: () => push(context, const ResetPasswordScreen()),
                            ),
                            const Divider(height: 1, indent: 50),
                            _buildSettingTile(
                              context,
                              title: 'Privacy Policy'.tr(),
                              icon: Icons.privacy_tip_outlined,
                              onTap: () => _launchPrivacyPolicy(context),
                            ),
                          ],
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
                          onPressed: () {
                            user.settings.allowPushNotifications = _allowPushNotifications;
                            context.read<LoadingCubit>().showLoading(
                                  context,
                                  'Saving changes...'.tr(),
                                  false,
                                  Color(colorPrimary),
                                );
                            context
                                .read<SettingsBloc>()
                                .add(SaveSettingsEvent(currentUser: user));
                          },
                          child: Text(
                            'Save Changes'.tr(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _launchPrivacyPolicy(BuildContext context) async {
    final Uri url = Uri.parse('https://www.caribtap.com/privacy'); // Update with your actual URL
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      showSnackBar(context, 'Could not launch Privacy Policy'.tr());
    }
  }

  Widget _buildSettingSwitch(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = isDarkMode(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SwitchListTile.adaptive(
        activeColor: Color(colorPrimary),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(colorPrimary).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Color(colorPrimary)),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = isDarkMode(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}
