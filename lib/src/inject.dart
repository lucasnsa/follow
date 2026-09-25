part of '../follow.dart';

/// Common runtime identity for heterogeneous token collections.
sealed class TokenKey extends DiagnosticableTree {
  const TokenKey();
  String get name;
}

/// A stable, typed identity for one dependency.
///
/// Unnamed tokens identify the default dependency for the exact type [T].
/// Named tokens use identity equality: reuse the same instance when registering
/// and reading a named dependency.
final class Token<T extends Object> extends TokenKey {
  Token([String? name]) : _name = name;

  final String? _name;
  Type get _type => T;

  @override
  String get name => _name ?? T.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (_name == null &&
          other is Token &&
          other._name == null &&
          _type == other._type);

  @override
  int get hashCode => _name == null ? _type.hashCode : identityHashCode(this);

  @override
  String toStringShort() => 'Token<$T>(${_name ?? ''})';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('name', name));
    properties.add(StringProperty('type', T.toString(), quoted: false));
  }
}

/// Reads dependencies while another dependency is being created.
abstract interface class Read {
  /// Reads [token], or the default dependency for the exact type [T].
  T call<T extends Object>([Token<T>? token]);

  /// Resolves [token], or the default dependency for the exact type [T].
  Future<T> async<T extends Object>([Token<T>? token]);
}

enum Activation { eager, lazy }

/// Controls startup and readiness participation for asynchronous bindings.
enum AsyncPolicy { blocking, background, lazy }

/// Common non-generic type used by heterogeneous feature binding lists.
sealed class BindingDeclaration {
  const BindingDeclaration();
}

/// Immutable, typed description of one dependency binding.
sealed class Binding<T extends Object> extends BindingDeclaration {
  const Binding(this.token, this.dispose);

  final Token<T> token;
  final FutureOr<void> Function(T value)? dispose;

  String get _kind;
  bool get _isFactory => false;
  bool get _isAsync => false;
  bool get _startsEagerly => true;
  bool get _blocksReadiness => false;
  FutureOr<T> _create(Read read);
  FutureOr<void> _release(Object value) => dispose?.call(value as T);
}

final class _ValueBinding<T extends Object> extends Binding<T> {
  const _ValueBinding(super.token, this.value, super.dispose);
  final T value;
  @override
  String get _kind => 'value';
  @override
  T _create(Read read) => value;
}

final class _FactoryBinding<T extends Object> extends Binding<T> {
  const _FactoryBinding(Token<T> token, this.create) : super(token, null);
  final T Function(Read read) create;
  @override
  String get _kind => 'factory';
  @override
  bool get _isFactory => true;
  @override
  bool get _startsEagerly => false;
  @override
  T _create(Read read) => create(read);
}

final class _SingletonBinding<T extends Object> extends Binding<T> {
  const _SingletonBinding(
    super.token,
    this.create,
    this.activation,
    super.dispose,
  );
  final T Function(Read read) create;
  final Activation activation;
  @override
  String get _kind => activation == Activation.eager ? 'singleton' : 'lazy';
  @override
  bool get _startsEagerly => activation == Activation.eager;
  @override
  T _create(Read read) => create(read);
}

final class _AsyncBinding<T extends Object> extends Binding<T> {
  const _AsyncBinding(super.token, this.create, this.policy, super.dispose);
  final Future<T> Function(Read read) create;
  final AsyncPolicy policy;
  @override
  String get _kind => 'async.${policy.name}';
  @override
  bool get _isAsync => true;
  @override
  bool get _startsEagerly => policy != AsyncPolicy.lazy;
  @override
  bool get _blocksReadiness => policy == AsyncPolicy.blocking;
  @override
  Future<T> _create(Read read) => create(read);
}

/// Constructors for immutable [Binding] declarations.
abstract final class Bind {
  static Binding<T> value<T extends Object>(
    Token<T> token,
    T value, {
    FutureOr<void> Function(T value)? dispose,
  }) =>
      _ValueBinding(token, value, dispose);

  static Binding<T> factory<T extends Object>(
    Token<T> token,
    T Function(Read read) create,
  ) =>
      _FactoryBinding(token, create);

  static Binding<T> singleton<T extends Object>(
    Token<T> token,
    T Function(Read read) create, {
    Activation activation = Activation.eager,
    FutureOr<void> Function(T value)? dispose,
  }) =>
      _SingletonBinding(token, create, activation, dispose);

  static Binding<T> async<T extends Object>(
    Token<T> token,
    Future<T> Function(Read read) create, {
    AsyncPolicy policy = AsyncPolicy.blocking,
    FutureOr<void> Function(T value)? dispose,
  }) =>
      _AsyncBinding(token, create, policy, dispose);
}

/// Observable initialization state of the active feature chain.
sealed class FeatureState {
  const FeatureState();
}

final class FeatureInitializing extends FeatureState {
  const FeatureInitializing(this.pending);
  final List<TokenKey> pending;
}

final class FeatureReady extends FeatureState {
  const FeatureReady();
}

final class FeatureFailed extends FeatureState {
  const FeatureFailed(this.error, this.stackTrace);
  final Object error;
  final StackTrace stackTrace;
}

/// Observable state of one stored dependency.
sealed class DependencyState<T extends Object> {
  const DependencyState();
}

final class DependencyIdle<T extends Object> extends DependencyState<T> {
  const DependencyIdle();
}

final class DependencyLoading<T extends Object> extends DependencyState<T> {
  const DependencyLoading();
}

final class DependencyReady<T extends Object> extends DependencyState<T> {
  const DependencyReady(this.value);
  final T value;
}

final class DependencyFailed<T extends Object> extends DependencyState<T> {
  const DependencyFailed(this.error, this.stackTrace);
  final Object error;
  final StackTrace stackTrace;
}
