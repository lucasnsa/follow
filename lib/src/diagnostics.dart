part of '../follow.dart';

void _fillFeatureDiagnosticProperties(
  DiagnosticPropertiesBuilder properties,
  _FeatureDefinition definition,
  _FeatureAccess access,
  _FeatureNode? node,
) {
  properties.add(StringProperty('name', definition.feature.name));
  properties.add(StringProperty(
    'state',
    switch (access.state) {
      FeatureInitializing() => 'initializing',
      FeatureReady() => 'ready',
      FeatureFailed() => 'failed',
    },
    quoted: false,
  ));
  properties.add(StringProperty(
    'basePath',
    node?.base ?? '<unrouted>',
    quoted: false,
  ));
  properties.add(StringProperty(
    'mounted',
    (node?.mounted ?? true) ? 'mounted' : 'unmounted',
    quoted: false,
  ));
  final failure = access.state;
  properties.add(DiagnosticsProperty<Object?>(
    'error',
    failure is FeatureFailed ? failure.error : null,
    defaultValue: null,
  ));
  properties.add(IntProperty('bindings', definition.bindings.length));
  properties.add(IterableProperty<String>(
    'bindingDetails',
    definition.bindings.map((declaration) {
      final binding = declaration as Binding<dynamic>;
      final state = _bindingState(
        binding,
        access._entries[binding.token],
      );
      return '${binding.token} (${binding._kind}, $state)';
    }),
  ));
  properties.add(IntProperty('routes', definition.routes.length));
  properties.add(IterableProperty<String>(
    'routeDetails',
    definition.routes.map((route) {
      final kind = route is _MountedFeatureRoute ? 'feature' : 'page';
      return '${route.path} ($kind, ${route.guardCount} guards)';
    }),
  ));
}

String _bindingState(Binding<dynamic> binding, _Entry? entry) {
  if (binding._isFactory) return 'per access';
  if (entry?.failure != null) return 'failed';
  if (entry?.instance != null) return 'ready';
  if (entry?.pending != null) return 'initializing';
  return 'idle';
}

class _FeatureDiagnostics extends DiagnosticableTree {
  const _FeatureDiagnostics(this.definition, this.access, this.node);

  final _FeatureDefinition definition;
  final _FeatureAccess access;
  final _FeatureNode? node;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    _fillFeatureDiagnosticProperties(properties, definition, access, node);
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() => [
        definition.feature.toDiagnosticsNode(name: 'definition'),
        for (final declaration in definition.bindings)
          if (declaration case final Binding<dynamic> binding)
            _BindingDiagnostics(binding, access._entries[binding.token])
                .toDiagnosticsNode(name: binding.token.name),
        for (final route in definition.routes)
          _RouteDiagnostics(route).toDiagnosticsNode(name: route.path),
      ];
}

class _BindingDiagnostics extends DiagnosticableTree {
  const _BindingDiagnostics(this.binding, this.entry);

  final Binding<dynamic> binding;
  final _Entry? entry;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TokenKey>(
      'token',
      binding.token,
    ));
    properties.add(StringProperty('kind', binding._kind, quoted: false));
    properties.add(StringProperty(
      'state',
      _bindingState(binding, entry),
      quoted: false,
    ));
    properties.add(FlagProperty(
      'dispose',
      value: binding.dispose != null,
      ifTrue: 'has dispose callback',
    ));
    properties.add(DiagnosticsProperty<Object?>(
      'failure',
      entry?.failure,
      defaultValue: null,
    ));
  }
}

class _RouteDiagnostics extends DiagnosticableTree {
  const _RouteDiagnostics(this.route);
  final FeatureRoute route;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty(
      'kind',
      route is _MountedFeatureRoute ? 'feature' : 'page',
      quoted: false,
    ));
    properties.add(IntProperty('guards', route.guardCount));
    properties.add(StringProperty(
      'arguments',
      route.spec.runtimeType.toString(),
      quoted: false,
    ));
  }
}
