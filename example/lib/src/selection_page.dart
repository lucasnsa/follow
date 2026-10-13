import 'package:flutter/material.dart';
import 'package:follow/follow.dart';

import 'navigation.dart';
import 'shell_demo.dart';

class SelectionPage extends StatelessWidget {
  const SelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FOLLOW  /  EXEMPLOS',
                      style: TextStyle(
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF19876D))),
                  const SizedBox(height: 16),
                  Text('Escolha o que explorar.',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          color: const Color(0xFF16382F))),
                  const SizedBox(height: 12),
                  const Text(
                      'Exemplos, uma forma de compor rotas e dependências.',
                      style: TextStyle(fontSize: 17, color: Color(0xFF61736C))),
                  const SizedBox(height: 34),
                  _ExampleCard(
                    title: 'Pilhas independentes',
                    label: 'SHELL + BRANCHES',
                    description:
                        'Alterne abas preservando páginas, formulário e rolagem.',
                    icon: Icons.tab_rounded,
                    tint: const Color(0xFF5064BD),
                    background: const Color(0xFFEAEFFF),
                    onTap: () => context.follow.go(shellDemoRoute.location),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 720;
                    final cards = [
                      _ExampleCard(
                        title: 'Follow Playground',
                        label: 'ROUTER + FEATURES',
                        description:
                            'Veja guards, escopos, rotas tipadas e dependências lazy em ação.',
                        icon: Icons.account_tree_rounded,
                        tint: const Color(0xFF5064BD),
                        background: const Color(0xFFEAEFFF),
                        onTap: () =>
                            context.follow.go(playgroundRoute.location),
                      ),
                      _ExampleCard(
                        title: 'Clima & Planos',
                        label: 'FOLLOW + BLOC + API',
                        description:
                            'Encontre bons horários para caminhar com dados reais de previsão.',
                        icon: Icons.wb_sunny_rounded,
                        tint: const Color(0xFF117D65),
                        background: const Color(0xFFDDF2E8),
                        onTap: () => context.follow.go(weatherRoute.location),
                      ),
                    ];
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Expanded(child: cards[0]),
                                const SizedBox(width: 18),
                                Expanded(child: cards[1]),
                              ])
                        : Column(children: [
                            cards[0],
                            const SizedBox(height: 18),
                            cards[1]
                          ]);
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard(
      {required this.title,
      required this.label,
      required this.description,
      required this.icon,
      required this.tint,
      required this.background,
      required this.onTap});

  final String title, label, description;
  final IconData icon;
  final Color tint, background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  height: 142,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(20)),
                  child: Center(child: Icon(icon, size: 68, color: tint))),
              const SizedBox(height: 28),
              Text(label,
                  style: TextStyle(
                      color: tint,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Text(title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C342D))),
              const SizedBox(height: 8),
              Text(description,
                  style: const TextStyle(
                      fontSize: 15, color: Color(0xFF61736C), height: 1.45)),
              const SizedBox(height: 30),
              Row(children: [
                Text('Abrir exemplo',
                    style: TextStyle(fontWeight: FontWeight.w800, color: tint)),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded, color: tint)
              ]),
            ]),
          ),
        ),
      );
}
