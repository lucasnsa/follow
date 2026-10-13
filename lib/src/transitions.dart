part of '../follow.dart';

/// Immutable page motion. Builders receive uncurved Flutter route animations.
final class FollowTransition {
  const FollowTransition.none()
      : duration = Duration.zero,
        reverseDuration = Duration.zero,
        builder = _noTransition;

  factory FollowTransition.custom({
    Duration duration = const Duration(milliseconds: 300),
    Duration? reverseDuration,
    required RouteTransitionsBuilder builder,
  }) {
    _validateDurations(duration, reverseDuration);
    return FollowTransition._(duration, reverseDuration ?? duration, builder);
  }

  factory FollowTransition.fade({
    Duration duration = const Duration(milliseconds: 300),
    Duration? reverseDuration,
  }) =>
      FollowTransition.custom(
          duration: duration,
          reverseDuration: reverseDuration,
          builder: _fadeTransition);

  /// Slides from the trailing edge, respecting Directionality.
  factory FollowTransition.slide({
    Duration duration = const Duration(milliseconds: 300),
    Duration? reverseDuration,
  }) =>
      FollowTransition.custom(
          duration: duration,
          reverseDuration: reverseDuration,
          builder: _slideTransition);

  const FollowTransition._(this.duration, this.reverseDuration, this.builder);
  final Duration duration;
  final Duration reverseDuration;
  final RouteTransitionsBuilder builder;
}

/// Motion between persistent branches, independent of their page transitions.
final class BranchTransition {
  factory BranchTransition.custom({
    Duration duration = const Duration(milliseconds: 300),
    Duration? reverseDuration,
    required RouteTransitionsBuilder builder,
  }) =>
      BranchTransition._(FollowTransition.custom(
          duration: duration,
          reverseDuration: reverseDuration,
          builder: builder));

  factory BranchTransition.fade({
    Duration duration = const Duration(milliseconds: 300),
    Duration? reverseDuration,
  }) =>
      BranchTransition.custom(
          duration: duration,
          reverseDuration: reverseDuration,
          builder: _fadeTransition);

  const BranchTransition._(this._transition);
  final FollowTransition _transition;
  Duration get duration => _transition.duration;
  Duration get reverseDuration => _transition.reverseDuration;
  RouteTransitionsBuilder get builder => _transition.builder;
}

void _validateDurations(Duration duration, Duration? reverseDuration) {
  if (duration.isNegative || (reverseDuration?.isNegative ?? false)) {
    throw ArgumentError('Transition durations must not be negative');
  }
}

Widget _noTransition(BuildContext context, Animation<double> animation,
        Animation<double> secondaryAnimation, Widget child) =>
    child;

Widget _fadeTransition(BuildContext context, Animation<double> animation,
        Animation<double> secondaryAnimation, Widget child) =>
    FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeInOutCubic)),
      child: FadeTransition(
        opacity: ReverseAnimation(
            secondaryAnimation.drive(CurveTween(curve: Curves.easeInOutCubic))),
        child: child,
      ),
    );

Widget _slideTransition(BuildContext context, Animation<double> animation,
        Animation<double> secondaryAnimation, Widget child) =>
    SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeInOutCubic))
          .animate(animation),
      textDirection: Directionality.of(context),
      child: child,
    );

/// Explicit decisions keep initial/staged/restored pages motionless and retain
/// only the visible exiting page for an animated replacement.
class _FollowTransitionDelegate extends TransitionDelegate<void> {
  const _FollowTransitionDelegate(this.animate, this.previousTopId);
  final bool animate;
  final int? previousTopId;

  @override
  Iterable<RouteTransitionRecord> resolve({
    required List<RouteTransitionRecord> newPageRouteHistory,
    required Map<RouteTransitionRecord?, RouteTransitionRecord>
        locationToExitingPageRoute,
    required Map<RouteTransitionRecord?, List<RouteTransitionRecord>>
        pageRouteToPagelessRoutes,
  }) {
    final result = <RouteTransitionRecord>[];
    // Only the page visible before the commit exits with motion.
    // Removed intermediate pages settle immediately.
    final retainedTop = newPageRouteHistory.lastOrNull;
    void exitAfter(RouteTransitionRecord? location) {
      final record = locationToExitingPageRoute[location];
      if (record == null) return;
      final pageless = pageRouteToPagelessRoutes[record] ?? const [];
      final settings = record.route.settings;
      final isTopExit =
          settings is _FollowPage && settings.entry.id == previousTopId;

      if (record.isWaitingForExitingDecision) {
        if (animate && isTopExit && pageless.isEmpty) {
          record.markForPop(record.route.currentResult);
        } else {
          record.markForComplete(record.route.currentResult);
        }
      }
      for (final route in pageless) {
        if (route.isWaitingForExitingDecision) {
          if (animate && isTopExit && identical(route, pageless.last)) {
            route.markForPop(route.route.currentResult);
          } else {
            route.markForComplete(route.route.currentResult);
          }
        }
      }
      result.add(record);
      exitAfter(record);
    }

    exitAfter(null);
    for (final record in newPageRouteHistory) {
      if (record.isWaitingForEnteringDecision) {
        if (animate && identical(record, retainedTop)) {
          record.markForPush();
        } else {
          record.markForAdd();
        }
      }
      result.add(record);
      exitAfter(record);
    }
    return result;
  }
}

class _FollowPageRoute extends PageRouteBuilder<void> {
  _FollowPageRoute(_FollowPage page)
      : _entry = page.entry,
        super(
          settings: page,
          transitionDuration: page.transition.duration,
          reverseTransitionDuration: page.transition.reverseDuration,
          transitionsBuilder: page.transition.builder,
          pageBuilder: (_, __, ___) =>
              _EntryHost(key: page.entry.hostKey, entry: page.entry),
        );

  final _RouteEntry _entry;
  bool _disposed = false;
  bool _settling = false;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (!_entry.owner.animatePages ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      if (!_settling && controller?.isAnimating == true) {
        _settling = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _settling = false;
          if (!_disposed && controller?.isAnimating == true) {
            controller!.value =
                controller!.status == AnimationStatus.reverse ? 0 : 1;
          }
        });
      }
      return super.buildTransitions(
          context, kAlwaysCompleteAnimation, kAlwaysDismissedAnimation, child);
    }
    return super
        .buildTransitions(context, animation, secondaryAnimation, child);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
