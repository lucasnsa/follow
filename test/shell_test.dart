import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/follow.dart';
import 'router_test.dart' show app, navigate, MemoryRouteInformationProvider;

class ShellFixture {
  final a = StaticRouteSpec('/tabs/a');
  final detailA = StaticRouteSpec('/tabs/a/details');
  final b = StaticRouteSpec('/tabs/b');
  final detailB = StaticRouteSpec('/tabs/b/details');
  final tabs = StaticRouteSpec('/tabs');
  final home = StaticRouteSpec('/');
  final outside = StaticRouteSpec('/outside');
  late FollowContext follow;
  late FollowShellController controller;
  final created = <String>[];
  final disposed = <String>[];
  final instances = <String, Object>{};
  FutureOr<GuardResult> Function()? guard;
  int initialIndex = 0;

  Feature branch(String name, StaticRouteSpec start, StaticRouteSpec detail) =>
      Feature(
        name: name,
        bindings: [
          Bind.singleton(Token<Object>(), (_) {
            created.add(name);
            return Object();
          }, dispose: (_) => disposed.add(name))
        ],
        routes: [
          FeatureRoute.page(start, builder: (context, _) {
            instances[name] = context.follow.read<Object>();
            return Scaffold(
                body: Column(children: [
              Text(name),
              TextField(key: ValueKey('field-$name')),
              Expanded(
                  child: ListView.builder(
                      key: ValueKey('list-$name'),
                      itemCount: 100,
                      itemBuilder: (_, index) => Text('$name item $index'))),
            ]));
          }),
          FeatureRoute.page(detail, builder: (_, __) => Text('$name details')),
        ],
      );

  late final shellFeature = Feature(
      name: 'tabs',
      shell: FeatureShell.indexedStack(
        initialIndex: initialIndex,
        branches: [
          FeatureBranch.mount(a,
              feature: (_) => branch('A', a, detailA),
              initialLocation: a.location),
          FeatureBranch.mount(b,
              feature: (_) => branch('B', b, detailB),
              initialLocation: b.location,
              guards: [(_, __) => guard?.call() ?? const GuardResult.allow()]),
        ],
        builder: (context, navigation, outlet) {
          controller = navigation;
          follow = context.follow;
          return Scaffold(
              body: outlet,
              bottomNavigationBar:
                  Text('tab ${context.follow.shell.currentIndex}'));
        },
      ));

  late final root = Feature(name: 'root', routes: [
    FeatureRoute.page(home, builder: (_, __) => const Text('home')),
    FeatureRoute.page(outside, builder: (_, __) => const Text('outside')),
    FeatureRoute.mount(tabs, feature: (_) => shellFeature),
  ]);
}

void main() {
  testWidgets('lazy branches retain stacks, form, scroll and dependencies',
      (tester) async {
    final f = ShellFixture();
    await tester.pumpWidget(app(f.root, initialLocation: '/tabs/a'));
    await tester.pumpAndSettle();
    expect(f.created, ['A']);
    final instance = f.instances['A'];
    await tester.enterText(find.byKey(const ValueKey('field-A')), 'preserved');
    await tester.drag(
        find.byKey(const ValueKey('list-A')), const Offset(0, -400));
    await tester.pumpAndSettle();
    final scroll = tester
        .state<ScrollableState>(find.descendant(
            of: find.byKey(const ValueKey('list-A')),
            matching: find.byType(Scrollable)))
        .position
        .pixels;
    await navigate(tester, f.follow.push(f.detailA.location));
    await navigate(tester, f.controller.goBranch(1));
    expect(find.text('B'), findsOneWidget);
    expect(f.created, ['A', 'B']);
    await navigate(tester, f.follow.push(f.detailB.location));
    await navigate(tester, f.controller.goBranch(0));
    expect(find.text('A details'), findsOneWidget);
    expect(f.disposed, isEmpty);
    expect(await f.follow.pop(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('preserved'), findsOneWidget);
    expect(identical(instance, f.instances['A']), isTrue);
    expect(
        tester
            .state<ScrollableState>(find.descendant(
                of: find.byKey(const ValueKey('list-A')),
                matching: find.byType(Scrollable)))
            .position
            .pixels,
        scroll);
    expect(await f.follow.pop(), isFalse);
    await navigate(tester, f.controller.goBranch(1));
    expect(find.text('B details'), findsOneWidget);
    await navigate(tester, f.controller.goBranch(1, reset: true));
    expect(find.text('B'), findsOneWidget);
    expect(f.created, ['A', 'B']);
    await navigate(tester, f.follow.go(f.outside.location));
    expect(f.disposed, unorderedEquals(['A', 'B']));
  });

  testWidgets('base and deep links select branches without inventing history',
      (tester) async {
    final f = ShellFixture()..initialIndex = 1;
    await tester.pumpWidget(app(f.root, initialLocation: '/tabs'));
    await tester.pumpAndSettle();
    expect(f.controller.currentIndex, 1);
    expect(f.follow.currentUri.toString(), '/tabs/b');
    expect(f.created, ['B']);
    await navigate(tester, f.follow.go(f.detailA.location));
    expect(f.controller.currentIndex, 0);
    expect(find.text('A details'), findsOneWidget);
    expect(await f.follow.pop(), isFalse);
    await navigate(tester, f.controller.goBranch(1));
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('guards and cancelled switches preserve active branch',
      (tester) async {
    final f = ShellFixture();
    await tester.pumpWidget(app(f.root, initialLocation: '/tabs/a'));
    await tester.pumpAndSettle();
    f.guard = () => const GuardResult.deny();
    await navigate(tester, f.controller.goBranch(1));
    expect(f.controller.currentIndex, 0);
    expect(f.created, ['A']);
    final gate = Completer<GuardResult>();
    f.guard = () => gate.future;
    final pending = f.controller.goBranch(1);
    await tester.pumpAndSettle();
    await navigate(tester, f.follow.push(f.detailA.location));
    await pending;
    gate.complete(const GuardResult.allow());
    await tester.pumpAndSettle();
    expect(f.controller.currentIndex, 0);
    expect(find.text('A details'), findsOneWidget);
    expect(f.disposed, isEmpty);
  });

  testWidgets('browser restores active selection and independent stacks',
      (tester) async {
    final f = ShellFixture();
    final provider = MemoryRouteInformationProvider('/tabs/a');
    addTearDown(provider.dispose);
    await tester.pumpWidget(app(f.root, provider: provider));
    await tester.pumpAndSettle();
    await navigate(tester, f.follow.push(f.detailA.location));
    await navigate(tester, f.controller.goBranch(1));
    await navigate(tester, f.follow.push(f.detailB.location));
    final snapshot = provider.value;
    expect((snapshot.state as Map)['follow'], 2);
    await navigate(tester, f.controller.goBranch(0, reset: true));
    provider.restore(snapshot);
    await tester.pumpAndSettle();
    expect(find.text('B details'), findsOneWidget);
    expect(f.controller.currentIndex, 1);
    await navigate(tester, f.controller.goBranch(0));
    expect(find.text('A details'), findsOneWidget);
    expect(f.created, ['A', 'B']);
  });

  test('invalid shell declarations fail early', () {
    final f = ShellFixture();
    expect(
        () => Feature(
            name: 'invalid',
            routes: [
              FeatureRoute.page(f.home, builder: (_, __) => const SizedBox())
            ],
            shell: f.shellFeature.shell),
        throwsArgumentError);
    expect(
        () => FeatureShell.indexedStack(
            branches: [], builder: (_, __, child) => child),
        throwsArgumentError);
    expect(
        () => FeatureBranch.mount(f.a,
            feature: (_) => Feature(name: 'a'), initialLocation: f.b.location),
        throwsArgumentError);
  });
  testWidgets('root shell handles fallbacks and recovers', (tester) async {
    final f = ShellFixture();
    await tester.pumpWidget(app(f.shellFeature, initialLocation: '/missing'));
    await tester.pumpAndSettle();
    expect(find.text('Not found: /missing'), findsOneWidget);
    await navigate(tester, f.controller.goBranch(1));
    expect(find.text('B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('push replace go cross branches and pop delegates to parent',
      (tester) async {
    final f = ShellFixture();
    final provider = MemoryRouteInformationProvider('/');
    addTearDown(provider.dispose);
    await tester.pumpWidget(app(f.root, provider: provider));
    await tester.pumpAndSettle();
    // A root context allows us to push the shell over the home page.
    final rootContext = tester.element(find.text('home')).follow;
    await navigate(tester, rootContext.push(f.a.location));
    await navigate(tester, f.follow.push(f.detailA.location));
    await navigate(tester, f.follow.push(f.b.location));
    await navigate(tester, f.follow.replace(f.detailB.location));
    expect(find.text('B details'), findsOneWidget);
    await navigate(tester, f.controller.goBranch(0));
    expect(find.text('A details'), findsOneWidget);
    await navigate(tester, f.follow.go(f.a.location));
    await navigate(tester, f.controller.goBranch(1));
    expect(find.text('B details'), findsOneWidget);
    // go reconstructs the ancestor stack too, so home is no longer underneath.
    expect(await f.follow.pop(), isFalse);
    await navigate(tester, f.follow.go(f.home.location));
    await navigate(
        tester, tester.element(find.text('home')).follow.push(f.a.location));
    await navigate(tester, f.controller.goBranch(1));
    expect(await f.follow.pop(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('selecting current branch cancels a pending switch',
      (tester) async {
    final f = ShellFixture();
    await tester.pumpWidget(app(f.root, initialLocation: '/tabs/a'));
    await tester.pumpAndSettle();
    final gate = Completer<GuardResult>();
    f.guard = () => gate.future;
    final pending = f.controller.goBranch(1);
    await tester.pumpAndSettle();
    await navigate(tester, f.controller.goBranch(0));
    await pending;
    gate.complete(const GuardResult.allow());
    await tester.pumpAndSettle();
    expect(f.controller.currentIndex, 0);
    expect(f.follow.isNavigating, isFalse);
  });

  testWidgets('inactive denied snapshot branch is discarded', (tester) async {
    final f = ShellFixture();
    final provider = MemoryRouteInformationProvider('/tabs/a');
    addTearDown(provider.dispose);
    await tester.pumpWidget(app(f.root, provider: provider));
    await tester.pumpAndSettle();
    await navigate(tester, f.controller.goBranch(1));
    await navigate(tester, f.controller.goBranch(0));
    final snapshot = provider.value;
    f.guard = () => const GuardResult.deny();
    provider.restore(snapshot);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(f.disposed, ['B']);
    expect(f.follow.navigationError, isNull);
    f.guard = null;
    await navigate(tester, f.controller.goBranch(1));
    expect(f.created, ['A', 'B', 'B']);
  });

  testWidgets('fresh runtime restores snapshot and malformed snapshots use URL',
      (tester) async {
    final f = ShellFixture();
    final provider = MemoryRouteInformationProvider('/tabs/a');
    addTearDown(provider.dispose);
    await tester.pumpWidget(app(f.root, provider: provider));
    await tester.pumpAndSettle();
    await navigate(tester, f.follow.push(f.detailA.location));
    await navigate(tester, f.controller.goBranch(1));
    final snapshot = provider.value;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final next = ShellFixture();
    provider.restore(snapshot);
    await tester.pumpWidget(app(next.root, provider: provider));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    await navigate(tester, next.controller.goBranch(0));
    expect(find.text('A details'), findsOneWidget);
    provider.restore(RouteInformation(uri: Uri.parse('/tabs/b'), state: {
      'follow': 2,
      'tree': {'kind': 'shell', 'active': 99, 'pages': []},
    }));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('legacy snapshot remains readable', (tester) async {
    final f = ShellFixture();
    final provider = MemoryRouteInformationProvider('/');
    addTearDown(provider.dispose);
    provider.restore(RouteInformation(uri: Uri.parse('/outside'), state: {
      'follow': 1,
      'locations': [
        {
          'uri': '/',
          'ids': [0]
        },
        {
          'uri': '/outside',
          'ids': [1]
        },
      ],
    }));
    await tester.pumpWidget(app(f.root, provider: provider));
    await tester.pumpAndSettle();
    final navigation = tester.element(find.text('outside')).follow;
    expect(await navigation.pop(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('nested shells preserve both selections and nearest controller',
      (tester) async {
    final inner = ShellFixture();
    final other = StaticRouteSpec('/other');
    late FollowShellController outer;
    late FollowContext rootNavigation;
    final root = Feature(
        name: 'outer',
        shell: FeatureShell.indexedStack(
          branches: [
            FeatureBranch.mount(inner.tabs,
                feature: (_) => inner.shellFeature,
                initialLocation: inner.tabs.location),
            FeatureBranch.mount(other,
                feature: (_) => Feature(name: 'other', routes: [
                      FeatureRoute.page(other,
                          builder: (_, __) => const Text('other')),
                    ]),
                initialLocation: other.location),
          ],
          builder: (context, controller, outlet) {
            outer = controller;
            rootNavigation = context.follow;
            return outlet;
          },
        ));
    await tester.pumpWidget(app(root, initialLocation: '/tabs/a'));
    await tester.pumpAndSettle();
    expect(rootNavigation.navigationError, isNull);
    expect(identical(inner.follow.shell, inner.controller), isTrue);
    expect(identical(rootNavigation.shell, outer), isTrue);
    await navigate(tester, inner.follow.push(inner.detailA.location));
    await navigate(tester, inner.controller.goBranch(1));
    await navigate(tester, inner.follow.push(inner.detailB.location));
    await navigate(tester, outer.goBranch(1));
    expect(find.text('other'), findsOneWidget);
    await navigate(tester, outer.goBranch(0));
    expect(find.text('B details'), findsOneWidget);
    expect(inner.controller.currentIndex, 1);
    expect(inner.disposed, isEmpty);
    await navigate(tester, outer.goBranch(0, reset: true));
    expect(find.text('A'), findsOneWidget);
    expect(await inner.follow.pop(), isFalse);
  });
  testWidgets('reset preserves parent history and root fallbacks can pop',
      (tester) async {
    final f = ShellFixture();
    await tester.pumpWidget(app(f.root));
    await tester.pumpAndSettle();
    await navigate(
        tester, tester.element(find.text('home')).follow.push(f.a.location));
    await navigate(tester, f.follow.push(f.detailA.location));
    await navigate(tester, f.controller.goBranch(0, reset: true));
    expect(find.text('A'), findsOneWidget);
    expect(await f.follow.pop(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final rootShell = ShellFixture();
    await tester
        .pumpWidget(app(rootShell.shellFeature, initialLocation: '/tabs/a'));
    await tester.pumpAndSettle();
    await navigate(
        tester, rootShell.follow.push(StaticRouteSpec('/missing').location));
    expect(find.text('Not found: /missing'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    expect(await rootShell.follow.pop(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets(
      'guards can fail or redirect without partially selecting a branch',
      (tester) async {
    final f = ShellFixture();
    await tester.pumpWidget(app(f.root, initialLocation: '/tabs/a'));
    await tester.pumpAndSettle();
    f.guard = () => throw StateError('guard failed');
    await navigate(tester, f.controller.goBranch(1));
    expect(f.follow.navigationError, isStateError);
    expect(f.controller.currentIndex, 0);
    expect(find.text('A'), findsOneWidget);
    f.guard = () => GuardResult.redirect(f.detailA.location);
    await navigate(tester, f.controller.goBranch(1));
    expect(f.follow.navigationError, isNull);
    expect(f.controller.currentIndex, 0);
    expect(find.text('A details'), findsOneWidget);
    expect(f.created, ['A']);
  });

  testWidgets('cancelled provisional branch disposes its bindings once',
      (tester) async {
    final a = StaticRouteSpec('/a');
    final b = StaticRouteSpec('/b');
    final gate = Completer<GuardResult>();
    var disposed = 0;
    late FollowShellController controller;
    final root = Feature(
        name: 'root',
        shell: FeatureShell.indexedStack(
          branches: [
            FeatureBranch.mount(a,
                initialLocation: a.location,
                feature: (_) => Feature(name: 'a', routes: [
                      FeatureRoute.page(a, builder: (_, __) => const Text('A')),
                    ])),
            FeatureBranch.mount(b,
                initialLocation: b.location,
                feature: (_) => Feature(
                      name: 'b',
                      bindings: [
                        Bind.value(Token<Object>(), Object(),
                            dispose: (_) => disposed++)
                      ],
                      routes: [
                        FeatureRoute.page(b,
                            guards: [(_, __) => gate.future],
                            builder: (_, __) => const Text('B'))
                      ],
                    )),
          ],
          builder: (_, navigation, child) {
            controller = navigation;
            return child;
          },
        ));
    await tester.pumpWidget(app(root, initialLocation: '/a'));
    await tester.pumpAndSettle();
    final pending = controller.goBranch(1);
    await tester.pumpAndSettle();
    await navigate(tester, controller.goBranch(0));
    await pending;
    expect(disposed, 1);
    gate.complete(const GuardResult.allow());
    await tester.pumpAndSettle();
    expect(disposed, 1);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('parameterized branch identity and query survive navigation',
      (tester) async {
    final user = DataRouteSpec<String>('/users/:id',
        decoder: (data) => data.params['id']!,
        encoder: (id) => (path: {'id': id}, query: const {}));
    final page = DataRouteSpec<({String id, String sort})>('/users/:id',
        decoder: (data) =>
            (id: data.params['id']!, sort: data.query['sort'] ?? 'name'),
        encoder: (args) => (path: {'id': args.id}, query: {'sort': args.sort}));
    final other = StaticRouteSpec('/other');
    final created = <String>[];
    final disposed = <String>[];
    late FollowContext navigation;
    late FollowShellController controller;
    final root = Feature(
        name: 'users',
        shell: FeatureShell.indexedStack(
            branches: [
              FeatureBranch.mount(user,
                  initialLocation: page.location((id: 'a b', sort: 'date')),
                  feature: (id) {
                created.add(id);
                return Feature(
                  name: 'user',
                  bindings: [
                    Bind.value(Token<String>(), id, dispose: disposed.add)
                  ],
                  routes: [
                    FeatureRoute.page(page,
                        builder: (_, args) => Text('${args.id}:${args.sort}'))
                  ],
                );
              }),
              FeatureBranch.mount(other,
                  initialLocation: other.location,
                  feature: (_) => Feature(name: 'other', routes: [
                        FeatureRoute.page(other,
                            builder: (_, __) => const Text('other'))
                      ])),
            ],
            builder: (context, control, child) {
              navigation = context.follow;
              controller = control;
              return child;
            }));
    await tester
        .pumpWidget(app(root, initialLocation: '/users/a%20b?sort=date'));
    await tester.pumpAndSettle();
    expect(find.text('a b:date'), findsOneWidget);
    await navigate(tester, controller.goBranch(1));
    await navigate(tester, controller.goBranch(0));
    expect(find.text('a b:date'), findsOneWidget);
    expect(created, ['a b']);
    await navigate(
        tester, navigation.go(page.location((id: 'new', sort: 'price'))));
    expect(find.text('new:price'), findsOneWidget);
    expect(disposed, ['a b']);
    expect(created, ['a b', 'new']);
  });

  testWidgets('inactive branches lose keyboard focus', (tester) async {
    final f = ShellFixture();
    await tester.pumpWidget(app(f.root, initialLocation: '/tabs/a'));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byKey(const ValueKey('field-A')));
    expect(tester.testTextInput.hasAnyClients, isTrue);
    await navigate(tester, f.controller.goBranch(1));
    expect(tester.testTextInput.hasAnyClients, isFalse);
    await tester.enterText(find.byKey(const ValueKey('field-B')), 'B only');
    await navigate(tester, f.controller.goBranch(0));
    expect(find.text('B only'), findsNothing);
  });
}
