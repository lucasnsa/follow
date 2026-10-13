import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/follow.dart';

class A {
  A(this.value);
  final Object value;
}

class B {
  B(this.value);
  final Object value;
}

final stringToken = Token<String>('string');
final intToken = Token<int>('int');
final aToken = Token<A>('a');
final bToken = Token<B>('b');

Feature feature({
  String name = 'test',
  List<BindingDeclaration> bindings = const [],
  FeatureBuilder? builder,
  Map<String, Object?> diagnostics = const {},
}) =>
    Feature(
      name: name,
      bindings: bindings,
      builder: builder,
      diagnostics: diagnostics,
    );

Widget capture(
  Feature feature,
  void Function(FollowContext) use, {
  Key? key,
  Widget? child,
}) =>
    FeatureScope(
      key: key,
      feature: feature,
      child: Builder(builder: (context) {
        use(context.follow);
        return child ?? const SizedBox();
      }),
    );

void main() {
  testWidgets('blocking ancestors participate in child feature state',
      (tester) async {
    final rootValue = Completer<String>();
    late FollowContext root, child;
    await tester.pumpWidget(capture(
      feature(bindings: [
        Bind.async(stringToken, (_) => rootValue.future),
      ]),
      (access) => root = access,
      child: capture(
        feature(bindings: [
          Bind.async(aToken, (read) async => A(await read.async(stringToken))),
        ]),
        (access) => child = access,
      ),
    ));

    expect(root.featureState, isA<FeatureInitializing>());
    expect(child.featureState, isA<FeatureInitializing>());
    rootValue.complete('shared');
    await tester.pumpAndSettle();
    expect(root.featureState, isA<FeatureReady>());
    expect(child.featureState, isA<FeatureReady>());
    expect(child.read(aToken).value, 'shared');
  });

  testWidgets('tokens resolve locally, through ancestors and as factories',
      (tester) async {
    late FollowContext root, child, sibling;
    final secondStringToken = Token<String>('string');
    var factoryCalls = 0;
    await tester.pumpWidget(capture(
      feature(bindings: [
        Bind.value(stringToken, 'root'),
        Bind.value(secondStringToken, 'qualified'),
        Bind.factory(
            aToken, (read) => A('${read(stringToken)}:${++factoryCalls}')),
      ]),
      (access) => root = access,
      child: Row(textDirection: TextDirection.ltr, children: [
        capture(
          feature(bindings: [Bind.value(stringToken, 'child')]),
          (access) => child = access,
        ),
        capture(feature(), (access) => sibling = access),
      ]),
    ));

    expect(root.read(stringToken), 'root');
    expect(root.read(secondStringToken), 'qualified');
    expect(child.read(stringToken), 'child');
    expect(sibling.read(stringToken), 'root');
    expect(child.read(aToken).value, 'root:1');
    expect(child.read(aToken).value, 'root:2');
  });

  testWidgets('lazy async state is observable and creation is shared',
      (tester) async {
    final completion = Completer<String>();
    late FollowContext access;
    var calls = 0;
    await tester.pumpWidget(capture(
      feature(bindings: [
        Bind.async(
          stringToken,
          (_) {
            calls++;
            return completion.future;
          },
          policy: AsyncPolicy.lazy,
        ),
      ]),
      (value) => access = value,
    ));

    expect(access.featureState, isA<FeatureReady>());
    expect(access.watch(stringToken), isA<DependencyLoading<String>>());
    final first = access.readAsync(stringToken);
    final second = access.readAsync(stringToken);
    expect(calls, 1);
    completion.complete('done');
    await tester.pumpAndSettle();
    expect(await first, 'done');
    expect(await second, 'done');
    expect(access.watch(stringToken), isA<DependencyReady<String>>());
    expect(access.read(stringToken), 'done');
  });

  testWidgets('background failures do not fail feature readiness',
      (tester) async {
    late FollowContext access;
    await tester.pumpWidget(capture(
      feature(bindings: [
        Bind.async(
          stringToken,
          (_) async => throw StateError('background'),
          policy: AsyncPolicy.background,
        ),
      ]),
      (value) => access = value,
    ));
    await tester.pumpAndSettle();
    expect(access.featureState, isA<FeatureReady>());
    expect(access.watch(stringToken), isA<DependencyFailed<String>>());
  });

  testWidgets('disposal is reverse creation order and ignores unused lazy',
      (tester) async {
    final disposed = <String>[];
    late FollowContext access;
    await tester.pumpWidget(capture(
      feature(bindings: [
        Bind.value(stringToken, 'value', dispose: disposed.add),
        Bind.singleton(aToken, (read) => A(read(stringToken)),
            dispose: (_) => disposed.add('A')),
        Bind.singleton(bToken, (_) => B(1),
            activation: Activation.lazy,
            dispose: (_) => disposed.add('unused')),
      ]),
      (value) => access = value,
    ));
    expect(access.read(aToken).value, 'value');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(disposed, ['A', 'value']);
  });

  testWidgets('pending async result is released after unmount', (tester) async {
    final completion = Completer<String>();
    final disposed = <String>[];
    late Future<void> ready;
    await tester.pumpWidget(capture(
      feature(bindings: [
        Bind.async(stringToken, (_) => completion.future,
            dispose: disposed.add),
      ]),
      (value) => ready = value.ready,
    ));
    final readiness = expectLater(ready, throwsStateError);
    await tester.pumpWidget(const SizedBox());
    await readiness;
    completion.complete('late');
    await tester.pump();
    expect(disposed, ['late']);
  });

  testWidgets('cycles, duplicates and watched factories fail clearly',
      (tester) async {
    late FollowContext access;
    await tester.pumpWidget(capture(
      feature(bindings: [
        Bind.singleton(aToken, (read) => A(read(bToken))),
        Bind.singleton(bToken, (read) => B(read(aToken))),
      ]),
      (value) => access = value,
    ));
    expect(access.featureState, isA<FeatureFailed>());
    final failed = access.featureState as FeatureFailed;
    expect(failed.error.toString(), contains('Circular dependency'));

    await tester.pumpWidget(capture(
      feature(bindings: [
        Bind.value(intToken, 1),
        Bind.value(intToken, 2),
      ]),
      (_) {},
      key: const ValueKey('duplicate'),
    ));
    expect(tester.takeException().toString(), contains('Duplicate binding'));

    await tester.pumpWidget(capture(
      feature(bindings: [Bind.factory(aToken, (_) => A(1))]),
      (value) => access = value,
      key: const ValueKey('factory'),
    ));
    expect(() => access.watch(aToken), throwsStateError);
  });

  testWidgets('scope survives rebuild and a new key recreates it',
      (tester) async {
    late FollowContext access;
    final disposed = <String>[];
    Widget tree(String key, String value) => capture(
          feature(bindings: [
            Bind.value(stringToken, value, dispose: disposed.add),
            Bind.singleton(aToken, (read) => A(read(stringToken))),
          ]),
          (next) => access = next,
          key: ValueKey(key),
        );

    await tester.pumpWidget(tree('one', 'original'));
    final original = access.read(aToken);
    await tester.pumpWidget(tree('one', 'ignored'));
    expect(access.read(aToken), same(original));
    expect(access.read(stringToken), 'original');
    await tester.pumpWidget(tree('two', 'replacement'));
    await tester.pump();
    expect(access.read(stringToken), 'replacement');
    expect(disposed, ['original']);
  });

  testWidgets('feature builder wraps a manual subtree', (tester) async {
    await tester.pumpWidget(FeatureScope(
      feature: feature(
        builder: (_, child) => Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [const Text('builder'), child]),
        ),
      ),
      child: const Text('content'),
    ));
    expect(find.text('builder'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('watch safely activates a synchronous lazy during build',
      (tester) async {
    var creations = 0;
    await tester.pumpWidget(FeatureScope(
      feature: feature(bindings: [
        Bind.singleton(
          stringToken,
          (_) => 'created ${++creations}',
          activation: Activation.lazy,
        ),
      ]),
      child: Builder(builder: (context) {
        return switch (context.follow.watch(stringToken)) {
          DependencyReady(:final value) =>
            Text(value, textDirection: TextDirection.ltr),
          _ => const SizedBox(),
        };
      }),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('created 1'), findsOneWidget);
    expect(creations, 1);
  });

  testWidgets('diagnostics expose feature, tokens and lazy state safely',
      (tester) async {
    var lazyCreations = 0;
    late FollowContext access;
    final checkout = feature(
      name: 'checkout',
      diagnostics: const {'environment': 'test'},
      bindings: [
        Bind.value(intToken, 1),
        Bind.singleton(
          stringToken,
          (_) {
            lazyCreations++;
            return 'lazy';
          },
          activation: Activation.lazy,
        ),
      ],
    );
    await tester.pumpWidget(capture(checkout, (value) => access = value));

    final diagnostics = access.debugDiagnostics;
    final before = diagnostics.toStringDeep();
    expect(before, contains('name: "checkout"'));
    expect(before, contains('environment: test'));
    expect(before, contains('bindings: 2'));
    expect(before, contains('Token<String>(string)'));
    expect(before, contains('idle'));
    expect(lazyCreations, 0);

    Element? inspectorScope;
    void findScope(Element element) {
      if (element.widget.toStringShort() == 'FollowFeatureScope<checkout>') {
        inspectorScope = element;
        return;
      }
      element.visitChildren(findScope);
    }

    findScope(tester.binding.rootElement!);
    expect(inspectorScope, isNotNull);
    expect(inspectorScope!.widget.toStringDeep(), contains('bindings: 2'));

    expect(access.read(stringToken), 'lazy');
    expect(diagnostics.toStringDeep(), contains('state: ready'));
    expect(lazyCreations, 1);
    expect(checkout.debugDiagnostics.toStringDeep(), contains('environment'));
    expect(checkout.debugDiagnostics.toStringDeep(), contains('bindings: 2'));
  });
}
