part of '../follow.dart';

enum _Operation { push, replace, go }

class _FollowRouter extends ChangeNotifier {
  _FollowRouter(
      {String? initialLocation,
      RouteInformationProvider? routeInformationProvider,
      WidgetBuilder? loadingBuilder,
      FollowRouteBuilder? notFoundBuilder,
      FollowRouteBuilder? deniedBuilder,
      FollowErrorBuilder? errorBuilder})
      : loadingBuilder = loadingBuilder ?? _loading,
        notFoundBuilder = notFoundBuilder ?? _notFound,
        deniedBuilder = deniedBuilder ?? _denied,
        errorBuilder = errorBuilder ?? _errorView {
    if (initialLocation != null && routeInformationProvider != null) {
      throw ArgumentError(
          'initialLocation and routeInformationProvider cannot be used together');
    }
    final uri = routeInformationProvider?.value.uri ??
        _uri(
            initialLocation ??
                WidgetsBinding.instance.platformDispatcher.defaultRouteName,
            '/');
    _ownedProvider = routeInformationProvider == null
        ? _FollowInformationProvider(this, RouteInformation(uri: uri))
        : null;
    _provider = routeInformationProvider ?? _ownedProvider!;
    _delegate = _FollowDelegate(this);
    config = RouterConfig<FollowNavigationState>(
      routeInformationProvider: _provider,
      routeInformationParser: _FollowParser(),
      routerDelegate: _delegate,
      backButtonDispatcher: RootBackButtonDispatcher(),
    );
  }

  final WidgetBuilder loadingBuilder;
  final FollowRouteBuilder notFoundBuilder;
  final FollowRouteBuilder deniedBuilder;
  final FollowErrorBuilder errorBuilder;
  late final RouterConfig<FollowNavigationState> config;
  late final RouteInformationProvider _provider;
  late final _FollowInformationProvider? _ownedProvider;
  late final _FollowDelegate _delegate;
  final _rootReady = Completer<_FeatureNode>();
  _FeatureNode? _root;
  _Transaction? _transaction;
  FollowNavigationState? _configuration;
  RouteInformationReportingType _reporting =
      RouteInformationReportingType.neglect;
  int _nextId = 0;
  bool _disposed = false;
  bool _notificationScheduled = false;
  bool _isNavigating = false;
  Object? _error;
  StackTrace? _stackTrace;

  bool get isNavigating => _isNavigating;
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;
  Uri? get currentUri => _configuration?.uri;

  Future<void> push(RouteLocation location) =>
      _navigate(location.uri, _Operation.push);
  Future<void> replace(RouteLocation location) =>
      _navigate(location.uri, _Operation.replace);
  Future<void> go(RouteLocation location) =>
      _navigate(location.uri, _Operation.go);

  void _attach(_FeatureNode node) {
    if (_disposed) throw StateError('FollowRouter has been disposed');
    if (node.entry == null) {
      if (_root != null && _root != node && _root!.mounted) {
        throw StateError('A router has only one root module');
      }
      _root = node;
      if (!_rootReady.isCompleted) {
        _rootReady.complete(node);
      } else if (_configuration != null) {
        _refreshAfterMount();
      }
    } else {
      final entry = node.entry!;
      if (entry.node != null && entry.node != node && entry.node!.mounted) {
        throw StateError('A FeatureRoute must mount exactly one feature');
      }
      entry.node = node;
      if (entry.attached.isCompleted) _refreshAfterMount();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (entry.attached.isCompleted) return;
        if (node.outlet == null) {
          entry.attached.completeError(StateError(
              'FeatureRoute ${entry.route!.path} shell must include its outlet'));
        } else {
          entry.attached.complete(node);
        }
      });
    }
  }

  void _refreshAfterMount() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = currentUri;
      if (!_disposed && !_isNavigating && _root != null && uri != null) {
        unawaited(_navigate(uri, _Operation.go));
      }
    });
  }

  void _detach(_FeatureNode node) {
    node.mounted = false;
    if (_root == node) _root = null;
    if (_disposed) return;
    // A route removed by its owning widget, rather than a navigation commit,
    // invalidates the currently displayed destination.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed &&
          !_isNavigating &&
          _root != null &&
          _containsDeadNode(_root!)) {
        bool visibleDead(_FeatureNode current) {
          if (current.pages.isEmpty) return false;
          final top = current.pages.last;
          return top.route is _MountedFeatureRoute &&
              (top.node?.mounted != true || visibleDead(top.node!));
        }

        final uri = currentUri ?? Uri(path: '/');
        if (visibleDead(_root!)) {
          _fallback(uri, (context) => notFoundBuilder(context, RouteData(uri)));
        } else {
          void prune(_FeatureNode current) {
            current.pages = current.pages
                .where((entry) =>
                    entry.route is! _MountedFeatureRoute ||
                    entry.node?.mounted == true)
                .toList();
            for (final entry in current.pages) {
              if (entry.node != null) prune(entry.node!);
            }
          }

          prune(_root!);
          _publish(uri, true);
        }
      }
    });
  }

  bool _containsDeadNode(_FeatureNode node) => node.pages.any((entry) =>
      entry.route is _MountedFeatureRoute &&
      (entry.node == null ||
          !entry.node!.mounted ||
          _containsDeadNode(entry.node!)));

  void _changed() {
    if (_disposed || _notificationScheduled) return;
    _notificationScheduled = true;
    _scheduleNotification(() {
      _notificationScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> _navigate(Uri requested, _Operation operation,
      {FollowNavigationState? restore}) async {
    if (_disposed) throw StateError('FollowRouter has been disposed');
    _transaction?.cancel();
    final tx = _Transaction(this);
    _transaction = tx;
    _isNavigating = true;
    _error = null;
    _stackTrace = null;
    _changed();
    var uri = requested;
    try {
      final _FeatureNode root =
          _root ?? await tx.wait<_FeatureNode>(_rootReady.future);
      final visited = <Uri>{};
      for (var redirects = 0;; redirects++) {
        tx.check();
        if (redirects > 10 || !visited.add(uri)) {
          throw StateError('Redirect loop or more than ten redirects: $uri');
        }
        try {
          if (restore != null &&
              restore._locations.isNotEmpty &&
              redirects == 0) {
            var first = true;
            for (final location in restore._locations) {
              final target = _uri(location['uri']! as String, '/');
              final ids = (location['ids']! as List).cast<int>();
              await _resolve(root, target, _segments(target.path), 0, {},
                  first ? _Operation.go : _Operation.push, tx,
                  ids: ids);
              first = false;
            }
          } else {
            await _resolve(
                root, uri, _segments(uri.path), 0, {}, operation, tx);
          }
          tx.check();
          tx.commit();
          _publish(uri, restore != null || operation != _Operation.push);
          break;
        } on _RedirectNavigation catch (redirect) {
          tx.clearDraft();
          uri = redirect.uri;
          restore = null;
        }
      }
    } on _Cancelled {
      // A newer request owns presentation and URL updates.
    } on _DeniedNavigation {
      tx.clearDraft();
      if (!tx.cancelled && _configuration == null && _root != null) {
        _fallback(uri, (context) => deniedBuilder(context, RouteData(uri)));
      }
    } on _NotFoundNavigation {
      tx.clearDraft();
      if (!tx.cancelled && _root != null) {
        _fallback(uri, (context) => notFoundBuilder(context, RouteData(uri)),
            replace: operation != _Operation.push || restore != null);
      }
    } catch (error, stack) {
      tx.clearDraft();
      if (!tx.cancelled) {
        _error = error;
        _stackTrace = stack;
        if (_configuration == null && _root != null) {
          _fallback(uri, (context) => errorBuilder(context, error, stack));
        }
      }
    } finally {
      tx.clearDraft();
      if (identical(_transaction, tx)) {
        _transaction = null;
        _isNavigating = false;
        _changed();
      }
    }
  }

  Future<void> _resolve(
      _FeatureNode node,
      Uri uri,
      List<String> segments,
      int offset,
      Map<String, String> inherited,
      _Operation operation,
      _Transaction tx,
      {List<int> ids = const [],
      int depth = 0}) async {
    tx.check();
    if (!node.mounted) throw _NotFoundNavigation();
    if (ids.isNotEmpty && tx.restoringNodes.add(node)) tx.drafts[node] = [];
    final match = _match(node, segments, offset);
    if (match == null) throw _NotFoundNavigation();
    final params = {...inherited, ...match.params};
    final data = RouteData(uri, params);
    final arguments = match.route.decode(data);
    for (final guard in match.route._guards) {
      final result =
          await tx.wait(Future.sync(() => guard(arguments, node.access)));
      tx.check();
      switch (result) {
        case _Allow():
          break;
        case _Deny():
          throw _DeniedNavigation();
        case _Redirect():
          throw _RedirectNavigation(result.location.uri);
      }
    }
    final stack = tx.pages(node);
    final end = offset + match.count;
    final base = Uri(pathSegments: ['', ...segments.take(end)]).path;
    final restoreId = depth < ids.length ? ids[depth] : null;
    _RouteEntry? entry;
    if (restoreId != null) {
      bool matches(_RouteEntry candidate) =>
          candidate.id == restoreId &&
          identical(candidate.route, match.route) &&
          candidate.base == base &&
          (candidate.route is _MountedFeatureRoute
              ? candidate.node?.mounted == true
              : candidate.data.uri == uri) &&
          candidate.arguments == arguments;
      entry = stack.where(matches).firstOrNull ??
          node.pages.where(matches).firstOrNull;
    } else if (match.route is _MountedFeatureRoute && stack.isNotEmpty) {
      final top = stack.last;
      if (identical(top.route, match.route) &&
          top.base == base &&
          top.node?.mounted == true &&
          top.arguments == arguments) {
        entry = top;
      }
    }
    if (restoreId != null && restoreId >= _nextId) _nextId = restoreId + 1;
    entry ??= _RouteEntry(
      restoreId ?? _nextId++,
      node,
      match.route,
      data,
      arguments,
      base,
    );
    tx.data[entry] = data;
    tx.arguments[entry] = arguments;
    if (operation == _Operation.go) {
      tx.drafts[node] = [entry];
    } else if (!stack.contains(entry)) {
      tx.drafts[node] = [
        ...stack.take(operation == _Operation.replace && stack.isNotEmpty
            ? stack.length - 1
            : stack.length),
        entry,
      ];
    }
    if (match.route is _MountedFeatureRoute) {
      if (entry.node?.mounted != true) {
        node.staging.add(entry);
        tx.staged.add(entry);
        // Observe mount failures before requesting the frame that mounts it.
        final attached = tx.wait(entry.attached.future);
        _changed();
        await attached;
      }
      tx.check();
      await _resolve(entry.node!, uri, segments, end, params, operation, tx,
          ids: ids, depth: depth + 1);
    }
  }

  void _fallback(Uri uri, WidgetBuilder builder, {bool replace = true}) {
    final root = _root!;
    final entry = _RouteEntry(
      _nextId++,
      root,
      null,
      RouteData(uri),
      null,
      '/',
      fallback: builder,
    );
    root.pages = replace ? [entry] : [...root.pages, entry];
    _publish(uri, replace);
  }

  void _publish(Uri uri, bool replace) {
    final locations = <Map<String, Object?>>[];
    void visit(_FeatureNode node, List<int> ancestors) {
      for (final entry in node.pages) {
        final ids = [...ancestors, entry.id];
        if (entry.route is _MountedFeatureRoute && entry.node != null) {
          visit(entry.node!, ids);
        } else {
          locations.add({'uri': entry.data.uri.toString(), 'ids': ids});
        }
      }
    }

    if (_root != null) visit(_root!, []);
    _configuration = FollowNavigationState._(uri, locations);
    _reporting = replace
        ? RouteInformationReportingType.neglect
        : RouteInformationReportingType.navigate;
    _changed();
  }

  Future<bool> pop() async {
    if (_disposed) return false;
    _transaction?.cancel();
    _transaction = null;
    _isNavigating = false;
    final root = _root;
    if (root == null || root.pages.isEmpty) return false;
    bool remove(_FeatureNode node) {
      final top = node.pages.last;
      if (top.node != null && top.node!.pages.isNotEmpty && remove(top.node!)) {
        return true;
      }
      if (node.pages.length <= 1) return false;
      node.pages = node.pages.sublist(0, node.pages.length - 1);
      return true;
    }

    final didPop = remove(root);
    if (didPop) _publish(_visibleUri(root), true);
    _changed();
    return didPop;
  }

  Uri _visibleUri(_FeatureNode node) {
    final top = node.pages.last;
    return top.node != null && top.node!.pages.isNotEmpty
        ? _visibleUri(top.node!)
        : top.data.uri;
  }

  void _removed(_FeatureNode node, _RouteEntry entry) {
    if (_disposed || !node.pages.contains(entry)) return;
    node.pages = node.pages.where((e) => e != entry).toList();
    if (_root != null && _root!.pages.isNotEmpty) {
      _publish(_visibleUri(_root!), true);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _transaction?.cancel();
    _disposed = true;
    _delegate.dispose();
    _ownedProvider?.dispose();
    super.dispose();
  }

  static Widget _loading(BuildContext context) =>
      const Center(child: Text('Loading…', textDirection: TextDirection.ltr));
  static Widget _notFound(BuildContext context, RouteData state) => Center(
      child: Text('Not found: ${state.uri}', textDirection: TextDirection.ltr));
  static Widget _denied(BuildContext context, RouteData state) => const Center(
      child: Text('Access denied', textDirection: TextDirection.ltr));
  static Widget _errorView(
          BuildContext context, Object error, StackTrace stack) =>
      Center(
          child: Text('Navigation failed: $error',
              textDirection: TextDirection.ltr));
}
