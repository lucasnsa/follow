import 'dart:convert';

import 'package:http/http.dart' as http;

import 'weather_models.dart';

class WeatherRepository {
  const WeatherRepository(this.client);

  final http.Client client;

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await client.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw WeatherException('Serviço indisponível (${response.statusCode}).');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> || decoded['error'] == true) {
      throw const WeatherException('Resposta inválida do serviço.');
    }
    return decoded;
  }

  Future<List<City>> searchCities(String query) async {
    final json =
        await _get(Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': query,
      'count': '6',
      'language': 'pt',
    }));
    return ((json['results'] as List<dynamic>?) ?? const [])
        .map((value) => City.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  Future<WeatherReport> getForecast(City city) async {
    final json = await _get(Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${city.latitude}',
      'longitude': '${city.longitude}',
      'timezone': city.timezone,
      'forecast_days': '7',
      'current':
          'temperature_2m,precipitation_probability,wind_speed_10m,weather_code',
      'hourly':
          'temperature_2m,precipitation_probability,wind_speed_10m,weather_code',
      'daily':
          'temperature_2m_min,temperature_2m_max,precipitation_probability_max,weather_code',
    }));
    return WeatherReport.fromJson(city, json);
  }
}

class WeatherException implements Exception {
  const WeatherException(this.message);
  final String message;
  @override
  String toString() => message;
}
