part of '../follow.dart';

class _NodeScope extends InheritedWidget {
  const _NodeScope({required this.node, required super.child});
  final _FeatureNode? node;
  @override
  bool updateShouldNotify(_NodeScope oldWidget) => node != oldWidget.node;
}

class _RouteMount extends InheritedWidget {
  const _RouteMount({required this.entry, required super.child});
  final _RouteEntry entry;
  @override
  bool updateShouldNotify(_RouteMount oldWidget) => entry != oldWidget.entry;
}

class _RouteStateScope extends InheritedWidget {
  const _RouteStateScope({required this.data, required super.child});
  final RouteData data;
  @override
  bool updateShouldNotify(_RouteStateScope oldWidget) => data != oldWidget.data;
}

/// Displays one module's local navigation stack, optionally inside a shell.
class _FeatureOutlet extends StatefulWidget {
  const _FeatureOutlet();
  @override
  State<_FeatureOutlet> createState() => _FeatureOutletState();
}

class _FeatureOutletState extends State<_FeatureOutlet> {
  _FeatureNode? node;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.dependOnInheritedWidgetOfExactType<_NodeScope>()?.node;
    if (next == null) {
      throw StateError('Feature outlet requires a routed Feature');
    }
    if (next.outlet != null && next.outlet != this) {
      throw StateError('A feature shell must include its outlet exactly once');
    }
    if (node != next) {
      node?.router.removeListener(_changed);
      if (node?.outlet == this) node!.outlet = null;
      node = next;
      next.outlet = this;
      next.context = context;
      next.router.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    node?.router.removeListener(_changed);
    if (node?.outlet == this) {
      node!.outlet = null;
      node!.context = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = node!;
    return Stack(fit: StackFit.expand, children: [
      if (current.pages.isEmpty)
        current.router.loadingBuilder(context)
      else
        Navigator(
          key: current.navigatorKey,
          pages: [
            for (final entry in current.pages)
              _FollowPage(entry, canPop: current.pages.length > 1)
          ],
          onDidRemovePage: (page) {
            if (page is _FollowPage) {
              current.router._removed(current, page.entry);
            }
          },
        ),
      for (final entry in current.staging)
        Offstage(
            offstage: true,
            child: TickerMode(
                enabled: false,
                child: HeroControllerScope.none(
                    child: Navigator(
                  pages: [_FollowPage(entry, canPop: false)],
                  onDidRemovePage: (_) {},
                )))),
    ]);
  }
}

class _FollowPage extends Page<void> {
  _FollowPage(this.entry, {required super.canPop})
      : super(key: ValueKey(entry.id), name: entry.data.uri.toString());
  final _RouteEntry entry;
  @override
  Route<void> createRoute(BuildContext context) => PageRouteBuilder<void>(
        settings: this,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) =>
            _EntryHost(key: entry.hostKey, entry: entry),
      );
}

class _EntryHost extends StatefulWidget {
  const _EntryHost({required this.entry, super.key});
  final _RouteEntry entry;
  @override
  State<_EntryHost> createState() => _EntryHostState();
}

class _EntryHostState extends State<_EntryHost> {
  Widget? child;
  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    entry.owner.router.addListener(_changed);
    if (entry.route is _MountedFeatureRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && entry.node == null && !entry.attached.isCompleted) {
          entry.attached.completeError(StateError(
              'FeatureRoute ${entry.route!.path} did not mount its feature'));
        }
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.entry.owner.router.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return _RouteStateScope(
        data: entry.data,
        child: _RouteMount(
            entry: entry,
            child: Builder(builder: (inner) {
              try {
                return child ??= switch (entry.route) {
                  _PageFeatureRoute route =>
                    route.build(inner, entry.arguments),
                  _MountedFeatureRoute route => _FeatureHost(
                      feature: route.feature(entry.arguments), routed: true),
                  null => entry.fallback!(inner),
                };
              } catch (error, stack) {
                if (!entry.attached.isCompleted &&
                    entry.route is _MountedFeatureRoute) {
                  entry.attached.completeError(error, stack);
                }
                return entry.owner.router.errorBuilder(inner, error, stack);
              }
            })));
  }
}
