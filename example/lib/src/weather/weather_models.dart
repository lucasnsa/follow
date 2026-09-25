class City {
  const City(
      {required this.name,
      required this.country,
      required this.latitude,
      required this.longitude,
      required this.timezone,
      this.region});

  final String name, country, timezone;
  final String? region;
  final double latitude, longitude;

  String get label => [
        name,
        if (region != null && region!.isNotEmpty) region!,
        country
      ].join(', ');

  factory City.fromJson(Map<String, dynamic> json) => City(
        name: json['name'] as String,
        country: json['country'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timezone: json['timezone'] as String? ?? 'auto',
        region: json['admin1'] as String?,
      );
}

class HourForecast {
  const HourForecast(
      {required this.time,
      this.temperature,
      this.rainChance,
      this.windSpeed,
      this.weatherCode});

  final DateTime time;
  final double? temperature, windSpeed;
  final int? rainChance, weatherCode;
}

class DayForecast {
  const DayForecast(
      {required this.date,
      this.minimum,
      this.maximum,
      this.rainChance,
      this.weatherCode});

  final DateTime date;
  final double? minimum, maximum;
  final int? rainChance, weatherCode;
}

class WeatherReport {
  const WeatherReport(
      {required this.city,
      required this.cityNow,
      required this.hours,
      required this.days,
      this.temperature,
      this.rainChance,
      this.windSpeed,
      this.weatherCode});

  final City city;

  /// Wall-clock time in [city]'s time zone, as returned by Open-Meteo.
  final DateTime cityNow;
  final List<HourForecast> hours;
  final List<DayForecast> days;
  final double? temperature, windSpeed;
  final int? rainChance, weatherCode;

  factory WeatherReport.fromJson(City city, Map<String, dynamic> json) {
    final current = _object(json['current']);
    final hourly = _object(json['hourly']);
    final daily = _object(json['daily']);
    final times = _list(hourly['time']);
    final dates = _list(daily['time']);
    final offset = (json['utc_offset_seconds'] as num?)?.toInt() ?? 0;
    final currentTime = current['time'] as String?;
    return WeatherReport(
      city: city,
      cityNow: currentTime == null
          ? DateTime.now().toUtc().add(Duration(seconds: offset))
          : _cityTime(currentTime),
      temperature: _double(current['temperature_2m']),
      rainChance: _int(current['precipitation_probability']),
      windSpeed: _double(current['wind_speed_10m']),
      weatherCode: _int(current['weather_code']),
      hours: List.generate(
          times.length,
          (i) => HourForecast(
                time: _cityTime(times[i] as String),
                temperature: _double(_at(hourly['temperature_2m'], i)),
                rainChance: _int(_at(hourly['precipitation_probability'], i)),
                windSpeed: _double(_at(hourly['wind_speed_10m'], i)),
                weatherCode: _int(_at(hourly['weather_code'], i)),
              )),
      days: List.generate(
          dates.length,
          (i) => DayForecast(
                date: _cityTime(dates[i] as String),
                minimum: _double(_at(daily['temperature_2m_min'], i)),
                maximum: _double(_at(daily['temperature_2m_max'], i)),
                rainChance:
                    _int(_at(daily['precipitation_probability_max'], i)),
                weatherCode: _int(_at(daily['weather_code'], i)),
              )),
    );
  }
}

Map<String, dynamic> _object(Object? value) =>
    value is Map<String, dynamic> ? value : const {};
List<dynamic> _list(Object? value) => value is List ? value : const [];
Object? _at(Object? values, int index) {
  final list = _list(values);
  return index < list.length ? list[index] : null;
}

double? _double(Object? value) => value is num ? value.toDouble() : null;
int? _int(Object? value) => value is num ? value.toInt() : null;

const saoPaulo = City(
    name: 'São Paulo',
    country: 'Brasil',
    region: 'São Paulo',
    latitude: -23.5505,
    longitude: -46.6333,
    timezone: 'America/Sao_Paulo');

// Open-Meteo returns local wall time without an offset. UTC components keep
// the city hour independent of the device time zone.
DateTime _cityTime(String value) =>
    DateTime.parse(value.contains('T') ? '${value}Z' : '${value}T00:00Z');
