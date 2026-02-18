import 'package:bloc/bloc.dart';
import 'package:caribtap/listings/model/filter_model.dart';
import 'package:caribtap/listings/listings_module/api/listings_repository.dart';

part 'filters_event.dart';

part 'filters_state.dart';

class FiltersBloc extends Bloc<FiltersEvent, FiltersState> {
  final ListingsRepository listingsRepository;

  FiltersBloc({required this.listingsRepository}) : super(FiltersInitial()) {
    on<GetFiltersEvent>((event, emit) async {
      List<FilterModel> filters = await listingsRepository.getFilters();
      emit(FiltersReadyState(filters: filters));
    });
  }
}
