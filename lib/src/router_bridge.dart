part of '../follow.dart';

/// Serializable URL and navigation tree used by browser back/forward.
class FollowNavigationState {
  FollowNavigationState(this.uri)
      : _locations = const [],
        _selections = const {},
        _tree = null;
  FollowNavigationState._(this.uri, this._locations,
      [this._selections = const {}, this._tree]);
  final Uri uri;
  final List<Map<String, Object?>> _locations;
  final Map<int, int> _selections;
  final Map<String, Object?>? _tree;
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
    final selections = <int, int>{};
    try {
      if (state is Map && state['follow'] == 2) {
        final seen = <int>{};
        var count = 0;
        Uri visit(Object? value, List<int> ancestors, int? inactiveRoot) {
          if (value is! Map || ancestors.length > 64 || ++count > 10000) {
            throw const FormatException('Invalid navigation tree');
          }
          final kind = value['kind'];
          final pages = value['pages'];
          final active = value['active'];
          if ((kind != 'stack' && kind != 'shell') ||
              pages is! List ||
              pages.isEmpty ||
              (kind == 'shell' && (active is! int || active < 0))) {
            throw const FormatException('Invalid navigation node');
          }
          if (kind == 'shell') {
            selections[ancestors.lastOrNull ?? -1] = active as int;
          }
          Uri? visible;
          final branches = <int>{};
          for (final page in pages) {
            if (page is! Map ||
                page['id'] is! int ||
                (page['id'] as int) < 0 ||
                !seen.add(page['id'] as int) ||
                page['uri'] is! String) {
              throw const FormatException('Invalid navigation entry');
            }
            final uri = Uri.parse(page['uri'] as String);
            if (!uri.path.startsWith('/') ||
                uri.hasScheme ||
                uri.hasAuthority) {
              throw const FormatException('Invalid route URI');
            }
            final ids = [...ancestors, page['id'] as int];
            var inactive = inactiveRoot;
            if (kind == 'shell') {
              final branch = page['branch'];
              if (branch is! int ||
                  branch < 0 ||
                  !branches.add(branch) ||
                  page['child'] == null) {
                throw const FormatException('Invalid shell branch');
              }
              if (branch != active) inactive ??= page['id'] as int;
            }
            Uri leaf;
            if (page['child'] != null) {
              leaf = visit(page['child'], ids, inactive);
            } else {
              leaf = uri;
              locations.add({
                'uri': uri.toString(),
                'ids': ids,
                if (inactive != null) 'inactive': inactive
              });
            }
            if (kind == 'stack' || page['branch'] == active) visible = leaf;
          }
          if (visible == null) {
            throw const FormatException('Missing active branch');
          }
          return visible;
        }

        if (visit(state['tree'], [], null) != information.uri) {
          throw const FormatException('Snapshot URI mismatch');
        }
      } else if (state is Map &&
          state['follow'] == 1 &&
          state['locations'] is List) {
        for (final item in state['locations'] as List) {
          if (item is! Map ||
              item['uri'] is! String ||
              item['ids'] is! List ||
              (item['ids'] as List).isEmpty ||
              !(item['ids'] as List).every((id) => id is int && id >= 0)) {
            throw const FormatException('Invalid legacy snapshot');
          }
          locations.add({
            'uri': item['uri'] as String,
            'ids': List<int>.from(item['ids'] as List)
          });
        }
        if (locations.isNotEmpty &&
            locations.last['uri'] != information.uri.toString()) {
          throw const FormatException('Snapshot URI mismatch');
        }
      }
    } catch (_) {
      locations.clear();
      selections.clear();
    }
    return SynchronousFuture(
        FollowNavigationState._(information.uri, locations, selections));
  }

  @override
  RouteInformation restoreRouteInformation(
          FollowNavigationState configuration) =>
      RouteInformation(
          uri: configuration.uri,
          state: configuration._tree == null
              ? {'follow': 1, 'locations': configuration._locations}
              : {'follow': 2, 'tree': configuration._tree});
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
    return root.content ??= Builder(
      builder: (context) =>
          root.definition.feature.buildContent(context, const _FeatureOutlet()),
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
