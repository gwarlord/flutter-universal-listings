import 'package:bloc/bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:instaflutter/core/utils/helper.dart';

part 'loading_state.dart';

class LoadingCubit extends Cubit<LoadingIndicatorState> {
  LoadingCubit() : super(LoadingInitial());

  void showLoading(BuildContext context, String message, bool isDismissible,
      Color colorPrimary) {
    showProgress(context, message, isDismissible, colorPrimary);
  }

  void hideLoading() {
    hideProgress();
  }
}
