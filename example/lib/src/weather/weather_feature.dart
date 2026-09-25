import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow/follow.dart';
import 'package:http/http.dart' as http;

import '../navigation.dart';
import 'weather_bloc.dart';
import 'weather_page.dart';
import 'weather_repository.dart';

final weatherFeature = Feature(
  name: 'weather',
  bindings: [
    Bind.singleton(Token<http.Client>(), (_) => http.Client(),
        dispose: (client) => client.close()),
    Bind.singleton(Token<WeatherRepository>(),
        (read) => WeatherRepository(read<http.Client>())),
    Bind.singleton(Token<CitySearchBloc>(),
        (read) => CitySearchBloc(read<WeatherRepository>()),
        dispose: (bloc) => bloc.close()),
    Bind.singleton(Token<ForecastBloc>(),
        (read) => ForecastBloc(read<WeatherRepository>()),
        dispose: (bloc) => bloc.close()),
  ],
  routes: [
    FeatureRoute.page(weatherRoute, builder: (_, __) => const WeatherPage())
  ],
  shell: (context, outlet) => MultiBlocProvider(
    providers: [
      BlocProvider<CitySearchBloc>.value(
          value: context.follow.read<CitySearchBloc>()),
      BlocProvider<ForecastBloc>.value(
          value: context.follow.read<ForecastBloc>()),
    ],
    child: outlet,
  ),
);
