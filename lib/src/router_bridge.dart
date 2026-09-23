part of '../follow.dart';

/// Serializable URL and local page stacks used by browser back/forward.
class FollowNavigationState {
  FollowNavigationState(this.uri) : _locations = const [];
  FollowNavigationState._(this.uri, this._locations);
  final Uri uri;
  final List<Map<String, Object?>> _locations;
}

class _RouterScope extends InheritedNotifier<_FollowRouter> {
  const _RouterScope({required super.notifier, required super.child});
}

class _FollowParser extends RouteInformationParser<FollowNavigationState> {
  @override
  Future<FollowNavigationState> parseRouteInformation(
      RouteInformation information) {
    final state = information.state;
    final locations = <Map<String, Object?>>[];
    if (state is Map && state['follow'] == 1 && state['locations'] is List) {
      for (final item in state['locations'] as List) {
        if (item is! Map ||
            item['uri'] is! String ||
            item['ids'] is! List ||
            !(item['ids'] as List).every((id) => id is int && id >= 0)) {
          locations.clear();
          break;
        }
        locations.add(
            {'uri': item['uri'], 'ids': List<int>.from(item['ids'] as List)});
      }
    }
    if (locations.isNotEmpty &&
        locations.last['uri'] != information.uri.toString()) {
      locations.clear();
    }
    return SynchronousFuture(
        FollowNavigationState._(information.uri, locations));
  }

  @override
  RouteInformation restoreRouteInformation(
          FollowNavigationState configuration) =>
      RouteInformation(
          uri: configuration.uri,
          state: {'follow': 1, 'locations': configuration._locations});
}

class _FollowDelegate extends RouterDelegate<FollowNavigationState>
    with ChangeNotifier {
  _FollowDelegate(this.router) {
    router.addListener(notifyListeners);
  }
  final _FollowRouter router;
  @override
  FollowNavigationState? get currentConfiguration => router._configuration;
  @override
  Future<void> setNewRoutePath(FollowNavigationState configuration) => router
      ._navigate(configuration.uri, _Operation.go, restore: configuration);
  @override
  Future<bool> popRoute() => router.pop();
  @override
  Widget build(BuildContext context) {
    final root = router._root;
    if (root == null) return router.loadingBuilder(context);
    return root.shell ??= Builder(
      builder: (context) =>
          root.definition.feature.buildShell(context, const _FeatureOutlet()),
    );
  }

  @override
  void dispose() {
    router.removeListener(notifyListeners);
    super.dispose();
  }
}

class _FollowInformationProvider extends PlatformRouteInformationProvider {
  _FollowInformationProvider(this.router, RouteInformation initial)
      : super(initialRouteInformation: initial);
  final _FollowRouter router;
  @override
  void routerReportsNewRouteInformation(RouteInformation routeInformation,
      {RouteInformationReportingType type =
          RouteInformationReportingType.none}) {
    super.routerReportsNewRouteInformation(routeInformation,
        type: router._reporting);
    router._reporting = RouteInformationReportingType.neglect;
  }
}
