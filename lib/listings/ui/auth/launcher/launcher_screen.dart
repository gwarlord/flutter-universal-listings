import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/ui/auth/onBoarding/on_boarding_screen.dart';
import 'package:caribtap/listings/ui/auth/welcome/welcome_screen.dart';
import 'package:caribtap/listings/ui/container/container_screen.dart';
import 'package:caribtap/listings/location/location_scope_cubit.dart';

class LauncherScreen extends StatefulWidget {
  const LauncherScreen({super.key});

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> {
  bool _nativeSplashRemoved = false;

  void _removeNativeSplashIfNeeded() {
    if (_nativeSplashRemoved) {
      return;
    }
    _nativeSplashRemoved = true;
    FlutterNativeSplash.remove();
  }

  void _completeLaunch(Widget destination) {
    pushReplacement(context, destination);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _removeNativeSplashIfNeeded();
    });
    context.read<AuthenticationBloc>().add(CheckFirstRunEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        switch (state.authState) {
          case AuthState.firstRun:
            _completeLaunch(const OnBoardingScreen());
            break;
          case AuthState.authenticated:
            final locationCubit = context.read<LocationScopeCubit>();
            locationCubit.setUserId(state.user!.userID);
            locationCubit.init();

            _completeLaunch(
              ContainerWrapperWidget(currentUser: state.user!),
            );
            break;
          case AuthState.unauthenticated:
            _completeLaunch(const WelcomeScreen());
            break;
        }
      },
      child: Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Image.asset(
            'assets/images/caribtap_c_logo.png',
            width: 250.0,
            height: 250.0,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
