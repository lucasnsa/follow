part of '../follow.dart';

class _FeatureAccess extends ChangeNotifier implements Read {
  _FeatureAccess(List<BindingDeclaration> bindings, this._parent) {
    for (final declaration in bindings) {
      final binding = declaration as Binding<dynamic>;
      if (_entries.containsKey(binding.token)) {
        throw StateError('Duplicate binding: ${binding.token}');
      }
      _entries[binding.token] = _Entry(this, binding);
    }
    _parent?.addListener(_parentChanged);
    unawaited(ready.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    _start();
  }

  final _FeatureAccess? _parent;
  final Map<TokenKey, _Entry> _entries = {};
  final List<_Entry> _created = [];
  final Completer<void> _ready = Completer<void>();
  bool _closed = false;
  bool _notificationScheduled = false;
  Object? _error;
  StackTrace? _stackTrace;

  Future<void> get ready => _ready.future;

  FeatureState get state {
    final parentState = _parent?.state;
    if (parentState case FeatureFailed()) return parentState;
    if (_error != null) return FeatureFailed(_error!, _stackTrace!);
    for (final entry in _entries.values) {
      if (entry.binding._blocksReadiness && entry.failure != null) {
        return FeatureFailed(entry.failure!, entry.failureStack!);
      }
    }
    final pending = <TokenKey>[
      if (parentState case FeatureInitializing(:final pending)) ...pending,
      for (final entry in _entries.values)
        if (entry.binding._blocksReadiness &&
            entry.instance == null &&
            entry.failure == null)
          entry.binding.token,
    ];
    return pending.isEmpty
        ? const FeatureReady()
        : FeatureInitializing(List.unmodifiable(pending));
  }

  void _parentChanged() => _changed();

  void _changed() {
    if (_closed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      if (_notificationScheduled) return;
      _notificationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notificationScheduled = false;
        if (!_closed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  void _checkOpen() {
    if (_closed) throw StateError('Feature has been disposed');
  }

  _Entry _find(TokenKey token) {
    _checkOpen();
    return _entries[token] ??
        _parent?._find(token) ??
        (throw StateError('Dependency $token is not registered'));
  }

  @override
  T call<T extends Object>(Token<T> token) => _find(token).getSync() as T;

  @override
  Future<T> async<T extends Object>(Token<T> token) async =>
      await _find(token).getAsync() as T;

  DependencyState<T> watch<T extends Object>(Token<T> token) {
    final entry = _find(token);
    if (entry.binding._isFactory) {
      throw StateError('Factory $token cannot be watched; use read instead');
    }
    if (entry.instance == null &&
        entry.failure == null &&
        entry.pending == null) {
      if (entry.binding._isAsync) {
        unawaited(entry.getAsync().then<void>(
              (_) {},
              onError: (Object _, StackTrace __) {},
            ));
      } else {
        try {
          entry.getSync();
        } catch (_) {
          // The state below carries the original error and stack trace.
        }
      }
    }
    if (entry.failure != null) {
      return DependencyFailed<T>(entry.failure!, entry.failureStack!);
    }
    if (entry.instance != null) {
      return DependencyReady<T>(entry.instance! as T);
    }
    if (entry.pending != null) return DependencyLoading<T>();
    return DependencyIdle<T>();
  }

  void _start() {
    final blocking = <Future<Object>>[];
    try {
      for (final entry in _entries.values) {
        if (!entry.binding._startsEagerly) continue;
        if (entry.binding._isAsync) {
          final future = entry.getAsync();
          if (entry.binding._blocksReadiness) {
            blocking.add(future);
          } else {
            unawaited(future.then<void>(
              (_) {},
              onError: (Object _, StackTrace __) {},
            ));
          }
        } else {
          entry.getSync();
        }
      }
    } catch (error, stack) {
      _fail(error, stack);
      return;
    }

    unawaited(() async {
      try {
        if (_parent != null) await _parent.ready;
        await Future.wait(blocking, eagerError: true);
        if (!_closed && !_ready.isCompleted) {
          _ready.complete();
          _changed();
        }
      } catch (error, stack) {
        _fail(error, stack);
      }
    }());
  }

  void _fail(Object error, StackTrace stack) {
    if (_closed || _ready.isCompleted) return;
    _error = error;
    _stackTrace = stack;
    _ready.completeError(error, stack);
    _changed();
  }

  Future<void> _release(_Entry entry) async {
    try {
      await entry.binding._release(entry.instance!);
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'follow',
        context: ErrorDescription('while disposing ${entry.binding.token}'),
      ));
    }
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _parent?.removeListener(_parentChanged);
    if (!_ready.isCompleted) {
      _ready.completeError(StateError('Feature disposed before ready'));
    }
    final entries = _created.reversed.toList();
    _created.clear();
    unawaited(() async {
      for (final entry in entries) {
        await _release(entry);
      }
    }());
    super.dispose();
  }
}
