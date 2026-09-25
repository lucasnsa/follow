import 'weather_models.dart';

List<HourForecast> bestWalkingHours(WeatherReport report) {
  final end = report.cityNow.add(const Duration(hours: 24));
  final candidates = report.hours.where((hour) {
    final temperature = hour.temperature;
    final rain = hour.rainChance;
    final wind = hour.windSpeed;
    return !hour.time.isBefore(report.cityNow) &&
        hour.time.isBefore(end) &&
        hour.time.hour >= 7 &&
        hour.time.hour < 19 &&
        temperature != null &&
        temperature >= 16 &&
        temperature <= 28 &&
        rain != null &&
        rain < 30 &&
        wind != null &&
        wind < 20;
  }).toList();
  candidates.sort((a, b) {
    final rain = a.rainChance!.compareTo(b.rainChance!);
    if (rain != 0) return rain;
    final temp =
        (a.temperature! - 22).abs().compareTo((b.temperature! - 22).abs());
    if (temp != 0) return temp;
    final wind = a.windSpeed!.compareTo(b.windSpeed!);
    return wind != 0 ? wind : a.time.compareTo(b.time);
  });
  return candidates.take(3).toList();
}
