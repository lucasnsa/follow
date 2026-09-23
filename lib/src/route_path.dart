part of '../follow.dart';

Uri _uri(String location, String base) {
  final value = Uri.parse(location);
  if (value.hasScheme || value.hasAuthority) {
    throw ArgumentError('Expected an application path: $location');
  }
  final prefix = base.endsWith('/') ? base : '$base/';
  final resolved = Uri.parse(prefix).resolveUri(value).normalizePath();
  final path =
      '/${_segments(resolved.path).map(Uri.encodeComponent).join('/')}';
  return resolved.replace(path: path);
}

List<String> _segments(String path) => Uri.parse(path)
    .pathSegments
    .where((segment) => segment.isNotEmpty)
    .toList();

Set<String> _parameterNames(String path) => {
      for (final segment in _segments(path))
        if (segment.startsWith(':')) segment.substring(1),
    };

void _validateRoutePath(String path, [List<String>? parsedSegments]) {
  final uri = Uri.parse(path);
  final segments = parsedSegments ?? _segments(path);
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
