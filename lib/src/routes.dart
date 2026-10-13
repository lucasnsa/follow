part of '../follow.dart';

typedef FollowRouteBuilder = Widget Function(BuildContext, RouteData);
typedef FollowErrorBuilder = Widget Function(BuildContext, Object, StackTrace);
typedef FeatureBuilder = Widget Function(BuildContext, Widget outlet);
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
  FeatureRoute._(this.spec, List<_FeatureGuard> guards, this.transition)
      : _guards = List.unmodifiable(guards);

  final RouteSpec<Object?> spec;
  final FollowTransition? transition;
  final List<_FeatureGuard> _guards;
  int get guardCount => _guards.length;
  String get path => spec.path;

  Object? decode(RouteData data) => spec.decode(data);

  static FeatureRoute page<A>(
    RouteSpec<A> spec, {
    required Widget Function(BuildContext context, A arguments) builder,
    List<FeatureGuard<A>> guards = const [],
    FollowTransition? transition,
  }) =>
      _PageFeatureRoute<A>(spec, builder, guards, transition);

  static FeatureRoute mount<A>(
    RouteSpec<A> spec, {
    required Feature Function(A arguments) feature,
    List<FeatureGuard<A>> guards = const [],
    FollowTransition? transition,
  }) =>
      _MountedFeatureRoute<A>(spec, feature, guards, transition);
}

typedef _FeatureGuard = FutureOr<GuardResult> Function(Object?, Read);

final class _PageFeatureRoute<A> extends FeatureRoute {
  _PageFeatureRoute(
    RouteSpec<A> spec,
    this.builder,
    List<FeatureGuard<A>> guards, [
    FollowTransition? transition,
  ])  : typedSpec = spec,
        super._(
          spec as RouteSpec<Object?>,
          [
            for (final guard in guards) (value, read) => guard(value as A, read)
          ],
          transition,
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
    List<FeatureGuard<A>> guards, [
    FollowTransition? transition,
  ])  : typedSpec = spec,
        super._(
          spec as RouteSpec<Object?>,
          [
            for (final guard in guards) (value, read) => guard(value as A, read)
          ],
          transition,
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
