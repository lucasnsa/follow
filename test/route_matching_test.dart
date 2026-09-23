import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/follow.dart';

import 'router_test.dart' show app, parameterRoute;

void main() {
  for (final count in [8, 64]) {
    testWidgets('equal suffix specificity preserves sorting for $count routes',
        (tester) async {
      const base = ['a', 'b', 'c', 'd', 'e', 'f'];
      final expected = List.generate(count, (i) => i)..sort((a, b) => 0);
      final child = Feature(name: 'child', routes: [
        for (var mask = 0; mask < count; mask++)
          FeatureRoute.page(
            DataRouteSpec<int>(
              '/${[
                for (var i = 0; i < base.length; i++)
                  mask & (1 << i) == 0 ? base[i] : ':p$i',
              ].join('/')}/item/:id',
              decoder: (_) => mask,
              encoder: (_) => (path: const {}, query: const {}),
            ),
            builder: (_, value) => Text('winner:$value'),
          ),
      ]);
      await tester.pumpWidget(app(
        Feature(name: 'root', routes: [
          FeatureRoute.mount(StaticRouteSpec('/a/b/c/d/e/f'),
              feature: (_) => child),
        ]),
        initialLocation: '/a/b/c/d/e/f/item/value',
      ));
      await tester.pumpAndSettle();
      expect(find.text('winner:${expected.first}'), findsOneWidget);
    });
  }

  testWidgets('specificity is lexicographic, not a count of literals',
      (tester) async {
    await tester.pumpWidget(app(
      Feature(name: 'root', routes: [
        FeatureRoute.page(parameterRoute('/:group/detail', 'group'),
            builder: (_, __) => const Text('parameter first')),
        FeatureRoute.page(parameterRoute('/fixed/:id', 'id'),
            builder: (_, __) => const Text('literal first')),
      ]),
      initialLocation: '/fixed/detail',
    ));
    await tester.pumpAndSettle();
    expect(find.text('literal first'), findsOneWidget);
  });

  for (final path in ['/items/a%20b?sort=new', '/items/a%20b/?sort=new']) {
    testWidgets('encoded parameters and query are preserved: $path',
        (tester) async {
      final item = parameterRoute('/items/:id', 'id');
      await tester.pumpWidget(app(
        Feature(name: 'root', routes: [
          FeatureRoute.page(item, builder: (context, id) {
            final data = context.follow.route;
            return Text('$id|${data.query['sort']}|${data.uri.path}');
          }),
        ]),
        initialLocation: path,
      ));
      await tester.pumpAndSettle();
      expect(find.text('a b|new|/items/a%20b'), findsOneWidget);
    });
  }

  for (final reverse in [false, true]) {
    testWidgets('literal beats allowed mounted prefix, reversed=$reverse',
        (tester) async {
      var mounts = 0;
      final routes = [
        FeatureRoute.mount(parameterRoute('/:group', 'group'), feature: (_) {
          mounts++;
          return Feature(name: 'child', routes: [
            FeatureRoute.page(parameterRoute('/:group/:id', 'id'),
                builder: (_, id) => Text('child:$id')),
          ]);
        }),
        FeatureRoute.page(StaticRouteSpec('/fixed/detail'),
            builder: (_, __) => const Text('literal')),
      ];
      await tester.pumpWidget(app(
        Feature(name: 'root', routes: reverse ? routes.reversed : routes),
        initialLocation: '/fixed/detail',
      ));
      await tester.pumpAndSettle();
      expect(find.text('literal'), findsOneWidget);
      expect(mounts, 0);
    });
  }

  testWidgets('nested matching preserves inherited encoded parameters',
      (tester) async {
    await tester.pumpWidget(app(
      Feature(name: 'root', routes: [
        FeatureRoute.mount(parameterRoute('/teams/:team', 'team'),
            feature: (_) => Feature(name: 'team', routes: [
                  FeatureRoute.mount(
                      parameterRoute('/teams/:team/catalog', 'team'),
                      feature: (_) => Feature(name: 'catalog', routes: [
                            FeatureRoute.page(
                              parameterRoute('/teams/:team/catalog/:id', 'id'),
                              builder: (context, id) => Text(
                                  '${context.follow.route.params['team']}|$id|${context.follow.route.query['q']}'),
                            ),
                          ])),
                ])),
      ]),
      initialLocation: '/teams/a%20b/catalog/c%2Fd/?q=yes',
    ));
    await tester.pumpAndSettle();
    expect(find.text('a b|c/d|yes'), findsOneWidget);
  });
}
