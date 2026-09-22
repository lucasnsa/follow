import 'package:flutter/material.dart';
import 'package:follow/follow.dart';

import 'navigation.dart';

const appIndigo = Color(0xFF4F46E5);
const appBackground = Color(0xFFF5F7FB);

ThemeData buildExampleTheme() {
  final colors = ColorScheme.fromSeed(
    seedColor: appIndigo,
    brightness: Brightness.light,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: appBackground,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE7EAF2)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

class AppShell extends StatelessWidget {
  const AppShell({
    required this.section,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
    super.key,
  });

  final int section;
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) =>
            _buildLayout(context, constraints.maxWidth >= 800),
      );

  Widget _buildLayout(BuildContext context, bool wide) {
    final navigation = context.follow;
    const destinations = [
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: Text('Visão geral'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2_rounded),
        label: Text('Produtos'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.science_outlined),
        selectedIcon: Icon(Icons.science_rounded),
        label: Text('Explorar'),
      ),
    ];

    void select(int index) {
      switch (index) {
        case 0:
          navigation.go(homeRoute.location);
        case 1:
          navigation.go(productsMountRoute.location);
        case 2:
          navigation.go(exploreRoute.location);
      }
    }

    final body = SafeArea(
      child: Column(children: [
        if (navigation.isNavigating)
          const LinearProgressIndicator(minHeight: 3),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              wide ? 40 : 20,
              28,
              wide ? 40 : 20,
              40,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.7,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                subtitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: const Color(0xFF667085),
                                      height: 1.45,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (wide) ...actions,
                      ],
                    ),
                    if (!wide && actions.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Wrap(spacing: 10, runSpacing: 10, children: actions),
                    ],
                    const SizedBox(height: 28),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );

    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: const BrandMark(compact: true),
              actions: [
                PopupMenuButton<int>(
                  tooltip: 'Navegação',
                  initialValue: section,
                  onSelected: select,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 0, child: Text('Visão geral')),
                    PopupMenuItem(value: 1, child: Text('Produtos')),
                    PopupMenuItem(value: 2, child: Text('Explorar recursos')),
                  ],
                ),
              ],
            ),
      body: wide
          ? Row(children: [
              Container(
                width: 230,
                color: Colors.white,
                child: Column(children: [
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: BrandMark(compact: true),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: NavigationRail(
                      extended: true,
                      backgroundColor: Colors.white,
                      selectedIndex: section,
                      onDestinationSelected: select,
                      labelType: NavigationRailLabelType.none,
                      destinations: destinations,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'follow 0.3.0',
                      style: TextStyle(color: Color(0xFF98A2B3)),
                    ),
                  ),
                ]),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ])
          : body,
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({this.compact = false, super.key});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: appIndigo,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_tree_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            compact ? 'Follow' : 'Follow playground',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      );
}

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    this.badge,
    this.action,
    this.actionLabel,
    super.key,
  });
  final IconData icon;
  final String title;
  final String description;
  final String? badge;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 160) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: appIndigo),
                  ),
                  const Spacer(),
                  if (badge != null)
                    Chip(
                      label: Text(badge!, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      backgroundColor: const Color(0xFFF2F4F7),
                    ),
                ]),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    height: 1.45,
                  ),
                ),
                if (action != null) ...[
                  const Spacer(),
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: action,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(actionLabel ?? 'Experimentar'),
                  ),
                ],
              ],
            ),
          ),
        );
      });
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid(
      {required this.children, this.minWidth = 260, super.key});
  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (_, constraints) {
        final columns = (constraints.maxWidth / minWidth).floor().clamp(1, 4);
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final child in children)
              SizedBox(width: width, height: 360, child: child),
          ],
        );
      });
}
