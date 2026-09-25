import 'dart:async';
import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:example/src/weather/walk_suggestions.dart';
import 'package:example/src/weather/weather_bloc.dart';
import 'package:example/src/weather/weather_models.dart';
import 'package:example/src/weather/weather_repository.dart';
import 'package:example/src/weather/weather_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

WeatherReport report(City city, {int rain = 10}) => WeatherReport(
      city: city,
      cityNow: DateTime(2026, 9, 23, 8),
      hours: [
        HourForecast(
            time: DateTime(2026, 9, 23, 10),
            temperature: 22,
            rainChance: rain,
            windSpeed: 8),
        HourForecast(
            time: DateTime(2026, 9, 23, 11),
            temperature: 20,
            rainChance: 5,
            windSpeed: 10),
        HourForecast(
            time: DateTime(2026, 9, 23, 20),
            temperature: 22,
            rainChance: 0,
            windSpeed: 4),
        HourForecast(
            time: DateTime(2026, 9, 24, 9),
            temperature: 22,
            rainChance: 1,
            windSpeed: null),
      ],
      days: const [],
    );

class FakeRepository extends WeatherRepository {
  FakeRepository() : super(http.Client());
  final forecasts = <String, Completer<WeatherReport>>{};
  final searches = <String, Completer<List<City>>>{};
  @override
  Future<WeatherReport> getForecast(City city) =>
      (forecasts[city.name] ??= Completer<WeatherReport>()).future;
  @override
  Future<List<City>> searchCities(String query) =>
      (searches[query] ??= Completer<List<City>>()).future;
}

void main() {
  test('walking ranking uses local daytime and rejects missing measurements',
      () {
    final chosen = bestWalkingHours(report(saoPaulo));
    expect(chosen.map((h) => h.time.hour), [11, 10]);
    expect(bestWalkingHours(report(saoPaulo, rain: 60)).length, 1);
  });

  test('repository parses forecast, geocoding and HTTP errors', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/search') {
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'results': [
                {
                  'name': 'São Paulo',
                  'country': 'Brasil',
                  'latitude': -23.55,
                  'longitude': -46.63,
                  'timezone': 'America/Sao_Paulo'
                }
              ]
            })),
            200);
      }
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'utc_offset_seconds': -10800,
            'current': {
              'time': '2026-09-23T08:00',
              'temperature_2m': 22,
              'precipitation_probability': 10,
              'wind_speed_10m': 8,
              'weather_code': 1
            },
            'hourly': {
              'time': ['2026-09-23T09:00'],
              'temperature_2m': [23],
              'precipitation_probability': [12],
              'wind_speed_10m': [9],
              'weather_code': [1]
            },
            'daily': {
              'time': ['2026-09-23'],
              'temperature_2m_min': [18],
              'temperature_2m_max': [25],
              'precipitation_probability_max': [40],
              'weather_code': [2]
            },
          })),
          200);
    });
    final repository = WeatherRepository(client);
    final cities = await repository.searchCities('São');
    expect(cities.single.name, 'São Paulo');
    final forecast = await repository.getForecast(cities.single);
    expect(forecast.cityNow.hour, 8);
    expect(forecast.hours.single.rainChance, 12);
    expect(forecast.days.single.maximum, 25);
    client.close();
    final failing =
        WeatherRepository(MockClient((_) async => http.Response('{}', 503)));
    expect(failing.getForecast(saoPaulo), throwsA(isA<WeatherException>()));
  });

  blocTest<ForecastBloc, ForecastState>(
    'switching cities discards the old response and never shows old report',
    build: () {
      final repo = FakeRepository();
      repo.forecasts['São Paulo'] = Completer<WeatherReport>();
      repo.forecasts['Rio'] = Completer<WeatherReport>();
      return ForecastBloc(repo);
    },
    act: (bloc) async {
      const rio = City(
          name: 'Rio',
          country: 'Brasil',
          latitude: -22.9,
          longitude: -43.2,
          timezone: 'America/Sao_Paulo');
      final repo = bloc.repository as FakeRepository;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      bloc.add(const ForecastCitySelected(rio));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      repo.forecasts['São Paulo']!.complete(report(saoPaulo));
      repo.forecasts['Rio']!.complete(report(rio));
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(bloc.state.city.name, 'Rio');
      expect(bloc.state.report?.city.name, 'Rio');
    },
  );

  test('search ignores stale responses after query changes', () async {
    final repo = FakeRepository();
    final bloc = CitySearchBloc(repo);
    bloc.add(const CityQueryChanged('Sao'));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    bloc.add(const CityQueryChanged('Rio'));
    repo.searches['Sao']!.complete([saoPaulo]);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    repo.searches['Rio']!.complete([]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(bloc.state.query, 'Rio');
    expect(bloc.state.status, CitySearchStatus.empty);
    await bloc.close();
  });

  testWidgets('weather screen changes city at mobile width with large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final repo = FakeRepository();
    final search = CitySearchBloc(repo);
    final forecast = ForecastBloc(repo);
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<CitySearchBloc>.value(value: search),
        BlocProvider<ForecastBloc>.value(value: forecast),
      ],
      child: const MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: WeatherPage(),
      )),
    ));
    repo.forecasts['São Paulo']!.complete(report(saoPaulo));
    await tester.pump();
    await tester.pump();
    expect(find.text('Melhor horário para caminhar'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Rio');
    await tester.pump(const Duration(milliseconds: 400));
    const rio = City(
        name: 'Rio',
        country: 'Brasil',
        latitude: -22.9,
        longitude: -43.2,
        timezone: 'America/Sao_Paulo');
    repo.searches['Rio']!.complete([rio]);
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Rio'));
    await tester.tap(find.widgetWithText(ListTile, 'Rio'));
    await tester.pump();
    expect(find.textContaining('São Paulo, São Paulo'), findsNothing);
    repo.forecasts['Rio']!.complete(report(rio));
    await tester.pump();
    await tester.pump();
    expect(find.text('Rio, Brasil'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await forecast.close();
      await search.close();
    });
    await tester.binding.setSurfaceSize(null);
  });
}
