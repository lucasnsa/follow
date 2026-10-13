import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> openPlayground(WidgetTester tester) async {
  await tapVisible(tester, find.text('Follow Playground'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'animations package receives progressing page and branch animations',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Pilhas independentes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catálogo — item 1'));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        tester
            .widgetList<SharedAxisTransition>(find.byType(SharedAxisTransition))
            .any((widget) =>
                widget.animation.value > 0 && widget.animation.value < 1),
        isTrue);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoritos'));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        tester
            .widgetList<FadeThroughTransition>(
                find.byType(FadeThroughTransition))
            .any((widget) =>
                widget.animation.value > 0 && widget.animation.value < 1),
        isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('independent stacks demo retains notes and detail page',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Pilhas independentes'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Minha nota');
    await tester.tap(find.text('Catálogo — item 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoritos'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Catálogo')));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes de Catálogo'), findsOneWidget);
    await tester.tap(find.text('Voltar à lista'));
    await tester.pumpAndSettle();
    expect(find.text('Minha nota'), findsOneWidget);
  });

  testWidgets('login guard, catalog readiness, lazy report and back',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await openPlayground(tester);
    await tapVisible(tester, find.text('Abrir produtos'));
    await tester.pumpAndSettle();
    expect(find.text('Área protegida'), findsOneWidget);
    await tapVisible(tester, find.text('Entrar e continuar'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    // The feature mount now enters with the app's configured transition.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Inicializando a feature de produtos'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Feature Scope'), findsOneWidget);
    await tapVisible(tester, find.text('Feature Scope'));
    await tester.pumpAndSettle();
    expect(find.text('ID 42'), findsOneWidget);
    await tapVisible(tester, find.text('Carregar relatório lazy'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey('lazy-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('lazy-result')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lazy-result')), findsOneWidget);
    expect(find.textContaining('4 produtos no catálogo compartilhado'),
        findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Feature Scope'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('404 uses custom builder and recovers to home', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await openPlayground(tester);
    await tapVisible(tester, find.text('Explorar recursos'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Abrir rota inválida'));
    await tester.pumpAndSettle();
    expect(find.text('Essa rota não foi encontrada'), findsOneWidget);
    expect(find.textContaining('/rota-que-nao-existe'), findsOneWidget);
    await tapVisible(tester, find.text('Ir ao início'));
    await tester.pumpAndSettle();
    expect(find.text('Escolha o que explorar.'), findsOneWidget);
    await openPlayground(tester);
    expect(find.text('Modularização que acompanha a árvore'), findsOneWidget);
  });

  testWidgets('denied and error guards keep explore mounted', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await openPlayground(tester);
    await tapVisible(tester, find.text('Explorar recursos'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Executar guard'));
    await tester.pumpAndSettle();
    expect(find.textContaining('O guard negou a navegação'), findsOneWidget);
    expect(find.text('Explore os estados do router'), findsOneWidget);
    await tapVisible(tester, find.text('Fechar'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Simular erro'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Falha simulada pelo guard'), findsOneWidget);
    expect(find.text('Explore os estados do router'), findsOneWidget);
  });

  testWidgets('isolated previews show loading, denied and error builders',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await openPlayground(tester);
    await tapVisible(tester, find.text('Explorar recursos'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Abrir prévia'));
    await tester.pump();
    expect(find.text('Aguardando o guard'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Guard concluído'), findsOneWidget);
    await tapVisible(tester, find.text('Negado'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso negado pelo guard'), findsOneWidget);
    await tapVisible(tester, find.text('Erro'));
    await tester.pumpAndSettle();
    expect(find.text('Erro capturado'), findsOneWidget);
  });

  testWidgets('selection opens weather and returns to examples',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Follow Playground'), findsOneWidget);
    expect(find.text('Clima & Planos'), findsOneWidget);
    await tapVisible(tester, find.text('Clima & Planos'));
    await tester.pumpAndSettle();
    expect(find.text('Onde você quer planejar?'), findsOneWidget);
    await tapVisible(tester, find.text('Trocar exemplo'));
    await tester.pumpAndSettle();
    expect(find.text('Escolha o que explorar.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mobile and desktop layouts do not overflow', (tester) async {
    var iteration = 0;
    for (final size in [const Size(390, 844), const Size(1280, 900)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
          KeyedSubtree(key: ValueKey(iteration++), child: const MyApp()));
      await tester.pumpAndSettle();
      await openPlayground(tester);
      // Flutter's test binding fails this test automatically on layout errors.
      await tester.pumpWidget(const SizedBox());
    }
    await tester.binding.setSurfaceSize(null);
  });
}
