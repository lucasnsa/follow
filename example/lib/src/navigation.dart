import 'package:follow/follow.dart';

final homeRoute = StaticRouteSpec('/');
final exploreRoute = StaticRouteSpec('/explore');
final deniedDemoRoute = StaticRouteSpec('/demo/denied');
final errorDemoRoute = StaticRouteSpec('/demo/error');
final missingDemoRoute = StaticRouteSpec('/rota-que-nao-existe');

final loginRoute = DataRouteSpec<String>(
  '/login',
  decoder: (data) => data.query['next'] ?? '/products',
  encoder: (next) => (path: const {}, query: {'next': next}),
);

final productsMountRoute = StaticRouteSpec('/products');

final productsListRoute = DataRouteSpec<String?>(
  '/products',
  decoder: (data) => data.query['sort'],
  encoder: (sort) => (
    path: const {},
    query: sort == null ? const {} : {'sort': sort},
  ),
);

final productDetailsRoute = DataRouteSpec<({String id, String? sort})>(
  '/products/:id',
  decoder: (data) => (
    id: data.params['id']!,
    sort: data.query['sort'],
  ),
  encoder: (arguments) => (
    path: {'id': arguments.id},
    query: arguments.sort == null ? const {} : {'sort': arguments.sort!},
  ),
);

final previewRoute = StaticRouteSpec('/preview');
