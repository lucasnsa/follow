part of '../follow.dart';

/// Builds shared UI around the shell's persistent branch outlet.
typedef FollowShellBuilder = Widget Function(
    BuildContext context, FollowShellController navigation, Widget outlet);

/// Immutable configuration for independent, lazily mounted feature stacks.
final class FeatureShell {
  FeatureShell.indexedStack({
    required Iterable<FeatureBranch> branches,
    required FollowShellBuilder builder,
    int initialIndex = 0,
  }) : this._(branches: branches, builder: builder, initialIndex: initialIndex);

  /// Retains all visited branches while animating changes in selection.
  FeatureShell.animated({
    required Iterable<FeatureBranch> branches,
    required FollowShellBuilder builder,
    required BranchTransition transition,
    int initialIndex = 0,
  }) : this._(
            branches: branches,
            builder: builder,
            initialIndex: initialIndex,
            transition: transition);

  FeatureShell._({
    required Iterable<FeatureBranch> branches,
    required this.builder,
    required this.initialIndex,
    this.transition,
  }) : branches = List.unmodifiable(branches) {
    if (this.branches.isEmpty) {
      throw ArgumentError('A shell requires at least one branch');
    }
    RangeError.checkValidIndex(initialIndex, this.branches, 'initialIndex');
    _compileRoutes(this.branches.map((b) => b._route).toList());
    for (var i = 0; i < this.branches.length; i++) {
      final a = _segments(this.branches[i]._route.path);
      for (var j = i + 1; j < this.branches.length; j++) {
        final b = _segments(this.branches[j]._route.path);
        final length = a.length < b.length ? a.length : b.length;
        if (List.generate(
            length,
            (k) =>
                a[k] == b[k] ||
                a[k].startsWith(':') ||
                b[k].startsWith(':')).every((v) => v)) {
          throw ArgumentError('Shell branch prefixes must not overlap');
        }
      }
    }
  }

  final List<FeatureBranch> branches;
  final int initialIndex;
  final FollowShellBuilder builder;
  final BranchTransition? transition;
}

/// One retained feature instance in a shell, identified by its mount route.
final class FeatureBranch {
  FeatureBranch._(this._route, this.initialLocation) {
    final prefix = _segments(_route.path);
    final target = _segments(initialLocation.uri.path);
    if (target.length < prefix.length ||
        !List.generate(prefix.length,
                (i) => prefix[i].startsWith(':') || prefix[i] == target[i])
            .every((v) => v)) {
      throw ArgumentError(
          'Branch initialLocation must be inside ${_route.path}');
    }
  }

  static FeatureBranch mount<A>(
    RouteSpec<A> spec, {
    required Feature Function(A arguments) feature,
    required RouteLocation initialLocation,
    List<FeatureGuard<A>> guards = const [],
  }) =>
      FeatureBranch._(
          _MountedFeatureRoute<A>(spec, feature, guards), initialLocation);

  final _MountedFeatureRoute _route;
  final RouteLocation initialLocation;
}

/// Runtime-owned handle. Obtain it from the shell builder or context.follow.shell.
final class FollowShellController {
  FollowShellController._(this._node);
  final _FeatureNode _node;

  int get currentIndex => _node.activeIndex;
  int get branchCount => _node.definition.feature.shell!.branches.length;

  /// Resumes a branch, or returns it to its initial location when [reset] is true.
  Future<void> goBranch(int index, {bool reset = false}) {
    RangeError.checkValidIndex(
        index, _node.definition.feature.shell!.branches, 'index');
    if (!_node.mounted || _node.router._disposed) {
      throw StateError('Shell has been disposed');
    }
    return _node.router._goBranch(_node, index, reset: reset);
  }
}

class _ShellScope extends InheritedWidget {
  const _ShellScope(
      {required this.controller, required this.index, required super.child});
  final FollowShellController controller;
  final int index;
  @override
  bool updateShouldNotify(_ShellScope oldWidget) =>
      controller != oldWidget.controller || index != oldWidget.index;
}
