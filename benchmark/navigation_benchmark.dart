// Run explicitly: flutter test benchmark/navigation_benchmark.dart --no-pub
// End-to-end debug/widget-test timings; not profile-mode frame timings.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/follow.dart';

void main() {
  for (final size in [10, 100, 1000]) {
    for (final depth in [0, 3]) {
      testWidgets('navigation routes=$size depth=$depth', (tester) async {
        late FollowContext navigation;
        final prefix = List.generate(depth, (i) => '/level$i').join();
        final specs =
            List.generate(size, (i) => StaticRouteSpec('$prefix/item$i'));
        Feature tree = Feature(name: 'leaf', routes: [
          for (final spec in specs)
            FeatureRoute.page(spec, builder: (_, __) => const SizedBox()),
        ]);
        for (var level = depth - 1; level >= 0; level--) {
          final child = tree;
          final path = List.generate(level + 1, (i) => '/level$i').join();
          tree = Feature(name: 'level$level', routes: [
            FeatureRoute.mount(StaticRouteSpec(path), feature: (_) => child),
          ]);
        }
        final root = Feature(
          name: 'root',
          routes: tree.routes,
          builder: (context, outlet) {
            navigation = context.follow;
            return outlet;
          },
        );
        await tester.pumpWidget(FollowApp(
          feature: root,
          initialLocation: specs.first.path,
          builder: (_, config) => MaterialApp.router(routerConfig: config),
        ));
        await tester.pumpAndSettle();

        Future<void> run(int count) async {
          for (var i = 0; i < count; i++) {
            final pending = navigation.go(specs[(i * 37 + 1) % size].location);
            await tester.pumpAndSettle();
            await pending;
          }
        }

        await run(20);
        final samples = <int>[];
        for (var trial = 0; trial < 5; trial++) {
          final watch = Stopwatch()..start();
          await run(40);
          watch.stop();
          samples.add(watch.elapsedMicroseconds);
        }
        samples.sort();
        // ignore: avoid_print
        print('BENCH routes=$size depth=$depth '
            'median_us_per_go=${samples[2] / 40} samples_us=$samples');
        expect(navigation.navigationError, isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
}
