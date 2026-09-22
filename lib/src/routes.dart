part of '../follow.dart';

typedef FollowRouteBuilder = Widget Function(BuildContext, RouteData);
typedef FollowErrorBuilder = Widget Function(BuildContext, Object, StackTrace);
typedef FeatureShell = Widget Function(BuildContext, Widget outlet);
typedef RouteEncoding = ({
  Map<String, String> path,
  Map<String, String> query,
});
typedef FeatureGuard<A> = FutureOr<GuardResult> Function(
    A arguments, Read read);

/// The requested URI and decoded path parameters.
final class RouteData {
  RouteData(this.uri, [Map<String, String> params = const {}])
      : params = Map.unmodifiable(params);

  final Uri uri;
  final Map<String, String> params;
  Map<String, String> get query => uri.queryParameters;

  static RouteData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RouteStateScope>()?.data ??
      (throw StateError('No Follow route above this context'));
}

/// A validated application location produced by a route specification.
final class RouteLocation {
  RouteLocation._(this.uri);
  final Uri uri;
  @override
  String toString() => uri.toString();
}

/// Typed contract for decoding deep links and encoding navigation arguments.
sealed class RouteSpec<A> {
  RouteSpec(this.path) {
    _validateRoutePath(path);
  }

  final String path;
  A decode(RouteData data);
}

/// A route without arguments.
final class StaticRouteSpec extends RouteSpec<()> {
  StaticRouteSpec(super.path) {
    if (_parameterNames(path).isNotEmpty) {
      throw ArgumentError('Static route cannot contain parameters: $path');
    }
  }

  RouteLocation get location => RouteLocation._(Uri.parse(path));

  @override
  () decode(RouteData data) => ();
}

/// A route whose arguments are represented by [A], commonly a Dart record.
final class DataRouteSpec<A> extends RouteSpec<A> {
  DataRouteSpec(
    super.path, {
    required this.decoder,
    required this.encoder,
  });

  final A Function(RouteData data) decoder;
  final RouteEncoding Function(A arguments) encoder;

  RouteLocation location(A arguments) {
    final encoded = encoder(arguments);
    final expected = _parameterNames(path);
    final supplied = encoded.path.keys.toSet();
    if (expected.length != supplied.length || !expected.containsAll(supplied)) {
      throw ArgumentError(
        'Route $path expects path parameters $expected, received $supplied',
      );
    }
    final segments = _segments(path).map((segment) {
      if (!segment.startsWith(':')) return segment;
      return encoded.path[segment.substring(1)]!;
    });
    final uri = Uri(
      pathSegments: ['', ...segments],
      queryParameters: encoded.query.isEmpty ? null : encoded.query,
    );
    return RouteLocation._(uri);
  }

  @override
  A decode(RouteData data) => decoder(data);
}

/// One page or nested feature in a [Feature] route table.
sealed class FeatureRoute {
  FeatureRoute._(this.spec, List<_FeatureGuard> guards)
      : _guards = List.unmodifiable(guards);

  final RouteSpec<Object?> spec;
  final List<_FeatureGuard> _guards;
  int get guardCount => _guards.length;
  String get path => spec.path;

  Object? decode(RouteData data) => spec.decode(data);

  static FeatureRoute page<A>(
    RouteSpec<A> spec, {
    required Widget Function(BuildContext context, A arguments) builder,
    List<FeatureGuard<A>> guards = const [],
  }) =>
      _PageFeatureRoute<A>(spec, builder, guards);

  static FeatureRoute mount<A>(
    RouteSpec<A> spec, {
    required Feature Function(A arguments) feature,
    List<FeatureGuard<A>> guards = const [],
  }) =>
      _MountedFeatureRoute<A>(spec, feature, guards);
}

typedef _FeatureGuard = FutureOr<GuardResult> Function(Object?, Read);

final class _PageFeatureRoute<A> extends FeatureRoute {
  _PageFeatureRoute(
    RouteSpec<A> spec,
    this.builder,
    List<FeatureGuard<A>> guards,
  )   : typedSpec = spec,
        super._(
          spec as RouteSpec<Object?>,
          [
            for (final guard in guards) (value, read) => guard(value as A, read)
          ],
        );

  final RouteSpec<A> typedSpec;
  final Widget Function(BuildContext, A) builder;

  Widget build(BuildContext context, Object? arguments) =>
      builder(context, arguments as A);
}

final class _MountedFeatureRoute<A> extends FeatureRoute {
  _MountedFeatureRoute(
    RouteSpec<A> spec,
    this.create,
    List<FeatureGuard<A>> guards,
  )   : typedSpec = spec,
        super._(
          spec as RouteSpec<Object?>,
          [
            for (final guard in guards) (value, read) => guard(value as A, read)
          ],
        );

  final RouteSpec<A> typedSpec;
  final Feature Function(A) create;

  Feature feature(Object? arguments) => create(arguments as A);
}

/// A guard allows, denies, or redirects a navigation.
sealed class GuardResult {
  const GuardResult();
  const factory GuardResult.allow() = _Allow;
  const factory GuardResult.deny() = _Deny;
  factory GuardResult.redirect(RouteLocation location) = _Redirect;
}

final class _Allow extends GuardResult {
  const _Allow();
}

final class _Deny extends GuardResult {
  const _Deny();
}

final class _Redirect extends GuardResult {
  const _Redirect(this.location);
  final RouteLocation location;
}

List<String> _segments(String path) => Uri.parse(path)
    .pathSegments
    .where((segment) => segment.isNotEmpty)
    .toList();

Set<String> _parameterNames(String path) => {
      for (final segment in _segments(path))
        if (segment.startsWith(':')) segment.substring(1),
    };

void _validateRoutePath(String path) {
  final uri = Uri.parse(path);
  final segments = _segments(path);
  if (!path.startsWith('/') ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      segments.any((s) => s == '.' || s == '..' || s.contains('*'))) {
    throw ArgumentError('Invalid absolute route path: $path');
  }
  final parameters = <String>{};
  for (final segment in segments.where((s) => s.startsWith(':'))) {
    if (segment.length == 1 || !parameters.add(segment.substring(1))) {
      throw ArgumentError('Invalid parameter in $path');
    }
  }
}

void _validateRoutes(List<FeatureRoute> routes) {
  final shapes = <String>{};
  for (final route in routes) {
    _validateRoutePath(route.path);
    final shape = _segments(route.path)
        .map((segment) => segment.startsWith(':') ? ':' : segment)
        .join('/');
    if (!shapes.add(shape)) {
      throw ArgumentError('Ambiguous sibling routes: ${route.path}');
    }
  }
  for (final candidate in routes) {
    if (candidate is! _MountedFeatureRoute) continue;
    final mounted = candidate;
    final prefix = _segments(mounted.path);
    for (final other in routes) {
      if (identical(mounted, other)) continue;
      final parts = _segments(other.path);
      if (parts.length > prefix.length &&
          List.generate(
            prefix.length,
            (index) =>
                (prefix[index].startsWith(':') &&
                    parts[index].startsWith(':')) ||
                prefix[index] == parts[index],
          ).every((value) => value)) {
        throw ArgumentError(
          'Route ${other.path} overlaps feature ${mounted.path}',
        );
      }
    }
  }
}

class _Match {
  _Match(this.route, this.count, this.params, this.specificity);
  final FeatureRoute route;
  final int count;
  final Map<String, String> params;
  final String specificity;
}

_Match? _match(_FeatureNode node, List<String> remaining) {
  final matches = <_Match>[];
  final baseSegments = _segments(node.base);
  for (final route in node.routes) {
    final absolute = _segments(route.path);
    if (absolute.length < baseSegments.length ||
        !List.generate(
          baseSegments.length,
          (index) =>
              absolute[index] == baseSegments[index] ||
              absolute[index].startsWith(':'),
        ).every((value) => value)) {
      continue;
    }
    final segments = absolute.sublist(baseSegments.length);
    if (segments.length > remaining.length ||
        (route is _PageFeatureRoute && segments.length != remaining.length)) {
      continue;
    }
    final params = <String, String>{};
    var valid = true;
    var specificity = '';
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      if (segment.startsWith(':')) {
        params[segment.substring(1)] = remaining[index];
        specificity += '0';
      } else {
        if (segment != remaining[index]) {
          valid = false;
          break;
        }
        specificity += '1';
      }
    }
    if (valid) matches.add(_Match(route, segments.length, params, specificity));
  }
  matches.sort((a, b) => b.specificity.compareTo(a.specificity));
  return matches.firstOrNull;
}
