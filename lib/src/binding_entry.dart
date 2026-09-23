part of '../follow.dart';

class _Entry {
  _Entry(this.owner, this.binding);

  final _FeatureAccess owner;
  final Binding<dynamic> binding;
  final Set<_Entry> dependencies = {};
  Object? instance;
  Object? failure;
  StackTrace? failureStack;
  Future<Object>? pending;
  bool creating = false;

  bool _reaches(_Entry target, Set<_Entry> visited) =>
      identical(this, target) ||
      (visited.add(this) &&
          dependencies.any((entry) => entry._reaches(target, visited)));

  void dependOn(_Entry entry) {
    if (entry._reaches(this, {})) {
      throw StateError(
        'Circular dependency: ${binding.token} -> ${entry.binding.token}',
      );
    }
    dependencies.add(entry);
  }

  void _remember(Object value) {
    instance = value;
    if (owner._closed) {
      unawaited(owner._release(this));
    } else {
      owner._created.add(this);
      owner._changed();
    }
  }

  Object getSync() {
    owner._checkOpen();
    if (instance != null) return instance!;
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
    if (binding._isAsync) {
      throw StateError(
        '${binding.token} is not ready; use readAsync or watch',
      );
    }
    if (creating) throw StateError('Circular dependency: ${binding.token}');
    creating = true;
    try {
      final value = binding._create(_Resolution(this)) as Object;
      if (!binding._isFactory) _remember(value);
      return value;
    } catch (error, stack) {
      if (!binding._isFactory) {
        failure = error;
        failureStack = stack;
        owner._changed();
      }
      rethrow;
    } finally {
      creating = false;
    }
  }

  Future<Object> getAsync() {
    owner._checkOpen();
    if (!binding._isAsync) return Future.sync(getSync);
    if (instance != null) return Future.value(instance!);
    if (failure != null) {
      return Future.error(failure!, failureStack);
    }
    return pending ??= Future<Object>.sync(
      () async => await binding._create(_Resolution(this)) as Object,
    ).then((value) {
      _remember(value);
      return value;
    }, onError: (Object error, StackTrace stack) {
      failure = error;
      failureStack = stack;
      owner._changed();
      Error.throwWithStackTrace(error, stack);
    });
  }
}

class _Resolution implements Read {
  _Resolution(this.source);
  final _Entry source;

  _Entry _find(TokenKey token) {
    final entry = source.owner._find(token);
    source.dependOn(entry);
    return entry;
  }

  @override
  T call<T extends Object>(Token<T> token) => _find(token).getSync() as T;

  @override
  Future<T> async<T extends Object>(Token<T> token) async =>
      await _find(token).getAsync() as T;
}
