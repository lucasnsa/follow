part of '../follow.dart';

class _FeatureNode {
  _FeatureNode(this.router, this.access, this.definition, {_RouteEntry? mount})
      : entry = mount,
        routes = definition.routes {
    final prefix = _segments(base);
    for (final pattern in definition.patterns) {
      final route = pattern.route;
      final parts = pattern.segments;
      final belongsToFeature =
          _hasRoutePrefix(parts, prefix, concreteBase: true);
      if (!belongsToFeature) {
        throw StateError(
          'Route ${route.path} is outside feature base $base',
        );
      }
      if (route is _MountedFeatureRoute && parts.length == prefix.length) {
        throw StateError(
          'Mounted feature route ${route.path} must advance beyond $base',
        );
      }
    }
    patterns = [
      for (final pattern in definition.patterns)
        pattern.relativeTo(prefix.length),
    ];
  }
  late final List<_RoutePattern> patterns;
  final _FollowRouter router;
  final _FeatureAccess access;
  final _FeatureDefinition definition;
  final List<FeatureRoute> routes;
  final _RouteEntry? entry;
  final navigatorKey = GlobalKey<NavigatorState>();
  final presented = Completer<void>();
  final List<_RouteEntry> staging = [];
  List<_RouteEntry> pages = [];
  BuildContext? context;
  _FeatureOutletState? outlet;
  Widget? content;
  late final FollowShellController shellController =
      FollowShellController._(this);
  late int activeIndex = definition.feature.shell?.initialIndex ?? 0;
  _ShellBranchesState? shellOutlet;
  bool get isShell => definition.feature.shell != null;
  int branchIndex(_RouteEntry entry) =>
      entry.route == null ? -1 : definition.routes.indexOf(entry.route!);
  _RouteEntry? get activeEntry => pages.lastOrNull?.fallback != null
      ? pages.last
      : isShell
          ? pages
              .where((entry) => branchIndex(entry) == activeIndex)
              .firstOrNull
          : pages.lastOrNull;
  int? previousTopId;
  bool animatePages = false;
  bool animateBranches = false;
  int presentationSerial = 0;
  FollowTransition get pageTransition =>
      definition.feature.pageTransition ??
      entry?.owner.pageTransition ??
      router.pageTransition;
  bool mounted = true;
  String get base => entry?.base ?? '/';
}

class _RouteEntry {
  _RouteEntry(
    this.id,
    this.owner,
    this.route,
    this.data,
    this.arguments,
    this.base, {
    this.fallback,
  });
  final int id;
  final _FeatureNode owner;
  final FeatureRoute? route;
  RouteData data;
  Object? arguments;
  final String base;
  final WidgetBuilder? fallback;
  final hostKey = GlobalKey();
  final attached = Completer<_FeatureNode>();
  _FeatureNode? node;
}
