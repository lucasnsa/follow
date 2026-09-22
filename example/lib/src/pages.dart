import 'dart:async';

import 'package:flutter/material.dart';
import 'package:follow/follow.dart';

import 'app.dart';
import 'design.dart';
import 'navigation.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final navigation = context.follow;
    return AppShell(
      section: 0,
      title: 'Modularização que acompanha a árvore',
      subtitle:
          'Explore escopos de dependência, features ativadas por rota, guards e carregamento lazy em um único exemplo.',
      actions: [
        FilledButton.icon(
          onPressed: () => navigation.push(productsMountRoute.location),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Abrir produtos'),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF312E81), Color(0xFF6366F1)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Wrap(
            runSpacing: 24,
            spacing: 30,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uma feature, um escopo, uma rota.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'A feature de produtos só nasce quando sua rota é ativada. As páginas internas compartilham o mesmo catálogo e relatório.',
                      style: TextStyle(
                        color: Color(0xFFDDE1FF),
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: () => navigation.push(
                  productDetailsRoute.location((id: '42', sort: 'price')),
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Link direto /products/42'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'O que está acontecendo',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        ResponsiveGrid(children: [
          const FeatureCard(
            icon: Icons.layers_outlined,
            title: 'Escopos na árvore',
            description:
                'Dependências locais sobrescrevem ancestrais, enquanto features irmãs permanecem isoladas.',
            badge: 'DI',
          ),
          const FeatureCard(
            icon: Icons.route_outlined,
            title: 'Rotas compostas',
            description:
                'Route specs compõem caminhos tipados e ativam somente a cadeia necessária.',
            badge: 'Router',
          ),
          const FeatureCard(
            icon: Icons.hourglass_bottom_rounded,
            title: 'Inicialização lazy',
            description:
                'O relatório espera cinco segundos e é criado somente no primeiro acesso.',
            badge: 'Async',
          ),
          FeatureCard(
            icon: Icons.science_outlined,
            title: 'Estados do router',
            description:
                'Veja loading, 404, acesso negado, erros e redirecionamentos em ação.',
            action: () => navigation.push(exploreRoute.location),
            actionLabel: 'Explorar recursos',
          ),
        ]),
      ]),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({required this.next, super.key});
  final String next;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

RouteLocation _locationFor(String location) {
  final uri = Uri.parse(location);
  final segments = uri.pathSegments;
  if (segments.length == 2 && segments.first == 'products') {
    return productDetailsRoute.location((
      id: segments.last,
      sort: uri.queryParameters['sort'],
    ));
  }
  if (segments.length == 1 && segments.first == 'products') {
    return productsListRoute.location(uri.queryParameters['sort']);
  }
  return homeRoute.location;
}

class _LoginPageState extends State<LoginPage> {
  bool busy = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const BrandMark(),
                      const SizedBox(height: 30),
                      const Icon(
                        Icons.shield_outlined,
                        size: 50,
                        color: appIndigo,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Área protegida',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Um guard redirecionou você para esta sessão demonstrativa. Nenhum dado real é solicitado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF667085),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Destino: ${widget.next}',
                        style: const TextStyle(
                          color: appIndigo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: busy ? null : _signIn,
                          icon: busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(
                            busy ? 'Entrando…' : 'Entrar e continuar',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => context.follow.go(homeRoute.location),
                        child: const Text('Voltar ao início'),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> _signIn() async {
    final session = await context.follow.readAsync(sessionToken);
    if (!mounted) return;
    setState(() => busy = true);
    session.signedIn = true;
    await context.follow.replace(_locationFor(widget.next));
    if (mounted) setState(() => busy = false);
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({required this.uri, super.key});
  final Uri uri;

  @override
  Widget build(BuildContext context) => AppStatePage(
        icon: Icons.travel_explore_rounded,
        eyebrow: 'ERRO 404',
        title: 'Essa rota não foi encontrada',
        message: 'Nenhuma feature ativa declarou “${uri.path}”.',
        actionLabel: 'Ir ao início',
        actionLocation: homeRoute.location,
        secondaryLabel: 'Voltar',
      );
}

class AppStatePage extends StatelessWidget {
  const AppStatePage({
    required this.icon,
    required this.title,
    required this.message,
    this.eyebrow,
    this.actionLabel,
    this.actionLocation,
    this.secondaryLabel,
    this.busy = false,
    super.key,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? eyebrow;
  final String? actionLabel;
  final RouteLocation? actionLocation;
  final String? secondaryLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: busy
                          ? const SizedBox.square(
                              dimension: 34,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : Icon(icon, size: 38, color: appIndigo),
                    ),
                    const SizedBox(height: 22),
                    if (eyebrow != null) ...[
                      Text(
                        eyebrow!,
                        style: const TextStyle(
                          color: appIndigo,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        height: 1.5,
                      ),
                    ),
                    if (actionLabel != null) ...[
                      const SizedBox(height: 26),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton(
                            onPressed: () => context.follow.go(actionLocation!),
                            child: Text(actionLabel!),
                          ),
                          if (secondaryLabel != null)
                            OutlinedButton(
                              onPressed: () async {
                                final didPop = await context.follow.pop();
                                if (!didPop && context.mounted) {
                                  await context.follow.go(homeRoute.location);
                                }
                              },
                              child: Text(secondaryLabel!),
                            ),
                        ],
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

enum PreviewKind { loading, denied, error }

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  String? notice;
  PreviewKind? preview;

  @override
  Widget build(BuildContext context) {
    final navigation = context.follow;
    return AppShell(
      section: 2,
      title: 'Explore os estados do router',
      subtitle:
          'Cada ação executa um comportamento real. As prévias isoladas não alteram a URL principal.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (notice != null) ...[
          MaterialBanner(
            backgroundColor: const Color(0xFFFFFAEB),
            leading: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFB54708),
            ),
            content: Text(notice!),
            actions: [
              TextButton(
                onPressed: () => setState(() => notice = null),
                child: const Text('Fechar'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        ResponsiveGrid(children: [
          FeatureCard(
            icon: Icons.travel_explore_rounded,
            title: 'Página não encontrada',
            description:
                'Navega para uma URI não declarada e usa o notFoundBuilder real.',
            badge: '404',
            action: () => navigation.push(missingDemoRoute.location),
            actionLabel: 'Abrir rota inválida',
          ),
          FeatureCard(
            icon: Icons.lock_outline_rounded,
            title: 'Acesso negado',
            description:
                'O guard retorna deny. A tela atual e a URL são preservadas.',
            badge: 'Guard',
            actionLabel: 'Executar guard',
            action: () async {
              await navigation.push(deniedDemoRoute.location);
              if (mounted) {
                setState(() => notice =
                    'O guard negou a navegação. A página atual permaneceu montada.');
              }
            },
          ),
          FeatureCard(
            icon: Icons.warning_amber_rounded,
            title: 'Erro controlado',
            description:
                'Um guard lança uma exceção e o router expõe o erro sem perder a página.',
            badge: 'Error',
            actionLabel: 'Simular erro',
            action: () async {
              await navigation.push(errorDemoRoute.location);
              if (mounted) {
                setState(() =>
                    notice = 'Erro observado: ${navigation.navigationError}');
              }
            },
          ),
          FeatureCard(
            icon: Icons.tune_rounded,
            title: 'Parâmetros e query',
            description:
                'Abre o produto 43 e ordena o catálogo por preço através da URI.',
            badge: 'URI',
            action: () => navigation.push(
              productDetailsRoute.location((id: '43', sort: 'price')),
            ),
            actionLabel: 'Abrir produto 43',
          ),
          FeatureCard(
            icon: Icons.hourglass_bottom_rounded,
            title: 'Loading inicial',
            description: 'Executa um guard assíncrono em um router isolado.',
            badge: 'Builder',
            action: () => setState(() => preview = PreviewKind.loading),
            actionLabel: 'Abrir prévia',
          ),
          FeatureCard(
            icon: Icons.web_asset_off_rounded,
            title: 'Builders iniciais',
            description:
                'Compare deniedBuilder e errorBuilder quando ainda não existe uma página anterior.',
            badge: 'Fallback',
            action: () => setState(() => preview = PreviewKind.denied),
            actionLabel: 'Abrir deniedBuilder',
          ),
        ]),
        if (preview != null) ...[
          const SizedBox(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Prévia isolada',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              SegmentedButton<PreviewKind>(
                segments: const [
                  ButtonSegment(
                    value: PreviewKind.loading,
                    label: Text('Loading'),
                  ),
                  ButtonSegment(
                    value: PreviewKind.denied,
                    label: Text('Negado'),
                  ),
                  ButtonSegment(
                    value: PreviewKind.error,
                    label: Text('Erro'),
                  ),
                ],
                selected: {preview!},
                onSelectionChanged: (value) =>
                    setState(() => preview = value.first),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RouterPreview(key: ValueKey(preview), kind: preview!),
        ],
      ]),
    );
  }
}

class RouterPreview extends StatefulWidget {
  const RouterPreview({required this.kind, super.key});
  final PreviewKind kind;

  @override
  State<RouterPreview> createState() => _RouterPreviewState();
}

class _RouterPreviewState extends State<RouterPreview> {
  late final _MemoryRouteInformationProvider provider;

  @override
  void initState() {
    super.initState();
    provider = _MemoryRouteInformationProvider(
      RouteInformation(uri: Uri.parse('/preview')),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 360,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE7EAF2)),
            ),
            child: FollowApp(
              feature: _previewFeature(widget.kind),
              routeInformationProvider: provider,
              loadingBuilder: (_) => const AppStatePage(
                icon: Icons.hourglass_bottom_rounded,
                title: 'Aguardando o guard',
                message:
                    'A página atual ainda não existe nesta navegação inicial.',
                busy: true,
              ),
              deniedBuilder: (_, __) => const AppStatePage(
                icon: Icons.lock_outline_rounded,
                title: 'Acesso negado pelo guard',
                message:
                    'Este é o deniedBuilder configurado no router isolado.',
              ),
              errorBuilder: (_, error, __) => AppStatePage(
                icon: Icons.error_outline_rounded,
                title: 'Erro capturado',
                message: '$error',
              ),
              builder: (_, routerConfig) => MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: buildExampleTheme(),
                routerConfig: routerConfig,
              ),
            ),
          ),
        ),
      );

  @override
  void dispose() {
    provider.dispose();
    super.dispose();
  }
}

Feature _previewFeature(PreviewKind kind) => Feature(
      name: 'preview-${kind.name}',
      routes: [
        FeatureRoute.page(
          previewRoute,
          guards: [
            (_, __) async {
              switch (kind) {
                case PreviewKind.loading:
                  await Future<void>.delayed(const Duration(seconds: 2));
                  return const GuardResult.allow();
                case PreviewKind.denied:
                  return const GuardResult.deny();
                case PreviewKind.error:
                  throw StateError('Exceção simulada na navegação inicial');
              }
            },
          ],
          builder: (_, __) => const AppStatePage(
            icon: Icons.check_circle_outline_rounded,
            title: 'Guard concluído',
            message: 'A navegação assíncrona terminou com sucesso.',
          ),
        ),
      ],
    );

class _MemoryRouteInformationProvider extends RouteInformationProvider
    with ChangeNotifier {
  _MemoryRouteInformationProvider(this._value);
  RouteInformation _value;

  @override
  RouteInformation get value => _value;

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    _value = routeInformation;
  }
}
