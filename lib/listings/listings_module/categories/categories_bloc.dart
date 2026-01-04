import 'dart:developer' as dev;

import 'package:bloc/bloc.dart';
import 'package:instaflutter/listings/model/categories_model.dart';
import 'package:instaflutter/listings/listings_module/api/listings_repository.dart';

part 'categories_event.dart';
part 'categories_state.dart';

class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  final ListingsRepository listingsRepository;

  CategoriesBloc({required this.listingsRepository})
      : super(CategoriesInitial()) {
    on<FetchCategoriesEvent>((event, emit) async {
      emit(LoadingState());

      dev.log('FetchCategoriesEvent -> calling getCategories()',
          name: 'CategoriesBloc');

      try {
        final categories = await listingsRepository.getCategories();

        dev.log('getCategories() returned ${categories.length} categories',
            name: 'CategoriesBloc');

        emit(CategoriesFetchedState(categoriesList: categories));
      } catch (e, st) {
        dev.log('getCategories() failed: $e',
            name: 'CategoriesBloc', error: e, stackTrace: st);

        // If you have an Error state, emit it here.
        // Otherwise, keep UX stable by returning an empty list.
        emit(CategoriesFetchedState(categoriesList: const []));
      }
    });

    on<LoadingEvent>((event, emit) => emit(LoadingState()));
  }
}
