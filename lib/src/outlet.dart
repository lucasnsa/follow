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

/// Displays a feature's stack or its persistent shell branches.
class _FeatureOutlet extends StatefulWidget {
  const _FeatureOutlet();
  @override
  State<_FeatureOutlet> createState() => _FeatureOutletState();
}

class _FeatureOutletState extends State<_FeatureOutlet> {
  _FeatureNode? node;
  final _heroes = HeroController();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.dependOnInheritedWidgetOfExactType<_NodeScope>()?.node;
    if (next == null) {
      throw StateError('Feature outlet requires a routed Feature');
    }
    if (next.outlet != null && next.outlet != this) {
      throw StateError(
          'A feature builder must include its outlet exactly once');
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
    _heroes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = node!;
    if (current.isShell) {
      return _ShellScope(
        controller: current.shellController,
        index: current.activeIndex,
        child: Stack(fit: StackFit.expand, children: [
          Offstage(
            offstage: current.activeEntry?.fallback != null,
            child: ExcludeFocus(
              excluding: current.activeEntry?.fallback != null,
              child: TickerMode(
                enabled: current.activeEntry?.fallback == null,
                child: Builder(
                    builder: (context) => current.definition.feature.shell!
                        .builder(context, current.shellController,
                            _ShellBranches(node: current))),
              ),
            ),
          ),
          if (current.activeEntry?.fallback != null)
            _EntryHost(
                key: current.activeEntry!.hostKey, entry: current.activeEntry!),
        ]),
      );
    }
    return Stack(fit: StackFit.expand, children: [
      if (current.pages.isEmpty)
        current.router.loadingBuilder(context)
      else
        HeroControllerScope(
          controller: _heroes,
          child: Navigator(
            transitionDelegate: _FollowTransitionDelegate(
                current.animatePages &&
                    !(MediaQuery.maybeOf(context)?.disableAnimations ?? false),
                current.previousTopId),
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
        ),
      for (final entry in current.staging)
        Offstage(
            offstage: true,
            child: TickerMode(
                enabled: false,
                child: HeroControllerScope.none(
                    child: Navigator(
                  pages: [_FollowPage(entry, canPop: false, staged: true)],
                  onDidRemovePage: (_) {},
                )))),
    ]);
  }
}

class _FollowPage extends Page<void> {
  _FollowPage(this.entry, {required super.canPop, bool staged = false})
      : transition = staged || entry.fallback != null
            ? const FollowTransition.none()
            : entry.route?.transition ?? entry.owner.pageTransition,
        super(key: ValueKey(entry.id), name: entry.data.uri.toString());
  final _RouteEntry entry;
  final FollowTransition transition;
  @override
  Route<void> createRoute(BuildContext context) => _FollowPageRoute(this);
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

class _ShellBranches extends StatefulWidget {
  const _ShellBranches({required this.node});
  final _FeatureNode node;
  @override
  State<_ShellBranches> createState() => _ShellBranchesState();
}

class _ShellBranchesState extends State<_ShellBranches>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this)
    ..addStatusListener(_statusChanged);
  late int _selected;
  late int _serial;
  int? _outgoing;
  bool _reverse = false;
  bool _disabled = false;

  @override
  void initState() {
    super.initState();
    final node = widget.node;
    if (node.shellOutlet != null) {
      throw StateError('A shell builder must include its outlet exactly once');
    }
    node.shellOutlet = this;
    _selected = node.activeIndex;
    _serial = node.presentationSerial;
    _motion.value = 1;
  }

  void _statusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && _outgoing != null && mounted) {
      setState(() => _outgoing = null);
    }
  }

  void _settle() {
    _outgoing = null;
    _motion.stop();
    _motion.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_disabled) _settle();
  }

  @override
  void didUpdateWidget(_ShellBranches oldWidget) {
    super.didUpdateWidget(oldWidget);
    final node = widget.node;
    if (_serial == node.presentationSerial) return;
    _serial = node.presentationSerial;
    final previous = _selected;
    _settle();
    _selected = node.activeIndex;
    final transition = node.definition.feature.shell!.transition;
    if (previous == _selected ||
        !node.animateBranches ||
        transition == null ||
        _disabled) {
      return;
    }
    _reverse = _selected < previous;
    final duration =
        _reverse ? transition.reverseDuration : transition.duration;
    if (duration == Duration.zero) return;
    _outgoing = previous;
    _motion.duration = duration;
    _motion.forward(from: 0);
  }

  @override
  void dispose() {
    if (widget.node.shellOutlet == this) widget.node.shellOutlet = null;
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final transition = node.definition.feature.shell!.transition;
    // Every branch occupies one permanent slot, including during interruption.
    return Stack(fit: StackFit.expand, children: [
      for (var i = 0; i < node.definition.routes.length; i++)
        Offstage(
          offstage: i != _selected && i != _outgoing,
          child: IgnorePointer(
            ignoring: i != _selected,
            child: ExcludeFocus(
              excluding: i != _selected,
              child: ExcludeSemantics(
                excluding: i != _selected,
                child: _transition(
                  context,
                  transition,
                  i,
                  TickerMode(
                    enabled: i == _selected,
                    child: Stack(fit: StackFit.expand, children: [
                      for (final entry in {...node.pages, ...node.staging})
                        if (node.branchIndex(entry) == i)
                          Offstage(
                            key: ValueKey(entry.id),
                            offstage: !node.pages.contains(entry),
                            child: TickerMode(
                              enabled: node.pages.contains(entry),
                              child: HeroControllerScope.none(
                                child: _EntryHost(
                                    key: entry.hostKey, entry: entry),
                              ),
                            ),
                          ),
                      if (!node.pages
                          .any((entry) => node.branchIndex(entry) == i))
                        node.router.loadingBuilder(context),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _transition(BuildContext context, BranchTransition? transition,
      int index, Widget child) {
    if (transition == null) return child;
    const complete = kAlwaysCompleteAnimation;
    const dismissed = kAlwaysDismissedAnimation;
    Animation<double> primary = complete;
    Animation<double> secondary = dismissed;
    if (_outgoing != null) {
      if (index == _selected) {
        if (_reverse) {
          secondary = ReverseAnimation(_motion);
        } else {
          primary = _motion;
        }
      } else if (index == _outgoing) {
        if (_reverse) {
          primary = ReverseAnimation(_motion);
        } else {
          secondary = _motion;
        }
      }
    }
    return AnimatedBuilder(
      animation: Listenable.merge([primary, secondary]),
      child: child,
      builder: (context, child) =>
          transition.builder(context, primary, secondary, child!),
    );
  }
}
