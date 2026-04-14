import 'package:easy_localization/easy_localization.dart' as easy_local;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/ui/auth/onBoarding/on_boarding_cubit.dart';
import 'package:caribtap/listings/ui/auth/welcome/welcome_screen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  PageController pageController = PageController();
  List<String> _titlesList = [];
  List<String> _subtitlesList = [];
  List<dynamic> _imageList = [];

  @override
  void initState() {
    super.initState();
    _titlesList = [
      'Welcome to CaribTap'.tr(),
      'Discover the Caribbean'.tr(),
      'Book & Shop'.tr(),
      'Grow Your Business'.tr(),
      'Stay Connected'.tr(),
    ];
    _subtitlesList = [
      'Your Caribbean marketplace — find businesses, services and products from across the region, all in one place.'.tr(),
      'Browse listings by category, location or keyword. Use the interactive map to explore what\'s near you or anywhere in the Caribbean.'.tr(),
      'Book appointments, order products and rent items directly in the app. Manage your bookings and orders with ease.'.tr(),
      'List your business, promote deals, sell products and offer rentals. Reach thousands of Caribbean customers and grow your brand.'.tr(),
      'Chat directly with businesses and customers, get real-time booking updates and stay on top of every transaction with push notifications.'.tr(),
    ];

    _imageList = [
      'assets/images/caribtap_logo.png',
      Icons.travel_explore_rounded,
      Icons.shopping_bag_outlined,
      Icons.storefront_outlined,
      Icons.chat_bubble_outline_rounded,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OnBoardingCubit(),
      child: Scaffold(
        backgroundColor: Color(colorPrimary),
        body: BlocBuilder<OnBoardingCubit, OnBoardingInitial>(
          builder: (context, state) {
            return Stack(
              children: [
                PageView.builder(
                  itemBuilder: (context, index) => getPage(
                      _imageList[index],
                      _titlesList[index],
                      _subtitlesList[index],
                      context,
                      index + 1 == _titlesList.length),
                  controller: pageController,
                  itemCount: _titlesList.length,
                  onPageChanged: (int index) {
                    context.read<OnBoardingCubit>().onPageChanged(index);
                  },
                ),
                Visibility(
                  visible: state.currentPageCount + 1 == _titlesList.length,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      top: 16.0,
                      bottom: 80.0 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: Align(
                      alignment: Directionality.of(context) == TextDirection.ltr
                          ? Alignment.bottomRight
                          : Alignment.bottomLeft,
                      child:
                          BlocListener<AuthenticationBloc, AuthenticationState>(
                        listener: (context, state) {
                          if (state.authState == AuthState.unauthenticated) {
                            pushAndRemoveUntil(
                                context, const WelcomeScreen(), false);
                          }
                        },
                        child: OutlinedButton(
                          onPressed: () {
                            context
                                .read<AuthenticationBloc>()
                                .add(FinishedOnBoardingEvent());
                          },
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white),
                              shape: const StadiumBorder()),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                                fontSize: 14.0,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ).tr(),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 50.0),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SmoothPageIndicator(
                      controller: pageController,
                      count: _titlesList.length,
                      effect: ScrollingDotsEffect(
                          activeDotColor: Colors.white,
                          dotColor: Colors.grey.shade400,
                          dotWidth: 8,
                          dotHeight: 8,
                          fixedCenter: true),
                    ),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  Widget getPage(dynamic image, String title, String subTitle,
      BuildContext context, bool isLastPage) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            image is String
                ? Image.asset(
                    image,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    image as IconData,
                    color: Colors.white,
                    size: 150,
                  ),
            const SizedBox(height: 40),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              subTitle,
              style: const TextStyle(color: Colors.white, fontSize: 14.0),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
