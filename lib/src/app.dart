part of '../follow.dart';

typedef FollowAppBuilder = Widget Function(
    BuildContext context, RouterConfig<FollowNavigationState> routerConfig);

/// Owns the root feature and router for an application or isolated subtree.
class FollowApp extends StatefulWidget {
  const FollowApp({
    required this.feature,
    required this.builder,
    this.initialLocation,
    this.routeInformationProvider,
    this.loadingBuilder,
    this.notFoundBuilder,
    this.deniedBuilder,
    this.errorBuilder,
    super.key,
  });

  final Feature feature;
  final FollowAppBuilder builder;
  final String? initialLocation;
  final RouteInformationProvider? routeInformationProvider;
  final WidgetBuilder? loadingBuilder;
  final FollowRouteBuilder? notFoundBuilder;
  final FollowRouteBuilder? deniedBuilder;
  final FollowErrorBuilder? errorBuilder;

  @override
  State<FollowApp> createState() => _FollowAppState();
}

class _FollowAppState extends State<FollowApp> {
  late final Feature _feature = widget.feature;
  late final _FollowRouter _router = _FollowRouter(
    initialLocation: widget.initialLocation,
    routeInformationProvider: widget.routeInformationProvider,
    loadingBuilder: widget.loadingBuilder,
    notFoundBuilder: widget.notFoundBuilder,
    deniedBuilder: widget.deniedBuilder,
    errorBuilder: widget.errorBuilder,
  );

  @override
  Widget build(BuildContext context) => _FeatureHost(
        feature: _feature,
        router: _router,
        contentBuilder: (context) => widget.builder(context, _router.config),
      );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }
}
