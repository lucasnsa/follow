import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/follow.dart';
import 'router_test.dart' show MemoryRouteInformationProvider;

class MotionFixture {
  final home = StaticRouteSpec('/');
  final next = StaticRouteSpec('/next');
  final third = StaticRouteSpec('/third');
  final featureRoute = StaticRouteSpec('/feature');
  final detail = StaticRouteSpec('/feature/detail');
  final calls = <String, (Animation<double>, Animation<double>)>{};
  final disposed = <String>[];
  late FollowContext navigation;
  FollowTransition? featureDefault;
  FollowTransition? nextTransition;
  FutureOr<GuardResult> Function()? guard;

  FollowTransition motion(String label) => FollowTransition.custom(
        duration: const Duration(milliseconds: 400),
        reverseDuration: const Duration(milliseconds: 200),
        builder: (_, animation, secondary, child) {
          calls[label] = (animation, secondary);
          return FadeTransition(opacity: animation, child: child);
        },
      );

  late final root = Feature(
    name: 'root',
    pageTransition: featureDefault,
    builder: (context, child) {
      navigation = context.follow;
      return child;
    },
    routes: [
      FeatureRoute.page(home, builder: (_, __) => const Text('home')),
      FeatureRoute.page(next,
          transition: nextTransition,
          guards: [(_, __) => guard?.call() ?? const GuardResult.allow()],
          builder: (_, __) => const Text('next')),
      FeatureRoute.page(third, builder: (_, __) => const Text('third')),
      FeatureRoute.mount(featureRoute,
          transition: motion('mount'),
          feature: (_) => Feature(
                name: 'child',
                bindings: [
                  Bind.value(Token<Object>(), Object(),
                      dispose: (_) => disposed.add('feature'))
                ],
                routes: [
                  FeatureRoute.page(featureRoute,
                      builder: (_, __) => const Text('feature')),
                  FeatureRoute.page(detail,
                      builder: (_, __) => const Text('detail')),
                ],
              )),
    ],
  );

  Widget app(
          {FollowTransition? global,
          RouteInformationProvider? provider,
          ValueNotifier<bool>? reduced}) =>
      FollowApp(
        feature: root,
        pageTransition: global ?? motion('global'),
        routeInformationProvider: provider,
        builder: (_, config) => MaterialApp.router(
          routerConfig: config,
          builder: reduced == null
              ? null
              : (context, child) => ValueListenableBuilder<bool>(
                    valueListenable: reduced,
                    builder: (_, value, __) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(disableAnimations: value),
                        child: child!),
                  ),
        ),
      );
}

Future<void> commit(WidgetTester tester, Future<void> operation) async {
  var completed = false;
  operation.then((_) => completed = true);
  for (var i = 0; !completed && i < 30; i++) {
    await tester.pump();
  }
  expect(completed, isTrue,
      reason: 'Navigation must complete before visual motion');
  await operation;
  await tester.pump();
}

void main() {
  test('transition durations validate and reverse defaults to forward', () {
    final fade =
        FollowTransition.fade(duration: const Duration(milliseconds: 77));
    expect(fade.reverseDuration, fade.duration);
    expect(
        () =>
            FollowTransition.slide(duration: const Duration(milliseconds: -1)),
        throwsArgumentError);
    expect(
        () => BranchTransition.fade(
            reverseDuration: const Duration(milliseconds: -1)),
        throwsArgumentError);
  });

  testWidgets('page motion enters after commit and reverses on pop',
      (tester) async {
    final f = MotionFixture();
    await tester.pumpWidget(f.app());
    await tester.pumpAndSettle();
    expect(f.calls['global']!.$1.value, 1);
    await commit(tester, f.navigation.push(f.next.location));
    expect(f.navigation.currentUri.toString(), '/next');
    expect(ModalRoute.of(tester.element(find.text('next')))!.animation!.value,
        lessThan(1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(ModalRoute.of(tester.element(find.text('next')))!.animation!.value,
        closeTo(.5, .05));
    await tester.pumpAndSettle();
    expect(await f.navigation.pop(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('next'), findsOneWidget);
    expect(ModalRoute.of(tester.element(find.text('next')))!.animation!.value,
        closeTo(.5, .05));
    await tester.pumpAndSettle();
    expect(find.text('next'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets(
      'mount scope survives until exit and child inherits feature default',
      (tester) async {
    final f = MotionFixture();
    f.featureDefault = f.motion('feature-default');
    await tester.pumpWidget(f.app());
    await tester.pumpAndSettle();
    await commit(tester, f.navigation.push(f.featureRoute.location));
    expect(f.calls['mount']!.$1.value, lessThan(1));
    // The first child page is already settled during the mount transition.
    expect(f.calls['feature-default']!.$1.value, 1);
    await tester.pumpAndSettle();
    await commit(tester, f.navigation.push(f.detail.location));
    expect(ModalRoute.of(tester.element(find.text('detail')))!.animation!.value,
        lessThan(1));
    await tester.pumpAndSettle();
    await f.navigation.pop();
    await tester.pumpAndSettle();
    await f.navigation.pop();
    await tester.pump();
    expect(f.disposed, isEmpty);
    await tester.pump(const Duration(milliseconds: 100));
    expect(f.disposed, isEmpty);
    await tester.pumpAndSettle();
    expect(f.disposed, ['feature']);
  });

  testWidgets('replace and go retain outgoing visible page through its exit',
      (tester) async {
    final f = MotionFixture();
    await tester.pumpWidget(f.app());
    await tester.pumpAndSettle();
    await commit(tester, f.navigation.push(f.featureRoute.location));
    await tester.pumpAndSettle();
    await commit(tester, f.navigation.replace(f.next.location));
    expect(f.disposed, isEmpty);
    expect(find.text('feature'), findsOneWidget);
    expect(find.text('next'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(f.disposed, ['feature']);
    await commit(tester, f.navigation.go(f.third.location));
    expect(find.text('next'), findsOneWidget);
    expect(find.text('third'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('next'), findsNothing);
  });

  testWidgets('explicit none overrides feature and global motion',
      (tester) async {
    final f = MotionFixture();
    f.featureDefault = f.motion('feature');
    f.nextTransition = const FollowTransition.none();
    await tester.pumpWidget(f.app());
    await tester.pumpAndSettle();
    f.calls.clear();
    await commit(tester, f.navigation.push(f.next.location));
    await tester.pump();
    expect(find.text('next'), findsOneWidget);
    expect(f.calls.containsKey('global'), isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
      'guards do not begin motion and restoring snapshots settles pages',
      (tester) async {
    final f = MotionFixture();
    final provider = MemoryRouteInformationProvider('/');
    addTearDown(provider.dispose);
    await tester.pumpWidget(f.app(provider: provider));
    await tester.pumpAndSettle();
    final snapshot = provider.value;
    final gate = Completer<GuardResult>();
    f.guard = () => gate.future;
    final pending = f.navigation.push(f.next.location);
    await tester.pumpAndSettle();
    expect(find.text('next'), findsNothing);
    expect(f.navigation.currentUri.toString(), '/');
    gate.complete(const GuardResult.allow());
    await commit(tester, pending);
    await tester.pumpAndSettle();
    provider.restore(snapshot);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('next'), findsNothing);
    expect(f.calls['global']!.$1.value, 1);
  });

  testWidgets(
      'reduced motion skips animations and finishes an active transition',
      (tester) async {
    final f = MotionFixture();
    final reduced = ValueNotifier(false);
    addTearDown(reduced.dispose);
    await tester.pumpWidget(f.app(reduced: reduced));
    await tester.pumpAndSettle();
    await commit(tester, f.navigation.push(f.next.location));
    await tester.pump(const Duration(milliseconds: 100));
    reduced.value = true;
    await tester.pump();
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await commit(tester, f.navigation.push(f.third.location));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('third'), findsOneWidget);
  });
  testWidgets('branch motion coordinates both animations and retains state',
      (tester) async {
    final f = BranchMotionFixture();
    await tester.pumpWidget(f.app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-0')), 'retained');
    await commit(tester, f.controller.goBranch(1));
    expect(f.navigation.currentUri.toString(), '/b1');
    expect(find.text('branch 0'), findsOneWidget);
    expect(find.text('branch 1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    final incoming = f.probe(tester, 1);
    final outgoing = f.probe(tester, 0);
    expect(incoming.primary.value, closeTo(.5, .05));
    expect(incoming.secondary.value, 0);
    expect(outgoing.primary.value, 1);
    expect(outgoing.secondary.value, closeTo(.5, .05));
    expect(tester.testTextInput.hasAnyClients, isFalse);
    await tester.pumpAndSettle();
    expect(find.text('branch 0'), findsNothing);
    await commit(tester, f.controller.goBranch(0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(f.probe(tester, 0).secondary.value, closeTo(.5, .05));
    expect(f.probe(tester, 1).primary.value, closeTo(.5, .05));
    await tester.pumpAndSettle();
    expect(find.text('retained'), findsOneWidget);
    expect(f.created, [0, 1]);
    expect(f.disposed, isEmpty);
  });

  testWidgets('rapid branch switches settle prior motion without remounting',
      (tester) async {
    final f = BranchMotionFixture();
    await tester.pumpWidget(f.app());
    await tester.pumpAndSettle();
    await commit(tester, f.controller.goBranch(1));
    await tester.pump(const Duration(milliseconds: 80));
    await commit(tester, f.controller.goBranch(2));
    expect(find.text('branch 0'), findsNothing);
    expect(find.text('branch 1'), findsOneWidget);
    expect(find.text('branch 2'), findsOneWidget);
    await commit(tester, f.controller.goBranch(0));
    await tester.pumpAndSettle();
    expect(find.text('branch 0'), findsOneWidget);
    expect(f.created, [0, 1, 2]);
    expect(f.disposed, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cross-branch push suppresses page motion while local push animates',
      (tester) async {
    final f = BranchMotionFixture();
    await tester.pumpWidget(f.app());
    await tester.pumpAndSettle();
    await commit(tester, f.navigation.push(f.details[1].location));
    expect(
        ModalRoute.of(tester.element(find.text('detail 1')))!.animation!.value,
        1);
    expect(find.text('branch 0'), findsOneWidget);
    await tester.pumpAndSettle();
    await commit(tester, f.controller.goBranch(0));
    await tester.pumpAndSettle();
    await commit(tester, f.navigation.push(f.details[0].location));
    expect(
        ModalRoute.of(tester.element(find.text('detail 0')))!.animation!.value,
        lessThan(1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'restoration and reduced motion complete shell transitions immediately',
      (tester) async {
    final f = BranchMotionFixture();
    final provider = MemoryRouteInformationProvider('/b0');
    final reduced = ValueNotifier(false);
    addTearDown(provider.dispose);
    addTearDown(reduced.dispose);
    await tester.pumpWidget(f.app(provider: provider, reduced: reduced));
    await tester.pumpAndSettle();
    final initial = provider.value;
    await commit(tester, f.controller.goBranch(1));
    await tester.pump(const Duration(milliseconds: 100));
    reduced.value = true;
    await tester.pump();
    await tester.pump();
    expect(find.text('branch 0'), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
    reduced.value = false;
    await tester.pumpAndSettle();
    provider.restore(initial);
    await tester.pumpAndSettle();
    expect(find.text('branch 0'), findsOneWidget);
    expect(f.probe(tester, 0).primary.value, 1);
    expect(f.probe(tester, 0).secondary.value, 0);
  });

  testWidgets('restoring the current page finishes in-flight page motion',
      (tester) async {
    final f = MotionFixture();
    final provider = MemoryRouteInformationProvider('/');
    addTearDown(provider.dispose);
    await tester.pumpWidget(f.app(provider: provider));
    await tester.pumpAndSettle();
    await commit(tester, f.navigation.push(f.next.location));
    await tester.pump(const Duration(milliseconds: 100));
    final snapshot = provider.value;
    provider.restore(snapshot);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(
        ModalRoute.of(tester.element(find.text('next')))!.animation!.value, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('pop settles branch motion before animating the page exit',
      (tester) async {
    final f = BranchMotionFixture();
    await tester.pumpWidget(f.app());
    await tester.pumpAndSettle();
    await commit(tester, f.controller.goBranch(1));
    await tester.pumpAndSettle();
    await commit(tester, f.navigation.push(f.details[1].location));
    await tester.pumpAndSettle();
    await commit(tester, f.controller.goBranch(0));
    await tester.pumpAndSettle();
    await commit(tester, f.controller.goBranch(1));
    await tester.pump(const Duration(milliseconds: 80));
    expect(await f.navigation.pop(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('branch 0'), findsNothing);
    expect(
        ModalRoute.of(tester.element(find.text('detail 1')))!.animation!.value,
        lessThan(1));
    await tester.pumpAndSettle();
    expect(find.text('branch 1'), findsOneWidget);
  });

  testWidgets('only the outer changed shell animates in nested branches',
      (tester) async {
    final zone = StaticRouteSpec('/zone');
    final a = StaticRouteSpec('/zone/a');
    final b = StaticRouteSpec('/zone/b');
    final other = StaticRouteSpec('/other');
    late FollowContext navigation;
    late FollowShellController outer;
    final motion = BranchTransition.custom(
        duration: const Duration(milliseconds: 400),
        builder: (_, primary, secondary, child) =>
            MotionProbe(primary: primary, secondary: secondary, child: child));
    Feature leaf(StaticRouteSpec spec, String title) => Feature(
        name: title,
        routes: [FeatureRoute.page(spec, builder: (_, __) => Text(title))]);
    final inner = Feature(
        name: 'inner',
        shell: FeatureShell.animated(
            transition: motion,
            branches: [
              FeatureBranch.mount(a,
                  feature: (_) => leaf(a, 'A'), initialLocation: a.location),
              FeatureBranch.mount(b,
                  feature: (_) => leaf(b, 'B'), initialLocation: b.location),
            ],
            builder: (_, __, child) => child));
    final root = Feature(
        name: 'outer',
        shell: FeatureShell.animated(
            transition: motion,
            branches: [
              FeatureBranch.mount(zone,
                  feature: (_) => inner, initialLocation: b.location),
              FeatureBranch.mount(other,
                  feature: (_) => leaf(other, 'other'),
                  initialLocation: other.location),
            ],
            builder: (context, controller, child) {
              navigation = context.follow;
              outer = controller;
              return child;
            }));
    await tester.pumpWidget(FollowApp(
        feature: root,
        initialLocation: '/zone/b',
        builder: (_, config) => MaterialApp.router(routerConfig: config)));
    await tester.pumpAndSettle();
    await commit(tester, outer.goBranch(1));
    await tester.pumpAndSettle();
    await commit(tester, navigation.go(a.location));
    await tester.pump(const Duration(milliseconds: 200));
    final probes = tester.widgetList<MotionProbe>(
        find.ancestor(of: find.text('A'), matching: find.byType(MotionProbe)));
    expect(probes.length, 2);
    expect(
        probes
            .where((p) => p.secondary.value > 0 && p.secondary.value < 1)
            .length,
        1);
    expect(
        probes
            .where((p) => p.primary.value == 1 && p.secondary.value == 0)
            .length,
        1);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('custom branch builders can read animation values directly',
      (tester) async {
    final f = BranchMotionFixture()
      ..custom = (_, primary, secondary, child) =>
          Opacity(opacity: primary.value * (1 - secondary.value), child: child);
    await tester.pumpWidget(f.app());
    await tester.pumpAndSettle();
    await commit(tester, f.controller.goBranch(1));
    await tester.pump(const Duration(milliseconds: 200));
    final opacity = tester.widget<Opacity>(find
        .ancestor(of: find.text('branch 1'), matching: find.byType(Opacity))
        .first);
    expect(opacity.opacity, closeTo(.5, .05));
    await tester.pumpAndSettle();
  });

  testWidgets('Heroes fly within a branch and identical tags are isolated',
      (tester) async {
    final f = BranchMotionFixture();
    await tester.pumpWidget(f.app());
    await tester.pumpAndSettle();
    await commit(tester, f.navigation.push(f.details[0].location));
    await tester.pump(const Duration(milliseconds: 100));
    expect(f.flights, greaterThan(0));
    final flights = f.flights;
    await tester.pumpAndSettle();
    await commit(tester, f.controller.goBranch(1));
    await tester.pumpAndSettle();
    await commit(tester, f.navigation.push(f.details[1].location));
    await tester.pumpAndSettle();
    expect(f.flights, greaterThan(flights));
    expect(tester.takeException(), isNull);
  });
}

class MotionProbe extends StatelessWidget {
  const MotionProbe(
      {required this.primary,
      required this.secondary,
      required this.child,
      super.key});
  final Animation<double> primary;
  final Animation<double> secondary;
  final Widget child;
  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: primary,
      child:
          FadeTransition(opacity: ReverseAnimation(secondary), child: child));
}

class BranchMotionFixture {
  final starts = List.generate(3, (i) => StaticRouteSpec('/b$i'));
  final details = List.generate(3, (i) => StaticRouteSpec('/b$i/detail'));
  final created = <int>[];
  final disposed = <int>[];
  int flights = 0;
  RouteTransitionsBuilder? custom;
  late FollowShellController controller;
  late FollowContext navigation;
  late final feature = Feature(
    name: 'shell',
    pageTransition: FollowTransition.slide(),
    shell: FeatureShell.animated(
      transition: BranchTransition.custom(
          duration: const Duration(milliseconds: 400),
          reverseDuration: const Duration(milliseconds: 200),
          builder: custom ??
              (_, primary, secondary, child) => MotionProbe(
                  primary: primary, secondary: secondary, child: child)),
      branches: [
        for (var i = 0; i < 3; i++)
          FeatureBranch.mount(starts[i], initialLocation: starts[i].location,
              feature: (_) {
            created.add(i);
            return Feature(name: 'b$i', bindings: [
              Bind.value(Token<int>(), i, dispose: disposed.add)
            ], routes: [
              FeatureRoute.page(starts[i],
                  builder: (_, __) => Scaffold(
                          body: Column(children: [
                        Text('branch $i'),
                        TextField(key: ValueKey('note-$i')),
                        Hero(
                            tag: 'shared-tag',
                            flightShuttleBuilder: (_, __, ___, ____, to) {
                              flights++;
                              return (to.widget as Hero).child;
                            },
                            child: const SizedBox(
                                width: 40,
                                height: 40,
                                child: ColoredBox(color: Colors.red))),
                      ]))),
              FeatureRoute.page(details[i],
                  builder: (_, __) => Scaffold(
                          body: Column(children: [
                        Text('detail $i'),
                        const SizedBox(height: 100),
                        Hero(
                            tag: 'shared-tag',
                            flightShuttleBuilder: (_, __, ___, ____, to) {
                              flights++;
                              return (to.widget as Hero).child;
                            },
                            child: const SizedBox(
                                width: 90,
                                height: 90,
                                child: ColoredBox(color: Colors.blue))),
                      ]))),
            ]);
          }),
      ],
      builder: (context, control, child) {
        controller = control;
        navigation = context.follow;
        return child;
      },
    ),
  );

  Widget app(
          {RouteInformationProvider? provider, ValueNotifier<bool>? reduced}) =>
      FollowApp(
        feature: feature,
        routeInformationProvider: provider,
        initialLocation: provider == null ? '/b0' : null,
        builder: (_, config) => MaterialApp.router(
            routerConfig: config,
            builder: reduced == null
                ? null
                : (context, child) => ValueListenableBuilder<bool>(
                      valueListenable: reduced,
                      builder: (_, value, __) => MediaQuery(
                          data: MediaQuery.of(context)
                              .copyWith(disableAnimations: value),
                          child: child!),
                    )),
      );

  MotionProbe probe(WidgetTester tester, int index) =>
      tester.widget<MotionProbe>(find
          .ancestor(
              of: find.text('branch $index'),
              matching: find.byType(MotionProbe))
          .first);
}
