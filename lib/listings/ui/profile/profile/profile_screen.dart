import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:instaflutter/listings/ui/auth/reauth_user/reauth_user_screen.dart';
import 'package:instaflutter/listings/ui/auth/welcome/welcome_screen.dart';
import 'package:instaflutter/listings/listings_module/admin_dashboard/admin_dashboard_screen.dart';
import 'package:instaflutter/listings/listings_module/admin_dashboard/edit_user_subscription_screen.dart';
import 'package:instaflutter/listings/listings_module/favorite_listings/favorite_listings_screen.dart';
import 'package:instaflutter/listings/listings_module/my_listings/my_listings_screen.dart';
import 'package:instaflutter/listings/listings_module/home/home_screen.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:instaflutter/listings/ui/profile/account_details/account_details_screen.dart';
import 'package:instaflutter/listings/ui/profile/api/profile_api_manager.dart';
import 'package:instaflutter/listings/ui/profile/contact_us/contact_us_screen.dart';
import 'package:instaflutter/listings/ui/profile/settings/settings_screen.dart';
import 'package:instaflutter/listings/ui/profile/profile/profile_bloc.dart';
import 'package:instaflutter/core/ui/theme/theme_cubit.dart';

class ProfileScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const ProfileScreen({super.key, required this.currentUser});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late ListingsUser currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (Platform.isAndroid) {
          pushAndRemoveUntil(
            context,
            HomeScreen(currentUser: currentUser),
            false,
          );
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: Platform.isIOS
            ? AppBar(
                title: Text('Profile'.tr()),
              )
            : null,
        body: BlocProvider(
        create: (context) => ProfileBloc(
          currentUser: currentUser,
          profileRepository: profileApiManager,
        ),
        child: Builder(
          builder: (context) {
            return MultiBlocListener(
              listeners: [
                BlocListener<AuthenticationBloc, AuthenticationState>(
                  listener: (context, state) {
                    context.read<LoadingCubit>().hideLoading();
                    if (state.authState == AuthState.unauthenticated) {
                      pushAndRemoveUntil(context, const WelcomeScreen(), false);
                    }
                  },
                ),
                BlocListener<ProfileBloc, ProfileState>(
                  listener: (context, state) async {
                    if (state is UpdatedUserState) {
                      context.read<LoadingCubit>().hideLoading();
                      context.read<AuthenticationBloc>().user =
                          state.updatedUser;
                      currentUser = state.updatedUser;
                    } else if (state is UploadingImageState) {
                      context.read<LoadingCubit>().showLoading(
                            context,
                            'Uploading image...'.tr(),
                            false,
                            Color(colorPrimary),
                          );
                    } else if (state is ReauthRequiredState) {
                      bool? result = await showDialog(
                        context: context,
                        builder: (context) => ReAuthUserScreen(
                          provider: state.authProvider,
                          currentEmail:
                              auth.FirebaseAuth.instance.currentUser!.email,
                          phoneNumber: auth
                              .FirebaseAuth.instance.currentUser!.phoneNumber,
                          isDeleteUser: true,
                        ),
                      );
                      if (result != null && result) {
                        if (!context.mounted) return;
                        context
                            .read<AuthenticationBloc>()
                            .add(UserDeletedEvent());
                      }
                    } else if (state is DeleteUserConfirmationState) {
                      bool? result;
                      String title = 'Account Deletion'.tr();
                      String content =
                          'Are you sure you want to delete your account? This can not be undone.'
                              .tr();
                      if (Platform.isIOS) {
                        await showCupertinoDialog(
                            context: context,
                            builder: (context) => CupertinoAlertDialog(
                                  title: Text(title),
                                  content: Text(content),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        result = true;
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Yes').tr(),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        result = false;
                                        Navigator.pop(context);
                                      },
                                      child: const Text('No').tr(),
                                    ),
                                  ],
                                ));
                      } else {
                        await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(title),
                            content: Text(content),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  result = true;
                                  Navigator.pop(context);
                                },
                                child: const Text('Yes').tr(),
                              ),
                              TextButton(
                                onPressed: () {
                                  result = false;
                                  Navigator.pop(context);
                                },
                                child: const Text('No').tr(),
                              ),
                            ],
                          ),
                        );
                      }
                      if (result != null && result!) {
                        if (!context.mounted) return;
                        context.read<LoadingCubit>().showLoading(
                              context,
                              'Deleting account...'.tr(),
                              false,
                              Color(colorPrimary),
                            );
                        context
                            .read<ProfileBloc>()
                            .add(DeleteUserConfirmedEvent());
                      }
                    } else if (state is UserDeletedState) {
                      context.read<LoadingCubit>().hideLoading();
                      context
                          .read<AuthenticationBloc>()
                          .add(UserDeletedEvent());
                    }
                  },
                ),
              ],
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 32.0, left: 32, right: 32),
                      child: Column(
                        children: [
                          BlocBuilder<ProfileBloc, ProfileState>(
                              buildWhen: (old, current) =>
                                  current is UpdatedUserState && old != current,
                              builder: (context, state) {
                                return Center(
                                    child: displayCircleImage(
                                        currentUser.profilePictureURL,
                                        130,
                                        false));
                              }),
                          SizedBox(
                            width: 175,
                            child: FloatingActionButton(
                                backgroundColor: Color(colorAccent),
                                mini: true,
                                onPressed: () => _onCameraClick(context),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: isDarkMode(context)
                                      ? Colors.black
                                      : Colors.white,
                                )),
                          )
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 16.0, right: 32, left: 32),
                      child: BlocBuilder<ProfileBloc, ProfileState>(
                          buildWhen: (old, current) =>
                              current is UpdatedUserState && old != current,
                          builder: (context, state) {
                            return Text(
                              currentUser.fullName(),
                              style: TextStyle(
                                  color: isDarkMode(context)
                                      ? Colors.white
                                      : Colors.black,
                                  fontSize: 20),
                              textAlign: TextAlign.center,
                            );
                          }),
                    ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          currentUser.isAdmin
                              ? 'Plan: ADMIN'
                              : 'Plan: ${currentUser.subscriptionTier.toUpperCase()}',
                          style: TextStyle(
                            color: currentUser.isAdmin
                                ? Colors.green.shade600
                                : (isDarkMode(context) ? Colors.grey.shade400 : Colors.grey.shade700),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: [
                          ListTile(
                            dense: true,
                            onTap: () => push(
                                context,
                                MyListingsWrapperWidget(
                                    currentUser: currentUser)),
                            title: Text(
                              'My Listings'.tr(),
                              style: const TextStyle(fontSize: 16),
                            ),
                            leading: Image.asset(
                              'assets/images/listings_welcome_image.png',
                              height: 24,
                              width: 24,
                              color: Color(colorPrimary),
                            ),
                          ),
                          ListTile(
                            dense: true,
                            onTap: () => push(
                                context,
                                FavoriteListingsWrapperWidget(
                                  currentUser: currentUser,
                                )),
                            title: Text(
                              'My Favorites'.tr(),
                              style: const TextStyle(fontSize: 16),
                            ),
                            leading: const Icon(
                              Icons.favorite,
                              color: Colors.red,
                            ),
                          ),
                          ListTile(
                            onTap: () async {
                              await push(
                                  context,
                                  AccountDetailsWrapperWidget(
                                      user: currentUser));
                              if (!context.mounted) return;
                              currentUser =
                                  context.read<AuthenticationBloc>().user!;
                              context.read<ProfileBloc>().add(
                                  InvalidateUserObjectEvent(
                                      newUser: currentUser));
                            },
                            title: const Text(
                              'Account Details',
                              style: TextStyle(fontSize: 16),
                            ).tr(),
                            leading: Icon(
                              Icons.person,
                              color: Color(colorPrimary),
                            ),
                          ),
                          ListTile(
                            onTap: () => push(
                                context, SettingsScreen(user: currentUser)),
                            title: const Text(
                              'Settings',
                              style: TextStyle(fontSize: 16),
                            ).tr(),
                            leading: Icon(
                              Icons.settings,
                              color: isDarkMode(context)
                                  ? Colors.white54
                                  : Colors.black45,
                            ),
                          ),
                          ListTile(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => BlocBuilder<ThemeCubit, ThemeState>(
                                  builder: (context, themeState) {
                                    return AlertDialog(
                                      title: Text('Theme'.tr()),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          RadioListTile<ThemeMode>(
                                            title: Text(
                                              'Light'.tr(),
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 14,
                                              ),
                                            ),
                                            value: ThemeMode.light,
                                            groupValue: themeState.themeMode,
                                            onChanged: (ThemeMode? value) {
                                              if (value != null) {
                                                context.read<ThemeCubit>().setThemeMode(value);
                                                Navigator.pop(context);
                                              }
                                            },
                                          ),
                                          RadioListTile<ThemeMode>(
                                            title: Text(
                                              'Dark'.tr(),
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 14,
                                              ),
                                            ),
                                            value: ThemeMode.dark,
                                            groupValue: themeState.themeMode,
                                            onChanged: (ThemeMode? value) {
                                              if (value != null) {
                                                context.read<ThemeCubit>().setThemeMode(value);
                                                Navigator.pop(context);
                                              }
                                            },
                                          ),
                                          RadioListTile<ThemeMode>(
                                            title: Text(
                                              'System Default'.tr(),
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 14,
                                              ),
                                            ),
                                            value: ThemeMode.system,
                                            groupValue: themeState.themeMode,
                                            onChanged: (ThemeMode? value) {
                                              if (value != null) {
                                                context.read<ThemeCubit>().setThemeMode(value);
                                                Navigator.pop(context);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('Close'.tr()),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            },
                            title: const Text(
                              'Theme',
                              style: TextStyle(fontSize: 16),
                            ).tr(),
                            leading: Icon(
                              isDarkMode(context) ? Icons.dark_mode : Icons.light_mode,
                              color: isDarkMode(context)
                                  ? Colors.yellow.shade600
                                  : Colors.orange,
                            ),
                          ),
                          ListTile(
                            onTap: () => push(context, const ContactUsScreen()),
                            title: const Text(
                              'Contact Us',
                              style: TextStyle(fontSize: 16),
                            ).tr(),
                            leading: const Icon(
                              Icons.call,
                              color: Colors.green,
                            ),
                          ),
                          ListTile(
                            dense: true,
                            onTap: () => context
                                .read<ProfileBloc>()
                                .add(TryToDeleteUserEvent()),
                            title: Text(
                              'Delete Account'.tr(),
                              style: const TextStyle(fontSize: 16),
                            ),
                            leading: const Icon(
                              CupertinoIcons.delete,
                              color: Colors.red,
                            ),
                          ),
                          if (currentUser.isAdmin)
                            ListTile(
                              dense: true,
                              onTap: () => push(
                                  context,
                                  AdminDashboardWrappingWidget(
                                      currentUser: currentUser)),
                              title: Text(
                                'Admin Dashboard'.tr(),
                                style: const TextStyle(fontSize: 16),
                              ),
                              leading: const Icon(
                                Icons.dashboard,
                                color: Colors.blueGrey,
                              ),
                            ),
                          if (currentUser.isAdmin)
                            ListTile(
                              dense: true,
                              onTap: () => push(
                                  context,
                                  EditUserSubscriptionScreen(
                                      currentUser: currentUser)),
                              title: const Text(
                                'Edit User Subscription',
                                style: TextStyle(fontSize: 16),
                              ),
                              leading: const Icon(
                                Icons.manage_accounts,
                                color: Colors.indigo,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(minWidth: double.infinity),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            padding: const EdgeInsets.only(top: 12, bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              side: BorderSide(
                                  color: isDarkMode(context)
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade200),
                            ),
                          ),
                          child: Text(
                            'Logout',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode(context)
                                    ? Colors.white
                                    : Colors.black),
                          ).tr(),
                          onPressed: () {
                            context.read<LoadingCubit>().showLoading(
                                  context,
                                  'Logging out...'.tr(),
                                  false,
                                  Color(colorPrimary),
                                );
                            context
                                .read<AuthenticationBloc>()
                                .add(LogoutEvent(currentUser));
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
    );
  }

  _onCameraClick(BuildContext context) => showCupertinoModalPopup(
        context: context,
        builder: (actionSheetContext) => CupertinoActionSheet(
          message: const Text(
            'Manage Profile Picture',
            style: TextStyle(fontSize: 15.0),
          ).tr(),
          actions: [
            if (currentUser.profilePictureURL.isNotEmpty)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(actionSheetContext);
                  context.read<LoadingCubit>().showLoading(
                        context,
                        'Removing picture...'.tr(),
                        false,
                        Color(colorPrimary),
                      );
                  context.read<ProfileBloc>().add(DeleteUserImageEvent());
                },
                child: const Text('Remove picture').tr(),
              ),
            CupertinoActionSheetAction(
              child: const Text('Choose from gallery').tr(),
              onPressed: () {
                Navigator.pop(actionSheetContext);
                context.read<ProfileBloc>().add(ChooseImageFromGalleryEvent());
              },
            ),
            CupertinoActionSheetAction(
              child: const Text('Take a picture').tr(),
              onPressed: () {
                Navigator.pop(actionSheetContext);
                context.read<ProfileBloc>().add(CaptureImageByCameraEvent());
              },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: const Text('Cancel').tr(),
            onPressed: () => Navigator.pop(actionSheetContext),
          ),
        ),
      );
}
