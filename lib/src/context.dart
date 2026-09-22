part of '../follow.dart';

extension FollowBuildContext on BuildContext {
  FollowContext get follow => FollowContext._(this);
}

/// Access to the nearest Follow feature and router.
final class FollowContext {
  const FollowContext._(this._context);

  final BuildContext _context;

  _FeatureAccess _feature({required bool listen}) {
    final scope = listen
        ? _context.dependOnInheritedWidgetOfExactType<_FeatureScope>()
        : _context.getInheritedWidgetOfExactType<_FeatureScope>();
    return scope?.notifier ??
        (throw StateError('No Follow feature above this context'));
  }

  _FollowNavigation _navigation({required bool listen}) {
    final scope = listen
        ? _context.dependOnInheritedWidgetOfExactType<_RouterScope>()
        : _context.getInheritedWidgetOfExactType<_RouterScope>();
    final node = listen
        ? _context.dependOnInheritedWidgetOfExactType<_NodeScope>()?.node
        : _context.getInheritedWidgetOfExactType<_NodeScope>()?.node;
    if (scope?.notifier == null || node == null) {
      throw StateError('No Follow router above this context');
    }
    return _FollowNavigation(scope!.notifier!);
  }

  T read<T extends Object>(Token<T> token) => _feature(listen: false)(token);

  Future<T> readAsync<T extends Object>(Token<T> token) =>
      _feature(listen: false).async(token);

  DependencyState<T> watch<T extends Object>(Token<T> token) =>
      _feature(listen: true).watch(token);

  FeatureState get featureState => _feature(listen: true).state;
  Future<void> get ready => _feature(listen: false).ready;

  DiagnosticsNode get debugDiagnostics {
    final scope = _context.getInheritedWidgetOfExactType<_FeatureScope>() ??
        (throw StateError('No Follow feature above this context'));
    return _FeatureDiagnostics(scope.definition, scope.notifier!, scope.node)
        .toDiagnosticsNode(name: 'feature');
  }

  RouteData get route => RouteData.of(_context);

  bool get isNavigating => _navigation(listen: true).isNavigating;
  Object? get navigationError => _navigation(listen: true).error;
  StackTrace? get navigationStackTrace =>
      _navigation(listen: true).router.stackTrace;
  Uri? get currentUri => _navigation(listen: true).currentUri;

  Future<void> push(RouteLocation location) =>
      _navigation(listen: false).push(location);
  Future<void> replace(RouteLocation location) =>
      _navigation(listen: false).replace(location);
  Future<void> go(RouteLocation location) =>
      _navigation(listen: false).go(location);
  Future<bool> pop() => _navigation(listen: false).pop();
}
