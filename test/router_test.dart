import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/follow.dart';

final counterToken = Token<int>('counter');
final signedInToken = Token<ValueGetter<bool>>('signed-in');
final textToken = Token<String>('text');

Feature feature({
  String name = 'test',
  List<BindingDeclaration> bindings = const [],
  List<FeatureRoute> routes = const [],
  FeatureBuilder? builder,
}) =>
    Feature(name: name, bindings: bindings, routes: routes, builder: builder);

DataRouteSpec<String> parameterRoute(String path, String parameter) =>
    DataRouteSpec<String>(
      path,
      decoder: (data) => data.params[parameter]!,
      encoder: (value) => (path: {parameter: value}, query: const {}),
    );

Widget app(
  Feature feature, {
  String? initialLocation,
  RouteInformationProvider? provider,
  FollowRouteBuilder? notFoundBuilder,
  FollowRouteBuilder? deniedBuilder,
  FollowErrorBuilder? errorBuilder,
}) =>
    FollowApp(
      feature: feature,
      initialLocation: initialLocation,
      routeInformationProvider: provider,
      notFoundBuilder: notFoundBuilder,
      deniedBuilder: deniedBuilder,
      errorBuilder: errorBuilder,
      builder: (_, config) => MaterialApp.router(routerConfig: config),
    );

Future<void> navigate(WidgetTester tester, Future<void> operation) async {
  await tester.pumpAndSettle();
  await operation;
  await tester.pumpAndSettle();
}

void main() {
  test('route specs encode records and reject incomplete path maps', () {
    final route = DataRouteSpec<({String id, String? sort})>(
      '/items/:id',
      decoder: (data) => (
        id: data.params['id']!,
        sort: data.query['sort'],
      ),
      encoder: (arguments) => (
        path: {'id': arguments.id},
        query: arguments.sort == null ? const {} : {'sort': arguments.sort!},
      ),
    );
    expect(
      route.location((id: 'a b', sort: 'new')).uri.toString(),
      '/items/a%20b?sort=new',
    );
    final invalid = DataRouteSpec<String>(
      '/items/:id',
      decoder: (_) => '',
      encoder: (_) => (path: const {}, query: const {}),
    );
    expect(() => invalid.location('x'), throwsArgumentError);
  });

  testWidgets('typed push replace go and pop update the root router',
      (tester) async {
    late FollowContext navigation;
    final home = StaticRouteSpec('/');
    final a = DataRouteSpec<String?>(
      '/a',
      decoder: (data) => data.query['x'],
      encoder: (value) => (
        path: const {},
        query: value == null ? const {} : {'x': value},
      ),
    );
    final b = StaticRouteSpec('/b');
    final root = feature(
      routes: [
        FeatureRoute.page(home, builder: (_, __) => const Text('home')),
        FeatureRoute.page(a, builder: (_, __) => const Text('A')),
        FeatureRoute.page(b, builder: (_, __) => const Text('B')),
      ],
      builder: (context, outlet) {
        navigation = context.follow;
        return outlet;
      },
    );
    await tester.pumpWidget(app(root));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    await navigate(tester, navigation.push(a.location('1')));
    expect(find.text('A'), findsOneWidget);
    expect(navigation.currentUri.toString(), '/a?x=1');
    await navigate(tester, navigation.replace(b.location));
    expect(find.text('B'), findsOneWidget);
    expect(await navigation.pop(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    await navigate(tester, navigation.go(a.location(null)));
    expect(await navigation.pop(), isFalse);
  });

  testWidgets('deep link mounts feature chain, builder and scoped dependencies',
      (tester) async {
    var creations = 0;
    var disposals = 0;
    var shellBuilds = 0;
    late FollowContext productContext;
    final home = StaticRouteSpec('/');
    final productsRoot = StaticRouteSpec('/products');
    final product = DataRouteSpec<({String id, String? sort})>(
      '/products/:id',
      decoder: (data) => (id: data.params['id']!, sort: data.query['sort']),
      encoder: (args) => (
        path: {'id': args.id},
        query: args.sort == null ? const {} : {'sort': args.sort!},
      ),
    );
    final products = feature(
      name: 'products',
      bindings: [
        Bind.singleton(counterToken, (_) => ++creations,
            dispose: (_) => disposals++),
      ],
      routes: [
        FeatureRoute.page(
          productsRoot,
          builder: (_, __) => const Text('products'),
        ),
        FeatureRoute.page(product, builder: (context, args) {
          productContext = context.follow;
          return Text('${args.id}:${args.sort}');
        }),
      ],
      builder: (_, outlet) {
        shellBuilds++;
        return Column(children: [
          const Text('products builder'),
          Expanded(child: outlet),
        ]);
      },
    );
    final root = feature(routes: [
      FeatureRoute.page(home, builder: (_, __) => const Text('home')),
      FeatureRoute.mount(productsRoot, feature: (_) => products),
    ]);

    await tester
        .pumpWidget(app(root, initialLocation: '/products/42?sort=new'));
    await tester.pumpAndSettle();
    expect(find.text('42:new'), findsOneWidget);
    expect(find.text('products builder'), findsOneWidget);
    expect(creations, 1);
    expect(shellBuilds, 1);
    final first = productContext.read(counterToken);
    await navigate(
      tester,
      productContext.push(product.location((id: '43', sort: null))),
    );
    expect(productContext.read(counterToken), first);
    await navigate(tester, productContext.go(home.location));
    expect(disposals, 1);
  });

  testWidgets('nested features navigate through absolute typed specs',
      (tester) async {
    late FollowContext orderNavigation;
    var shopShellBuilds = 0;
    final shopRoot = StaticRouteSpec('/shop');
    final ordersRoot = StaticRouteSpec('/shop/orders');
    final order = parameterRoute('/shop/orders/:id', 'id');
    final orders = feature(routes: [
      FeatureRoute.page(order, builder: (context, id) {
        orderNavigation = context.follow;
        return Text('order $id');
      }),
    ]);
    final shop = feature(
      routes: [FeatureRoute.mount(ordersRoot, feature: (_) => orders)],
      builder: (_, outlet) {
        shopShellBuilds++;
        return Column(children: [
          const Text('shop builder'),
          Expanded(child: outlet),
        ]);
      },
    );
    final root = feature(routes: [
      FeatureRoute.mount(shopRoot, feature: (_) => shop),
    ]);
    await tester.pumpWidget(app(root, initialLocation: '/shop/orders/1'));
    await tester.pumpAndSettle();
    expect(find.text('order 1'), findsOneWidget);
    await navigate(tester, orderNavigation.push(order.location('2')));
    expect(find.text('order 2'), findsOneWidget);
    expect(orderNavigation.currentUri.toString(), '/shop/orders/2');
    expect(shopShellBuilds, 1);
    expect(await orderNavigation.pop(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('order 1'), findsOneWidget);
  });

  testWidgets('parent guards redirect before creating a child feature',
      (tester) async {
    var signedIn = false;
    var childMounts = 0;
    late FollowContext loginNavigation;
    final home = StaticRouteSpec('/');
    final login = StaticRouteSpec('/login');
    final gated = StaticRouteSpec('/feature');
    final child = feature(routes: [
      FeatureRoute.page(gated, builder: (_, __) => const Text('feature')),
    ]);
    final root = feature(
      bindings: [Bind.value(signedInToken, () => signedIn)],
      routes: [
        FeatureRoute.page(home, builder: (_, __) => const Text('home')),
        FeatureRoute.page(login, builder: (context, __) {
          loginNavigation = context.follow;
          return const Text('login');
        }),
        FeatureRoute.mount(
          gated,
          guards: [
            (_, read) => read(signedInToken)()
                ? const GuardResult.allow()
                : GuardResult.redirect(login.location),
          ],
          feature: (_) {
            childMounts++;
            return child;
          },
        ),
      ],
    );
    await tester.pumpWidget(app(root, initialLocation: '/feature'));
    await tester.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);
    expect(childMounts, 0);
    signedIn = true;
    await navigate(tester, loginNavigation.go(gated.location));
    expect(find.text('feature'), findsOneWidget);
    expect(childMounts, 1);
  });

  testWidgets('child guards can await local DI without full readiness',
      (tester) async {
    final used = Completer<int>();
    final unused = Completer<String>();
    final childRoot = StaticRouteSpec('/feature');
    final child = feature(
      bindings: [
        Bind.async(counterToken, (_) => used.future),
        Bind.async(textToken, (_) => unused.future),
      ],
      routes: [
        FeatureRoute.page(
          childRoot,
          guards: [
            (_, read) async {
              expect(await read.async(counterToken), 5);
              return const GuardResult.allow();
            },
          ],
          builder: (_, __) => const Text('ready enough'),
        ),
      ],
    );
    final root = feature(routes: [
      FeatureRoute.mount(childRoot, feature: (_) => child),
    ]);
    await tester.pumpWidget(app(root, initialLocation: '/feature'));
    await tester.pump();
    expect(find.text('Loading…'), findsOneWidget);
    used.complete(5);
    await tester.pumpAndSettle();
    expect(find.text('ready enough'), findsOneWidget);
    unused.complete('unused');
    await tester.pumpAndSettle();
  });

  testWidgets('denied and guard errors preserve the current page',
      (tester) async {
    late FollowContext navigation;
    final home = StaticRouteSpec('/');
    final denied = StaticRouteSpec('/denied');
    final error = StaticRouteSpec('/error');
    final root = feature(routes: [
      FeatureRoute.page(home, builder: (context, __) {
        navigation = context.follow;
        return const Text('home');
      }),
      FeatureRoute.page(
        denied,
        guards: [(_, __) => const GuardResult.deny()],
        builder: (_, __) => const Text('denied'),
      ),
      FeatureRoute.page(
        error,
        guards: [(_, __) => throw StateError('guard failed')],
        builder: (_, __) => const Text('error'),
      ),
    ]);
    await tester.pumpWidget(app(root));
    await tester.pumpAndSettle();
    await navigate(tester, navigation.push(denied.location));
    expect(find.text('home'), findsOneWidget);
    await navigate(tester, navigation.push(error.location));
    expect(find.text('home'), findsOneWidget);
    expect(navigation.navigationError.toString(), contains('guard failed'));
  });

  testWidgets('initial denied, errors and unknown paths use custom builders',
      (tester) async {
    final target = StaticRouteSpec('/target');
    Feature rootFor(FeatureGuard<()> guard) => feature(routes: [
          FeatureRoute.page(
            target,
            guards: [guard],
            builder: (_, __) => const Text('target'),
          ),
        ]);
    await tester.pumpWidget(app(
      rootFor((_, __) => const GuardResult.deny()),
      initialLocation: '/target',
      deniedBuilder: (_, __) => const Text('custom denied'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('custom denied'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(app(
      rootFor((_, __) => throw StateError('boom')),
      initialLocation: '/target',
      errorBuilder: (_, error, __) => Text('custom $error'),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('custom Bad state: boom'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final home = StaticRouteSpec('/');
    await tester.pumpWidget(app(
      feature(routes: [
        FeatureRoute.page(home, builder: (_, __) => const Text('home')),
      ]),
      initialLocation: '/missing',
      notFoundBuilder: (_, data) => Text('missing ${data.uri.path}'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('missing /missing'), findsOneWidget);
  });

  testWidgets('literal routes beat typed parameters and expose route data',
      (tester) async {
    final literal = StaticRouteSpec('/items/new');
    final item = parameterRoute('/items/:id', 'id');
    final root = feature(routes: [
      FeatureRoute.page(literal, builder: (_, __) => const Text('literal')),
      FeatureRoute.page(item, builder: (context, id) {
        expect(context.follow.route.params['id'], id);
        return Text('item $id');
      }),
    ]);
    await tester.pumpWidget(app(root, initialLocation: '/items/new'));
    await tester.pumpAndSettle();
    expect(find.text('literal'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(app(root, initialLocation: '/items/a%20b'));
    await tester.pumpAndSettle();
    expect(find.text('item a b'), findsOneWidget);
  });

  testWidgets('covered feature entries keep separate scoped instances',
      (tester) async {
    var created = 0;
    final disposed = <int>[];
    late FollowContext navigation;
    final home = StaticRouteSpec('/');
    final other = StaticRouteSpec('/other');
    final childRoot = StaticRouteSpec('/feature');
    final child = feature(
      bindings: [
        Bind.singleton(counterToken, (_) => ++created, dispose: disposed.add),
      ],
      routes: [
        FeatureRoute.page(
          childRoot,
          builder: (context, __) =>
              Text('instance ${context.follow.read(counterToken)}'),
        ),
      ],
    );
    final root = feature(
      routes: [
        FeatureRoute.page(home, builder: (_, __) => const Text('home')),
        FeatureRoute.page(other, builder: (_, __) => const Text('other')),
        FeatureRoute.mount(childRoot, feature: (_) => child),
      ],
      builder: (context, outlet) {
        navigation = context.follow;
        return outlet;
      },
    );
    await tester.pumpWidget(app(root));
    await tester.pumpAndSettle();
    await navigate(tester, navigation.push(childRoot.location));
    expect(find.text('instance 1'), findsOneWidget);
    await navigate(tester, navigation.push(other.location));
    await navigate(tester, navigation.push(childRoot.location));
    expect(find.text('instance 2'), findsOneWidget);
    expect(disposed, isEmpty);
    await navigation.pop();
    await tester.pumpAndSettle();
    expect(disposed, [2]);
    await navigation.pop();
    await tester.pumpAndSettle();
    expect(find.text('instance 1'), findsOneWidget);
  });

  testWidgets('external route provider drives an isolated router',
      (tester) async {
    final provider = MemoryRouteInformationProvider('/a');
    addTearDown(provider.dispose);
    final a = StaticRouteSpec('/a');
    final b = StaticRouteSpec('/b');
    final root = feature(routes: [
      FeatureRoute.page(a, builder: (_, __) => const Text('A')),
      FeatureRoute.page(b, builder: (_, __) => const Text('B')),
    ]);
    await tester.pumpWidget(app(root, provider: provider));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    provider.open('/b');
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('history restores nested stacks and feature identity',
      (tester) async {
    final provider = MemoryRouteInformationProvider('/');
    addTearDown(provider.dispose);
    var created = 0;
    late FollowContext navigation;
    final home = StaticRouteSpec('/');
    final childRoot = StaticRouteSpec('/feature');
    final item = parameterRoute('/feature/:id', 'id');
    final child = feature(
      bindings: [Bind.singleton(counterToken, (_) => ++created)],
      routes: [
        FeatureRoute.page(item, builder: (context, id) {
          return Text('$id:${context.follow.read(counterToken)}');
        }),
      ],
    );
    final root = feature(
      routes: [
        FeatureRoute.page(home, builder: (_, __) => const Text('home')),
        FeatureRoute.mount(childRoot, feature: (_) => child),
      ],
      builder: (context, outlet) {
        navigation = context.follow;
        return outlet;
      },
    );
    await tester.pumpWidget(app(root, provider: provider));
    await tester.pumpAndSettle();
    await navigate(tester, navigation.push(item.location('1')));
    final back = provider.value;
    await navigate(tester, navigation.push(item.location('2')));
    final forward = provider.value;
    provider.restore(back);
    await tester.pumpAndSettle();
    expect(find.text('1:1'), findsOneWidget);
    provider.restore(forward);
    await tester.pumpAndSettle();
    expect(find.text('2:1'), findsOneWidget);
    expect(created, 1);
  });

  testWidgets('new navigation cancels and disposes provisional feature',
      (tester) async {
    final decision = Completer<GuardResult>();
    var disposed = 0;
    late FollowContext navigation;
    final home = StaticRouteSpec('/');
    final fast = StaticRouteSpec('/fast');
    final slowRoot = StaticRouteSpec('/slow');
    final slow = feature(
      bindings: [
        Bind.value(counterToken, 1, dispose: (_) => disposed++),
      ],
      routes: [
        FeatureRoute.page(
          slowRoot,
          guards: [(_, __) => decision.future],
          builder: (_, __) => const Text('slow'),
        ),
      ],
    );
    final root = feature(
      routes: [
        FeatureRoute.page(home, builder: (_, __) => const Text('home')),
        FeatureRoute.page(fast, builder: (_, __) => const Text('fast')),
        FeatureRoute.mount(slowRoot, feature: (_) => slow),
      ],
      builder: (context, outlet) {
        navigation = context.follow;
        return outlet;
      },
    );
    await tester.pumpWidget(app(root));
    await tester.pumpAndSettle();
    final old = navigation.push(slowRoot.location);
    await tester.pump();
    await navigate(tester, navigation.go(fast.location));
    await old;
    expect(find.text('fast'), findsOneWidget);
    expect(disposed, 1);
    decision.completeError(StateError('late failure'));
    await tester.pumpAndSettle();
    expect(navigation.navigationError, isNull);
  });

  testWidgets('redirect loops become observable navigation errors',
      (tester) async {
    late FollowContext navigation;
    final home = StaticRouteSpec('/');
    final loop = StaticRouteSpec('/loop');
    final root = feature(
      routes: [
        FeatureRoute.page(home, builder: (_, __) => const Text('home')),
        FeatureRoute.page(
          loop,
          guards: [(_, __) => GuardResult.redirect(loop.location)],
          builder: (_, __) => const Text('loop'),
        ),
      ],
      builder: (context, outlet) {
        navigation = context.follow;
        return outlet;
      },
    );
    await tester.pumpWidget(app(root));
    await tester.pumpAndSettle();
    await navigate(tester, navigation.push(loop.location));
    expect(navigation.navigationError.toString(), contains('Redirect loop'));
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('invalid feature declarations fail instead of hanging',
      (tester) async {
    final first = parameterRoute('/:a', 'a');
    final second = parameterRoute('/:b', 'b');
    final duplicate = feature(routes: [
      FeatureRoute.page(first, builder: (_, __) => const Text('A')),
      FeatureRoute.page(second, builder: (_, __) => const Text('B')),
    ]);
    await tester.pumpWidget(app(duplicate));
    expect(tester.takeException().toString(), contains('Ambiguous sibling'));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final brokenRoot = StaticRouteSpec('/broken');
    final outside = StaticRouteSpec('/outside');
    final misplaced = feature(routes: [
      FeatureRoute.page(outside, builder: (_, __) => const Text('outside')),
    ]);
    await tester.pumpWidget(app(
      feature(routes: [
        FeatureRoute.mount(brokenRoot, feature: (_) => misplaced),
      ]),
      initialLocation: '/broken',
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('outside feature base /broken'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final withoutOutlet = feature(
      routes: [
        FeatureRoute.page(
          brokenRoot,
          builder: (_, __) => const Text('never'),
        ),
      ],
      builder: (_, __) => const SizedBox(),
    );
    final root = feature(routes: [
      FeatureRoute.mount(brokenRoot, feature: (_) => withoutOutlet),
    ]);
    await tester.pumpWidget(app(root, initialLocation: '/broken'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Navigation failed'), findsOneWidget);
  });
}

class MemoryRouteInformationProvider extends RouteInformationProvider
    with ChangeNotifier {
  MemoryRouteInformationProvider(String location)
      : _value = RouteInformation(uri: Uri.parse(location));

  RouteInformation _value;

  @override
  RouteInformation get value => _value;

  void open(String location) {
    _value = RouteInformation(uri: Uri.parse(location));
    notifyListeners();
  }

  void restore(RouteInformation information) {
    _value = information;
    notifyListeners();
  }

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    _value = routeInformation;
  }
}
