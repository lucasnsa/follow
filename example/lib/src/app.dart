import 'package:flutter/material.dart';
import 'package:follow/follow.dart';

import 'design.dart';
import 'navigation.dart';
import 'pages.dart';
import 'products.dart';

class Session {
  bool signedIn = false;
}

final sessionToken = Token<Session>('session');

final appFeature = Feature(
  name: 'app',
  bindings: [
    Bind.async(sessionToken, (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return Session();
    }),
  ],
  routes: [
    FeatureRoute.page(homeRoute, builder: (_, __) => const OverviewPage()),
    FeatureRoute.page(
      exploreRoute,
      builder: (_, __) => const ExplorePage(),
    ),
    FeatureRoute.page(
      loginRoute,
      builder: (_, next) => LoginPage(next: next),
    ),
    FeatureRoute.page(
      deniedDemoRoute,
      guards: [(_, __) => const GuardResult.deny()],
      builder: (_, __) => const SizedBox.shrink(),
    ),
    FeatureRoute.page(
      errorDemoRoute,
      guards: [(_, __) => throw StateError('Falha simulada pelo guard')],
      builder: (_, __) => const SizedBox.shrink(),
    ),
    FeatureRoute.mount(
      productsMountRoute,
      guards: [
        (_, read) async {
          final session = await read.async(sessionToken);
          return session.signedIn
              ? const GuardResult.allow()
              : GuardResult.redirect(loginRoute.location('/products'));
        },
      ],
      feature: (_) => productsFeature,
    ),
  ],
);

class FollowExample extends StatelessWidget {
  const FollowExample({super.key});

  @override
  Widget build(BuildContext context) => FollowApp(
        feature: appFeature,
        loadingBuilder: (_) => const AppStatePage(
          icon: Icons.route_rounded,
          title: 'Preparando as rotas',
          message: 'A feature raiz está sendo resolvida.',
          busy: true,
        ),
        notFoundBuilder: (_, data) => NotFoundPage(uri: data.uri),
        deniedBuilder: (_, data) => AppStatePage(
          icon: Icons.lock_outline_rounded,
          title: 'Acesso não autorizado',
          message: 'O guard bloqueou o acesso a ${data.uri.path}.',
          actionLabel: 'Ir ao início',
          actionLocation: homeRoute.location,
        ),
        errorBuilder: (_, error, __) => AppStatePage(
          icon: Icons.error_outline_rounded,
          title: 'Não foi possível navegar',
          message: '$error',
          actionLabel: 'Voltar ao início',
          actionLocation: homeRoute.location,
        ),
        builder: (_, routerConfig) => MaterialApp.router(
          title: 'Follow Playground',
          debugShowCheckedModeBanner: false,
          theme: buildExampleTheme(),
          routerConfig: routerConfig,
        ),
      );
}
