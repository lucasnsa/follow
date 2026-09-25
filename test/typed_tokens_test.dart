import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/follow.dart';

class Service {
  Service(this.value);
  final Object value;
}

class SpecialService extends Service {
  SpecialService(super.value);
}

class Repository {
  Repository(this.service);
  final Service service;
}

Widget scope(
  List<BindingDeclaration> bindings,
  void Function(FollowContext) capture, {
  Widget? child,
  Key? key,
}) =>
    FeatureScope(
      key: key,
      feature: Feature(name: 'typed', bindings: bindings),
      child: Builder(builder: (context) {
        capture(context.follow);
        return child ?? const SizedBox();
      }),
    );

void main() {
  test('unnamed keys use exact types; named keys retain identity', () {
    final first = Token<Service>();
    final second = Token<Service>();
    final named = Token<Service>('service');
    expect(first, second);
    expect(identical(first, second), isFalse);
    expect(first.hashCode, second.hashCode);
    expect(first.name, 'Service');
    expect(first.toStringShort(), 'Token<Service>()');
    expect(named.toStringShort(), 'Token<Service>(service)');
    expect(named, same(named));
    expect(named, isNot(Token<Service>('service')));
    expect(named, isNot(first));
    expect(first, isNot(named));
    expect(first, isNot(Token<SpecialService>()));
    expect(Token<List<int>>(), isNot(Token<List<num>>()));
    expect(Token<Object>(), isNot(Token<num>()));
    expect(Token<String>(''), isNot(Token<String>()));
    final keys = <TokenKey>{first, second, named, Token<Service>('service')};
    expect(keys.length, 3);
  });

  testWidgets('bindings and widgets read defaults alongside named instances',
      (tester) async {
    final named = Token<Service>('other');
    final sameName = Token<Service>('other');
    late FollowContext access;
    await tester.pumpWidget(scope([
      Bind.singleton(Token<Service>(), (_) => Service('default')),
      Bind.singleton(
          Token<Repository>(), (read) => Repository(read<Service>())),
      Bind.value(named, Service('named')),
      Bind.value(sameName, Service('same name')),
    ], (value) => access = value));
    expect(access.read<Repository>().service, same(access.read<Service>()));
    expect(access.read(Token<Service>()), same(access.read<Service>()));
    expect(access.read<Service>().value, 'default');
    expect(access.read(named).value, 'named');
    expect(access.read(sameName).value, 'same name');
    expect(() => access.read(Token<Service>('other')), throwsStateError);
    expect(
        access.debugDiagnostics.toStringDeep(), contains('Token<Service>()'));
  });

  testWidgets(
      'nearest default wins without leaking into siblings or parent factories',
      (tester) async {
    late FollowContext root, child, sibling;
    await tester.pumpWidget(scope(
      [
        Bind.value(Token<String>(), 'root'),
        Bind.factory(Token<Service>(), (read) => Service(read<String>())),
      ],
      (value) => root = value,
      child: Row(textDirection: TextDirection.ltr, children: [
        scope([Bind.value(Token<String>(), 'child')], (value) => child = value),
        scope([], (value) => sibling = value),
      ]),
    ));
    expect(root.read<String>(), 'root');
    expect(child.read<String>(), 'child');
    expect(sibling.read<String>(), 'root');
    expect(child.read<Service>().value, 'root');
    expect(child.read<Service>(), isNot(same(child.read<Service>())));
    expect(() => child.watch<Service>(), throwsStateError);
  });

  testWidgets('lookup is exact and never falls back to named bindings',
      (tester) async {
    final named = Token<Service>('only');
    late FollowContext access;
    await tester.pumpWidget(scope([
      Bind.value(named, Service('named')),
      Bind.value(Token<SpecialService>(), SpecialService('subtype')),
      Bind.value(Token<List<int>>(), [1]),
      Bind.value(Token<List<String>>(), ['one']),
    ], (value) => access = value));
    expect(access.read<List<int>>(), [1]);
    expect(access.read<List<String>>(), ['one']);
    expect(() => access.read<List<num>>(), throwsStateError);
    expect(() => access.read<Service>(), throwsStateError);
    expect(() => access.watch<Service>(), throwsStateError);
    await expectLater(access.readAsync<Service>(), throwsStateError);
    expect(access.read(named).value, 'named');
  });

  testWidgets('child named binding does not shadow an ancestor default',
      (tester) async {
    late FollowContext child;
    final named = Token<String>('child');
    await tester.pumpWidget(scope(
      [Bind.value(Token<String>(), 'root')],
      (_) {},
      child: scope([Bind.value(named, 'named')], (value) => child = value),
    ));
    expect(child.read<String>(), 'root');
    expect(child.read(named), 'named');
  });

  testWidgets('duplicate unnamed bindings fail on mounting', (tester) async {
    await tester.pumpWidget(scope([
      Bind.value(Token<String>(), 'one'),
      Bind.value(Token<String>(), 'two'),
    ], (_) {}));
    expect(tester.takeException().toString(),
        contains('Duplicate binding: Token<String>()'));
  });

  testWidgets(
      'typed watch starts lazy async and shares the result with readAsync',
      (tester) async {
    final completion = Completer<Service>();
    var calls = 0;
    late FollowContext access;
    await tester.pumpWidget(scope(
      [
        Bind.async(Token<Service>(), (_) {
          calls++;
          return completion.future;
        }, policy: AsyncPolicy.lazy),
      ],
      (value) => access = value,
      child: Builder(
          builder: (context) => Text(
                switch (context.follow.watch<Service>()) {
                  DependencyReady(:final value) => '${value.value}',
                  _ => 'loading',
                },
                textDirection: TextDirection.ltr,
              )),
    ));
    expect(find.text('loading'), findsOneWidget);
    expect(access.featureState, isA<FeatureReady>());
    expect(() => access.read<Service>(), throwsStateError);
    final first = access.readAsync<Service>();
    final second = access.readAsync(Token<Service>());
    expect(calls, 1);
    final service = Service('done');
    completion.complete(service);
    await tester.pumpAndSettle();
    expect(await first, same(service));
    expect(await second, same(service));
    expect(access.read<Service>(), same(service));
    expect(find.text('done'), findsOneWidget);
  });

  testWidgets('typed Read.async resolves blocking ancestors in factories',
      (tester) async {
    final completion = Completer<Service>();
    late FollowContext child;
    await tester.pumpWidget(scope([
      Bind.async(Token<Service>(), (_) => completion.future),
    ], (_) {},
        child: scope([
          Bind.async(Token<Repository>(),
              (read) async => Repository(await read.async<Service>())),
        ], (value) => child = value)));
    expect(child.featureState, isA<FeatureInitializing>());
    final service = Service('ready');
    completion.complete(service);
    await tester.pumpAndSettle();
    expect(child.featureState, isA<FeatureReady>());
    expect(child.read<Repository>().service, same(service));
  });

  testWidgets(
      'typed background failures remain observable without blocking readiness',
      (tester) async {
    late FollowContext access;
    await tester.pumpWidget(scope([
      Bind.async(Token<Service>(), (_) async => throw StateError('failure'),
          policy: AsyncPolicy.background),
    ], (value) => access = value));
    await tester.pumpAndSettle();
    expect(access.featureState, isA<FeatureReady>());
    expect(access.watch<Service>(), isA<DependencyFailed<Service>>());
  });

  for (final asyncCycle in [false, true]) {
    testWidgets('typed ${asyncCycle ? 'async' : 'sync'} cycles are detected',
        (tester) async {
      late FollowContext access;
      await tester.pumpWidget(scope(
          asyncCycle
              ? [
                  Bind.async(Token<Service>(),
                      (read) async => Service(await read.async<Repository>())),
                  Bind.async(Token<Repository>(),
                      (read) async => Repository(await read.async<Service>())),
                ]
              : [
                  Bind.singleton(
                      Token<Service>(), (read) => Service(read<Repository>())),
                  Bind.singleton(Token<Repository>(),
                      (read) => Repository(read<Service>())),
                ],
          (value) => access = value));
      await tester.pumpAndSettle();
      expect(access.featureState, isA<FeatureFailed>());
      expect((access.featureState as FeatureFailed).error.toString(),
          contains('Circular dependency'));
    });
  }

  testWidgets('typed dependencies are disposed once in reverse creation order',
      (tester) async {
    final disposed = <String>[];
    late FollowContext access;
    await tester.pumpWidget(scope([
      // Declared first so resolving the dependency must establish creation order.
      Bind.singleton(Token<Repository>(), (read) => Repository(read<Service>()),
          dispose: (_) => disposed.add('repository')),
      Bind.singleton(Token<Service>(), (_) => Service('shared'),
          dispose: (_) => disposed.add('service')),
      Bind.singleton(Token<String>(), (_) => 'unused',
          activation: Activation.lazy, dispose: (_) => disposed.add('unused')),
    ], (value) => access = value));
    expect(
        access.read<Repository>().service, same(access.read(Token<Service>())));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(disposed, ['repository', 'service']);
  });
}
