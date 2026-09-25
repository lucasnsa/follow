import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow/follow.dart';

import '../navigation.dart';
import 'walk_suggestions.dart';
import 'weather_bloc.dart';
import 'weather_models.dart';

const _ink = Color(0xFF183B32);
const _green = Color(0xFF157C65);
const _muted = Color(0xFF5E746B);

class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F8F6),
        body: SafeArea(
            child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 64),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Clima & Planos',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: _ink,
                                      letterSpacing: -1)),
                          OutlinedButton.icon(
                            onPressed: () =>
                                context.follow.go(homeRoute.location),
                            icon: const Icon(Icons.swap_horiz_rounded),
                            label: const Text('Trocar exemplo'),
                          ),
                        ]),
                    const SizedBox(height: 8),
                    const Text('Um olhar mais inteligente para o seu dia.',
                        style: TextStyle(color: _muted, fontSize: 17)),
                    const SizedBox(height: 28),
                    const _CitySearch(),
                    const SizedBox(height: 26),
                    BlocBuilder<ForecastBloc, ForecastState>(
                        builder: (context, state) {
                      final report = state.report;
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (state.status == ForecastStatus.refreshing)
                              const LinearProgressIndicator(minHeight: 3),
                            if (state.status == ForecastStatus.failure)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: _Notice(state.error!,
                                      onRetry: () => context
                                          .read<ForecastBloc>()
                                          .add(const ForecastRefreshed()))),
                            if (report == null &&
                                state.status == ForecastStatus.loading)
                              const _LoadingCard()
                            else if (report != null) ...[
                              _CurrentWeather(report: report),
                              const SizedBox(height: 26),
                              _WalkCard(report: report),
                              const SizedBox(height: 30),
                              _SectionTitle('Próximas 24 horas',
                                  trailing: TextButton.icon(
                                      onPressed: () => context
                                          .read<ForecastBloc>()
                                          .add(const ForecastRefreshed()),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Atualizar'))),
                              const SizedBox(height: 12),
                              _HourlyList(report: report),
                              const SizedBox(height: 30),
                              const _SectionTitle('Próximos 7 dias'),
                              const SizedBox(height: 12),
                              _DailyList(report: report),
                              const SizedBox(height: 24),
                              const Text(
                                  'Dados meteorológicos e geográficos: Open-Meteo.com',
                                  style:
                                      TextStyle(color: _muted, fontSize: 12)),
                            ],
                          ]);
                    }),
                  ]),
            ),
          ))),
        ])),
      );
}

class _CitySearch extends StatefulWidget {
  const _CitySearch();
  @override
  State<_CitySearch> createState() => _CitySearchState();
}

class _CitySearchState extends State<_CitySearch> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Onde você quer planejar?',
              style: TextStyle(
                  color: _ink, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            onChanged: (value) =>
                context.read<CitySearchBloc>().add(CityQueryChanged(value)),
            decoration: InputDecoration(
              hintText: 'Busque uma cidade',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                  tooltip: 'Limpar busca',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    controller.clear();
                    context
                        .read<CitySearchBloc>()
                        .add(const CityQueryChanged(''));
                  }),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          BlocBuilder<CitySearchBloc, CitySearchState>(
              builder: (context, state) {
            if (state.status == CitySearchStatus.idle) {
              return const SizedBox.shrink();
            }
            if (state.status == CitySearchStatus.waiting ||
                state.status == CitySearchStatus.loading) {
              return const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(minHeight: 2));
            }
            if (state.status == CitySearchStatus.failure) {
              return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _Notice(state.error!,
                      onRetry: () => context
                          .read<CitySearchBloc>()
                          .add(const CitySearchRetried())));
            }
            if (state.status == CitySearchStatus.empty) {
              return const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Nenhuma cidade encontrada. Tente outro nome.'));
            }
            return Column(children: [
              for (final city in state.cities)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.location_on_outlined, color: _green),
                  title: Text(city.name),
                  subtitle: Text(city.label),
                  onTap: () {
                    context
                        .read<ForecastBloc>()
                        .add(ForecastCitySelected(city));
                    controller.clear();
                    context
                        .read<CitySearchBloc>()
                        .add(const CityQueryChanged(''));
                    FocusScope.of(context).unfocus();
                  },
                ),
            ]);
          }),
        ]),
      ));
}

class _CurrentWeather extends StatelessWidget {
  const _CurrentWeather({required this.report});
  final WeatherReport report;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
              colors: [Color(0xFF20564A), Color(0xFF268F73)]),
        ),
        child: Wrap(
            spacing: 30,
            runSpacing: 22,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(report.city.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 21)),
                const SizedBox(height: 8),
                Text(
                    '${_weekday(report.cityNow)} • ${_hour(report.cityNow)} • ${report.city.timezone}',
                    style: const TextStyle(color: Color(0xFFDDF3E9))),
                const SizedBox(height: 22),
                Text(_temperature(report.temperature),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 70,
                        height: 1,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(_condition(report.weatherCode),
                    style: const TextStyle(color: Colors.white, fontSize: 17)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _WeatherMetric(Icons.water_drop_outlined, 'Chance de chuva',
                    report.rainChance == null ? '—' : '${report.rainChance}%'),
                const SizedBox(height: 16),
                _WeatherMetric(
                    Icons.air_rounded,
                    'Vento',
                    report.windSpeed == null
                        ? '—'
                        : '${report.windSpeed!.round()} km/h'),
              ]),
            ]),
      );
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.white, size: 25),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Color(0xFFDDF3E9))),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
      ]);
}

class _WalkCard extends StatelessWidget {
  const _WalkCard({required this.report});
  final WeatherReport report;
  @override
  Widget build(BuildContext context) {
    final hours = bestWalkingHours(report);
    return Card(
        color: const Color(0xFFEAF4EC),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.directions_walk_rounded, color: _green),
              SizedBox(width: 10),
              Flexible(
                  child: Text('Melhor horário para caminhar',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _ink)))
            ]),
            const SizedBox(height: 8),
            const Text(
                'Sugestões para as próximas 24 horas, com base em chuva, temperatura e vento.',
                style: TextStyle(color: _muted)),
            const SizedBox(height: 18),
            if (hours.isEmpty)
              const Text(
                  'Nenhum horário diurno atende aos critérios agora. Confira a previsão abaixo.',
                  style: TextStyle(color: _ink))
            else
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final hour in hours)
                  Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_weekday(hour.time)} · ${_hour(hour.time)}',
                                style: const TextStyle(
                                    color: _ink, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Text(
                                '${_temperature(hour.temperature)} · chuva ${hour.rainChance}% · vento ${hour.windSpeed!.round()} km/h',
                                style: const TextStyle(color: _muted)),
                          ])),
              ]),
          ]),
        ));
  }
}

class _HourlyList extends StatelessWidget {
  const _HourlyList({required this.report});
  final WeatherReport report;
  @override
  Widget build(BuildContext context) {
    final end = report.cityNow.add(const Duration(hours: 24));
    final hours = report.hours
        .where((h) => !h.time.isBefore(report.cityNow) && h.time.isBefore(end))
        .toList();
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
        height: 170 * scale + 24,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: hours.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final hour = hours[i];
            return SizedBox(
                width: 130 * scale + 20,
                child: Card(
                    child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_hour(hour.time),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: _ink)),
                              const Spacer(),
                              Icon(_icon(hour.weatherCode), color: _green),
                              const SizedBox(height: 6),
                              Text(_temperature(hour.temperature),
                                  style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: _ink)),
                              Text(
                                  hour.rainChance == null
                                      ? 'Chuva —'
                                      : 'Chuva ${hour.rainChance}%',
                                  style: const TextStyle(
                                      color: _muted, fontSize: 12)),
                            ]))));
          },
        ));
  }
}

class _DailyList extends StatelessWidget {
  const _DailyList({required this.report});
  final WeatherReport report;
  @override
  Widget build(BuildContext context) => Card(
          child: Column(children: [
        for (final day in report.days) ...[
          ListTile(
            leading: Icon(_icon(day.weatherCode), color: _green),
            title: Text(
                '${_weekday(day.date)} ${day.date.day}/${day.date.month}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(_condition(day.weatherCode)),
            trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                      '${_temperature(day.minimum)} – ${_temperature(day.maximum)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: _ink)),
                  Text(
                      day.rainChance == null
                          ? 'Chuva —'
                          : 'Chuva ${day.rainChance}%',
                      style: const TextStyle(color: _muted, fontSize: 12)),
                ]),
          ),
          if (day != report.days.last) const Divider(height: 1),
        ],
      ]));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800, color: _ink))),
        if (trailing != null) trailing!,
      ]);
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
      color: const Color(0xFFFFF4E5),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(message),
              TextButton(
                  onPressed: onRetry, child: const Text('Tentar novamente'))
            ],
          )));
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const Card(
      child: Padding(
          padding: EdgeInsets.all(36),
          child: Row(children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Flexible(child: Text('Buscando previsão…'))
          ])));
}

String _temperature(double? value) =>
    value == null ? '—' : '${value.round()}°C';
String _hour(DateTime date) => '${date.hour.toString().padLeft(2, '0')}:00';
String _weekday(DateTime date) =>
    const ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'][date.weekday - 1];
String _condition(int? code) {
  if (code == null) return 'Condição indisponível';
  if (code == 0) return 'Céu limpo';
  if (code <= 3) return 'Parcialmente nublado';
  if (code <= 48) return 'Névoa';
  if (code <= 67) return 'Chuva';
  if (code <= 77) return 'Neve';
  if (code <= 82) return 'Pancadas de chuva';
  if (code <= 86) return 'Neve';
  return 'Tempestade';
}

IconData _icon(int? code) {
  if (code == null) return Icons.cloud_outlined;
  if (code == 0) return Icons.wb_sunny_rounded;
  if (code <= 3) return Icons.wb_cloudy_rounded;
  if (code <= 48) return Icons.foggy;
  if (code <= 67) return Icons.water_drop_rounded;
  if (code <= 77) return Icons.ac_unit_rounded;
  return Icons.thunderstorm_rounded;
}
