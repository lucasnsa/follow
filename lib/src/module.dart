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
    _validateRoutes(feature.routes);
  }

  final Feature feature;
  List<BindingDeclaration> get bindings => feature.bindings;
  List<FeatureRoute> get routes => feature.routes;
}

/// Mounts a dependency feature in an arbitrary, non-routed subtree.
///
/// Features containing routes must be mounted by [FollowApp] or another
/// [FeatureRoute.mount].
class FeatureScope extends StatelessWidget {
  const FeatureScope({required this.feature, required this.child, super.key});

  final Feature feature;
  final Widget child;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Feature>('feature', feature));
  }

  @override
  Widget build(BuildContext context) => _FeatureHost(
        feature: feature,
        scopeChild: child,
      );
}

class _FeatureHost extends StatefulWidget {
  const _FeatureHost({
    required this.feature,
    this.router,
    this.contentBuilder,
    this.scopeChild,
    this.routed = false,
  });

  final Feature feature;
  final _FollowRouter? router;
  final WidgetBuilder? contentBuilder;
  final Widget? scopeChild;
  final bool routed;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Feature>('feature', feature));
    properties.add(FlagProperty('routed', value: routed, ifTrue: 'routed'));
  }

  @override
  State<_FeatureHost> createState() => _FeatureHostState();
}

class _FeatureHostState extends State<_FeatureHost> {
  late final _FeatureDefinition definition = _FeatureDefinition(widget.feature);
  late _FeatureAccess access;
  _FeatureAccess? parent;
  bool initialized = false;
  int generation = 0;
  _FeatureNode? routeNode;
  bool failedMount = false;
  Widget? routedShell;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next =
        context.dependOnInheritedWidgetOfExactType<_FeatureScope>()?.notifier;
    if (!initialized || !identical(parent, next)) {
      if (failedMount) return;
      if (routeNode != null) routeNode!.router._detach(routeNode!);
      if (initialized) access.dispose();
      parent = next;
      final mount = context.getInheritedWidgetOfExactType<_RouteMount>()?.entry;
      final parentNode =
          context.getInheritedWidgetOfExactType<_NodeScope>()?.node;
      final ownsMount = mount != null &&
          mount.route is _MountedFeatureRoute &&
          parentNode == mount.owner;
      final controller =
          widget.router ?? (ownsMount ? mount.owner.router : null);
      routeNode = null;
      try {
        if (widget.routed && !ownsMount) {
          throw StateError('A routed Feature must be mounted by FeatureRoute');
        }
        if (!widget.routed &&
            widget.router == null &&
            definition.routes.isNotEmpty) {
          throw StateError(
            'FeatureScope only accepts features without routes; '
            'use FollowApp or FeatureRoute.mount',
          );
        }
        access = _FeatureAccess(definition.bindings, parent);
        initialized = true;
        generation++;
        if (controller != null) {
          routeNode = _FeatureNode(
            controller,
            access,
            definition,
            mount: ownsMount ? mount : null,
          );
          controller._attach(routeNode!);
        }
      } catch (error, stack) {
        if (ownsMount) {
          if (!mount.attached.isCompleted) {
            mount.attached.completeError(error, stack);
          }
          failedMount = true;
        } else {
          rethrow;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (failedMount) return const SizedBox.shrink();
    Widget child;
    if (widget.routed) {
      child = routedShell ??= Builder(
        builder: (context) =>
            definition.feature.buildShell(context, const _FeatureOutlet()),
      );
    } else if (widget.scopeChild != null) {
      child = Builder(
        builder: (context) =>
            definition.feature.buildShell(context, widget.scopeChild!),
      );
    } else {
      child = Builder(builder: widget.contentBuilder!);
    }
    if (routeNode != null) {
      child = _RouterScope(
        notifier: routeNode!.router,
        child: _NodeScope(node: routeNode, child: child),
      );
    }
    return _FeatureScope(
      key: ValueKey(generation),
      notifier: access,
      definition: definition,
      node: routeNode,
      child: child,
    );
  }

  @override
  void deactivate() {
    routeNode?.mounted = false;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    routeNode?.mounted = true;
  }

  @override
  void dispose() {
    if (routeNode != null) routeNode!.router._detach(routeNode!);
    if (initialized) access.dispose();
    super.dispose();
  }
}

class _FeatureScope extends InheritedNotifier<_FeatureAccess> {
  const _FeatureScope({
    required super.notifier,
    required this.definition,
    required this.node,
    required super.child,
    super.key,
  });

  final _FeatureDefinition definition;
  final _FeatureNode? node;

  @override
  String toStringShort() => 'FollowFeatureScope<${definition.feature.name}>';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Feature>(
      'feature',
      definition.feature,
    ));
    _fillFeatureDiagnosticProperties(properties, definition, notifier!, node);
  }
}
