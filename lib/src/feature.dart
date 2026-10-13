part of '../follow.dart';

/// An immutable declaration of dependencies, navigation, and widget composition.
final class Feature extends DiagnosticableTree {
  Feature({
    required this.name,
    Iterable<BindingDeclaration> bindings = const [],
    Iterable<FeatureRoute> routes = const [],
    this.builder,
    this.shell,
    this.pageTransition,
    Map<String, Object?> diagnostics = const {},
  })  : bindings = List.unmodifiable(bindings),
        routes = List.unmodifiable(routes),
        diagnostics = Map.unmodifiable(diagnostics) {
    if (shell != null && this.routes.isNotEmpty) {
      throw ArgumentError('A Feature accepts either routes or shell');
    }
  }

  final String name;
  final List<BindingDeclaration> bindings;
  final List<FeatureRoute> routes;
  final FeatureBuilder? builder;
  final FeatureShell? shell;

  /// Default page motion for this feature and descendants. Null inherits.
  final FollowTransition? pageTransition;
  final Map<String, Object?> diagnostics;

  Widget buildContent(BuildContext context, Widget outlet) =>
      builder?.call(context, outlet) ?? outlet;

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
    properties.add(IntProperty('branches', shell?.branches.length ?? 0));
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
    patterns = _compileRoutes(routes);
  }

  final Feature feature;
  late final List<_RoutePattern> patterns;
  List<BindingDeclaration> get bindings => feature.bindings;
  late final List<FeatureRoute> routes = List.unmodifiable(
      feature.shell?.branches.map((b) => b._route) ?? feature.routes);
}
