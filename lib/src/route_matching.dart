part of '../follow.dart';

/// Immutable route metadata owned by a mounted feature definition.
class _RoutePattern {
  _RoutePattern(this.route, this.segments)
      : parameters = [
          for (final segment in segments)
            segment.startsWith(':') ? segment.substring(1) : null,
        ],
        specificity = [
          for (final segment in segments) segment.startsWith(':') ? '0' : '1',
        ].join();

  final FeatureRoute route;
  final List<String> segments;
  final List<String?> parameters;
  final String specificity;

  _RoutePattern relativeTo(int offset) =>
      offset == 0 ? this : _RoutePattern(route, segments.sublist(offset));

  bool matches(List<String> requested, int offset) {
    final remaining = requested.length - offset;
    if (segments.length > remaining ||
        (route is _PageFeatureRoute && segments.length != remaining)) {
      return false;
    }
    for (var i = 0; i < segments.length; i++) {
      if (parameters[i] == null && segments[i] != requested[offset + i]) {
        return false;
      }
    }
    return true;
  }

  _Match match(List<String> requested, int offset) => _Match(
        route,
        segments.length,
        {
          for (var i = 0; i < parameters.length; i++)
            if (parameters[i] case final String name)
              name: requested[offset + i],
        },
      );
}

/// With a concrete base, a parameter in the declaration matches any segment.
/// Between declarations, only corresponding parameters are equivalent.
bool _hasRoutePrefix(List<String> parts, List<String> prefix,
    {bool concreteBase = false}) {
  if (parts.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (parts[i] != prefix[i] &&
        !(parts[i].startsWith(':') &&
            (concreteBase || prefix[i].startsWith(':')))) {
      return false;
    }
  }
  return true;
}

List<_RoutePattern> _compileRoutes(List<FeatureRoute> routes) {
  final patterns = <_RoutePattern>[];
  final shapes = <String>{};
  for (final route in routes) {
    final segments = _segments(route.path);
    _validateRoutePath(route.path, segments);
    final pattern = _RoutePattern(route, segments);
    patterns.add(pattern);
    final shape = [
      for (var i = 0; i < segments.length; i++)
        pattern.parameters[i] == null ? segments[i] : ':',
    ].join('/');
    if (!shapes.add(shape)) {
      throw ArgumentError('Ambiguous sibling routes: ${route.path}');
    }
  }
  for (final mounted in patterns) {
    if (mounted.route is! _MountedFeatureRoute) continue;
    for (final other in patterns) {
      if (identical(mounted, other)) continue;
      if (other.segments.length > mounted.segments.length &&
          _hasRoutePrefix(other.segments, mounted.segments)) {
        throw ArgumentError(
          'Route ${other.route.path} overlaps feature ${mounted.route.path}',
        );
      }
    }
  }
  return patterns;
}

class _Match {
  _Match(this.route, this.count, this.params);
  final FeatureRoute route;
  final int count;
  final Map<String, String> params;
}

_Match? _match(_FeatureNode node, List<String> segments, int offset) {
  _RoutePattern? best;
  var tied = false;
  for (final pattern in node.patterns) {
    if (!pattern.matches(segments, offset)) continue;
    final comparison =
        best == null ? 1 : pattern.specificity.compareTo(best.specificity);
    if (comparison > 0) {
      best = pattern;
      tied = false;
    } else if (comparison == 0) {
      tied = true;
    }
  }
  if (tied) {
    // List.sort is not stable. Preserve the old winner even for large tied
    // tables, including lower-ranked matches that influence that ordering.
    final matches = [
      for (final pattern in node.patterns)
        if (pattern.matches(segments, offset)) pattern,
    ]..sort((a, b) => b.specificity.compareTo(a.specificity));
    best = matches.first;
  }
  return best?.match(segments, offset);
}
