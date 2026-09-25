import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/follow.dart';

// Unlike pumpWidget, build the application synchronously while the scheduler
// is idle, as runApp's initial root attachment can do.
void mountWhileIdle(WidgetTester tester, Widget child) {
  final binding = tester.binding;
  expect(binding.schedulerPhase, SchedulerPhase.idle);
  binding.attachRootWidget(binding.wrapWithDefaultView(child));
  binding.buildOwner!.buildScope(binding.rootElement!);
}

void main() {
  testWidgets('initial routing can notify safely during an idle build',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    final home = StaticRouteSpec('/');
    final next = StaticRouteSpec('/next');
    late FollowContext follow;
    mountWhileIdle(
      tester,
      FollowApp(
        feature: Feature(name: 'root', routes: [
          FeatureRoute.page(home, builder: (context, _) {
            follow = context.follow;
            return const Text('home');
          }),
          FeatureRoute.page(next, builder: (_, __) => const Text('next')),
        ]),
        initialLocation: '/',
        builder: (_, config) => MaterialApp.router(routerConfig: config),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(follow.isNavigating, isFalse);
    final navigation = follow.go(next.location);
    await tester.pumpAndSettle();
    await navigation;
    expect(find.text('next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final disposeBeforeFlush in [false, true]) {
    testWidgets(
        'lazy activation during idle build, dispose=$disposeBeforeFlush',
        (tester) async {
      await tester.pumpWidget(const SizedBox());
      final value = Token<int>('value');
      var creations = 0;
      var disposals = 0;
      mountWhileIdle(
        tester,
        FeatureScope(
          feature: Feature(name: 'lazy', bindings: [
            Bind.singleton(value, (_) => ++creations,
                activation: Activation.lazy, dispose: (_) => disposals++),
          ]),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(builder: (context) {
              final state = context.follow.watch(value);
              return Text(state is DependencyReady<int>
                  ? 'value:${state.value}'
                  : 'pending');
            }),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      if (disposeBeforeFlush) {
        mountWhileIdle(tester, const SizedBox());
        tester.binding.buildOwner!.finalizeTree();
      }
      await tester.pumpAndSettle();
      expect(creations, 1);
      expect(disposals, disposeBeforeFlush ? 1 : 0);
      if (!disposeBeforeFlush) {
        expect(find.text('value:1'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
