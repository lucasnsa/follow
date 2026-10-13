import 'package:flutter/material.dart';
import 'package:follow/follow.dart';

import 'navigation.dart';
import 'motion.dart';

final shellDemoRoute = StaticRouteSpec('/stacks');
final _catalog = StaticRouteSpec('/stacks/catalog');
final _favorites = StaticRouteSpec('/stacks/favorites');
final _catalogDetail = StaticRouteSpec('/stacks/catalog/details');
final _favoritesDetail = StaticRouteSpec('/stacks/favorites/details');

final shellDemoFeature = Feature(
  name: 'independent-stacks',
  pageTransition: sharedAxisTransition,
  shell: FeatureShell.animated(
    transition: fadeThroughBranches,
    branches: [
      FeatureBranch.mount(_catalog,
          feature: (_) => _branch('Catálogo', _catalog, _catalogDetail),
          initialLocation: _catalog.location),
      FeatureBranch.mount(_favorites,
          feature: (_) => _branch('Favoritos', _favorites, _favoritesDetail),
          initialLocation: _favorites.location),
    ],
    builder: (context, navigation, outlet) => Scaffold(
      appBar: AppBar(
        title: const Text('Pilhas independentes'),
        leading: IconButton(
          tooltip: 'Exemplos',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.follow.go(homeRoute.location),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                navigation.goBranch(navigation.currentIndex, reset: true),
            child: const Text('Reiniciar aba'),
          ),
        ],
      ),
      body: outlet,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigation.currentIndex,
        onDestinationSelected: (index) => navigation.goBranch(index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.store_outlined), label: 'Catálogo'),
          NavigationDestination(
              icon: Icon(Icons.favorite_outline), label: 'Favoritos'),
        ],
      ),
    ),
  ),
);

Feature _branch(String title, StaticRouteSpec start, StaticRouteSpec detail) =>
    Feature(
      name: title,
      routes: [
        FeatureRoute.page(start,
            builder: (_, __) => _BranchPage(title: title, detail: detail)),
        FeatureRoute.page(detail,
            builder: (context, _) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Detalhes de $title',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    const Text(
                        'Troque de aba e volte: esta página continua aqui.'),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: () async {
                          if (!await context.follow.pop() && context.mounted) {
                            await context.follow.go(start.location);
                          }
                        },
                        child: const Text('Voltar à lista')),
                  ]),
                )),
      ],
    );

class _BranchPage extends StatelessWidget {
  const _BranchPage({required this.title, required this.detail});
  final String title;
  final StaticRouteSpec detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const Text(
              'Escreva uma nota, role a lista e visite os detalhes. Cada aba guarda seu lugar.'),
          const SizedBox(height: 16),
          const TextField(
              decoration: InputDecoration(
                  labelText: 'Sua nota nesta aba',
                  border: OutlineInputBorder())),
          const SizedBox(height: 16),
          Expanded(
              child: ListView.builder(
                  itemCount: 80,
                  itemBuilder: (context, index) => ListTile(
                        title: Text('$title — item ${index + 1}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.follow.push(detail.location),
                      ))),
        ]),
      );
}
