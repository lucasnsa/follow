part of '../follow.dart';

/// An immutable declaration of dependencies, routes, and visual shell.
final class Feature extends DiagnosticableTree {
  Feature({
    required this.name,
    Iterable<BindingDeclaration> bindings = const [],
    Iterable<FeatureRoute> routes = const [],
    this.shell,
    Map<String, Object?> diagnostics = const {},
  })  : bindings = List.unmodifiable(bindings),
        routes = List.unmodifiable(routes),
        diagnostics = Map.unmodifiable(diagnostics);

  final String name;
  final List<BindingDeclaration> bindings;
  final List<FeatureRoute> routes;
  final FeatureShell? shell;
  final Map<String, Object?> diagnostics;

  Widget buildShell(BuildContext context, Widget outlet) =>
      shell?.call(context, outlet) ?? outlet;

  DiagnosticsNode get debugDiagnostics => toDiagnosticsNode(name: 'feature');

  @override
  String toStringShort() => 'Feature($name)';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('name', name));
    properties.add(IntProperty('bindings', bindings.length));
    properties.add(IterableProperty<String>(
      'bindingDetails',
      bindings.map((declaration) {
        final binding = declaration as Binding<dynamic>;
        return '${binding.token} (${binding._kind})';
      }),
    ));
    properties.add(IntProperty('routes', routes.length));
    properties.add(IterableProperty<String>(
      'routeDetails',
      routes.map((route) {
        final kind = route is _MountedFeatureRoute ? 'feature' : 'page';
        return '${route.path} ($kind, ${route.guardCount} guards)';
      }),
    ));
    for (final entry in diagnostics.entries) {
      properties.add(DiagnosticsProperty<Object?>(entry.key, entry.value));
    }
  }
}

class _FeatureDefinition {
  _FeatureDefinition(this.feature) {
    final tokens = <TokenKey>{};
    for (final declaration in feature.bindings) {
      final binding = declaration as Binding<dynamic>;
      if (!tokens.add(binding.token)) {
        throw StateError('Duplicate binding: ${binding.token}');
      }
    }
    patterns = _compileRoutes(feature.routes);
  }

  final Feature feature;
  late final List<_RoutePattern> patterns;
  List<BindingDeclaration> get bindings => feature.bindings;
  List<FeatureRoute> get routes => feature.routes;
}
