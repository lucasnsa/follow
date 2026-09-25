import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'weather_models.dart';
import 'weather_repository.dart';

sealed class CitySearchEvent {
  const CitySearchEvent();
}

class CityQueryChanged extends CitySearchEvent {
  const CityQueryChanged(this.query);
  final String query;
}

class CitySearchRetried extends CitySearchEvent {
  const CitySearchRetried();
}

class _CitySearchRequested extends CitySearchEvent {
  const _CitySearchRequested(this.query, this.generation);
  final String query;
  final int generation;
}

enum CitySearchStatus { idle, waiting, loading, results, empty, failure }

class CitySearchState {
  const CitySearchState(
      {this.query = '',
      this.status = CitySearchStatus.idle,
      this.cities = const [],
      this.error});
  final String query;
  final CitySearchStatus status;
  final List<City> cities;
  final String? error;
}

class CitySearchBloc extends Bloc<CitySearchEvent, CitySearchState> {
  CitySearchBloc(this.repository) : super(const CitySearchState()) {
    on<CityQueryChanged>(_onQuery);
    on<_CitySearchRequested>(_onSearch);
    on<CitySearchRetried>((_, __) => add(CityQueryChanged(state.query)));
  }
  final WeatherRepository repository;
  Timer? _debounce;
  int _generation = 0;

  void _onQuery(CityQueryChanged event, Emitter<CitySearchState> emit) {
    _debounce?.cancel();
    final generation = ++_generation;
    final query = event.query.trim();
    if (query.length < 3) {
      emit(CitySearchState(query: query));
      return;
    }
    emit(CitySearchState(query: query, status: CitySearchStatus.waiting));
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!isClosed) add(_CitySearchRequested(query, generation));
    });
  }

  Future<void> _onSearch(
      _CitySearchRequested event, Emitter<CitySearchState> emit) async {
    if (event.generation != _generation) return;
    emit(CitySearchState(query: event.query, status: CitySearchStatus.loading));
    try {
      final cities = await repository.searchCities(event.query);
      if (event.generation != _generation || isClosed) return;
      emit(CitySearchState(
          query: event.query,
          cities: cities,
          status: cities.isEmpty
              ? CitySearchStatus.empty
              : CitySearchStatus.results));
    } catch (_) {
      if (event.generation != _generation || isClosed) return;
      emit(CitySearchState(
          query: event.query,
          status: CitySearchStatus.failure,
          error: 'Não foi possível buscar cidades. Tente novamente.'));
    }
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    ++_generation;
    await super.close();
  }
}

sealed class ForecastEvent {
  const ForecastEvent();
}

class ForecastCitySelected extends ForecastEvent {
  const ForecastCitySelected(this.city);
  final City city;
}

class ForecastRefreshed extends ForecastEvent {
  const ForecastRefreshed();
}

enum ForecastStatus { loading, ready, refreshing, failure }

class ForecastState {
  const ForecastState(
      {required this.city,
      this.status = ForecastStatus.loading,
      this.report,
      this.error});
  final City city;
  final ForecastStatus status;
  final WeatherReport? report;
  final String? error;
}

class ForecastBloc extends Bloc<ForecastEvent, ForecastState> {
  ForecastBloc(this.repository) : super(const ForecastState(city: saoPaulo)) {
    on<ForecastCitySelected>((event, emit) => _load(event.city, emit));
    on<ForecastRefreshed>((_, emit) => _load(state.city, emit));
    add(const ForecastCitySelected(saoPaulo));
  }
  final WeatherRepository repository;
  int _generation = 0;

  Future<void> _load(City city, Emitter<ForecastState> emit) async {
    final generation = ++_generation;
    final sameCity = city.name == state.city.name &&
        city.latitude == state.city.latitude &&
        city.longitude == state.city.longitude;
    final previous = sameCity ? state.report : null;
    emit(ForecastState(
        city: city,
        report: previous,
        status: previous == null
            ? ForecastStatus.loading
            : ForecastStatus.refreshing));
    try {
      final report = await repository.getForecast(city);
      if (generation != _generation || isClosed) return;
      emit(ForecastState(
          city: city, report: report, status: ForecastStatus.ready));
    } catch (_) {
      if (generation != _generation || isClosed) return;
      emit(ForecastState(
          city: city,
          report: previous,
          status: ForecastStatus.failure,
          error: 'Não foi possível carregar a previsão. Tente novamente.'));
    }
  }

  @override
  Future<void> close() async {
    ++_generation;
    await super.close();
  }
}
