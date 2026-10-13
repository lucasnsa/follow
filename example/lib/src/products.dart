import 'package:flutter/material.dart';
import 'package:follow/follow.dart';

import 'design.dart';
import 'navigation.dart';

class Product {
  const Product(this.id, this.name, this.description, this.price, this.icon);
  final String id;
  final String name;
  final String description;
  final double price;
  final IconData icon;
}

class Catalog {
  final products = const [
    Product(
      '42',
      'Feature Scope',
      'Escopo de dependências ligado à árvore de widgets.',
      42,
      Icons.account_tree_outlined,
    ),
    Product(
      '43',
      'Lazy Report',
      'Singleton assíncrono criado apenas quando solicitado.',
      19.90,
      Icons.query_stats_rounded,
    ),
    Product(
      '44',
      'Route Guard',
      'Proteção e redirecionamento antes de montar uma feature.',
      27.50,
      Icons.shield_outlined,
    ),
    Product(
      '45',
      'Nested Outlet',
      'Navegação interna mantendo o layout da feature ativa.',
      35,
      Icons.dashboard_customize_outlined,
    ),
  ];

  Product byId(String id) => products.firstWhere(
        (product) => product.id == id,
        orElse: () => Product(
          id,
          'Produto $id',
          'Produto aberto por parâmetro dinâmico.',
          0,
          Icons.extension_outlined,
        ),
      );
}

class Report {
  Report(this.message);
  final String message;
}

final catalogToken = Token<Catalog>('catalog');
final reportToken = Token<Report>('report');

final productsFeature = Feature(
  name: 'products',
  bindings: [
    Bind.async(catalogToken, (_) async {
      await Future<void>.delayed(const Duration(seconds: 5));
      return Catalog();
    }),
    Bind.async(
      reportToken,
      (read) async {
        final catalogFuture = read.async(catalogToken);
        await Future.wait<Object?>([
          catalogFuture,
          Future<void>.delayed(const Duration(seconds: 5)),
        ]);
        final catalog = await catalogFuture;
        return Report(
          '${catalog.products.length} produtos no catálogo compartilhado',
        );
      },
      policy: AsyncPolicy.lazy,
    ),
  ],
  routes: [
    FeatureRoute.page(
      productsListRoute,
      builder: (_, sort) => ProductList(sort: sort),
    ),
    FeatureRoute.page(
      productDetailsRoute,
      builder: (_, arguments) => ProductDetails(id: arguments.id),
    ),
  ],
  builder: (_, outlet) => ProductsShell(outlet: outlet),
);

class ProductsShell extends StatelessWidget {
  const ProductsShell({required this.outlet, super.key});

  final Widget outlet;

  @override
  Widget build(BuildContext context) => AppShell(
        section: 1,
        title: 'Catálogo modular',
        subtitle:
            'O layout permanece montado enquanto as rotas internas trocam no outlet da feature.',
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              final didPop = await context.follow.pop();
              if (!didPop && context.mounted) {
                await context.follow.go(playgroundRoute.location);
              }
            },
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Voltar'),
          ),
        ],
        child: SizedBox(height: 620, child: outlet),
      );
}

class ProductList extends StatelessWidget {
  const ProductList({this.sort, super.key});
  final String? sort;

  @override
  Widget build(BuildContext context) {
    final follow = context.follow;
    if (follow.featureState case FeatureFailed(:final error)) {
      return _InlineState(
        icon: Icons.error_outline,
        title: 'Falha ao carregar o catálogo',
        message: '$error',
      );
    }
    if (follow.featureState is! FeatureReady) return const _CatalogLoading();

    final products = [...follow.read(catalogToken).products];
    if (sort == 'price') products.sort((a, b) => a.price.compareTo(b.price));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${products.length} recursos disponíveis',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'default', label: Text('Padrão')),
              ButtonSegment(value: 'price', label: Text('Preço')),
            ],
            selected: {sort == 'price' ? 'price' : 'default'},
            onSelectionChanged: (value) {
              final sort = value.first == 'price' ? 'price' : null;
              context.follow.replace(productsListRoute.location(sort));
            },
          ),
        ],
      ),
      const SizedBox(height: 18),
      Expanded(child: LayoutBuilder(builder: (_, constraints) {
        final columns = (constraints.maxWidth / 250).floor().clamp(1, 4);
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: constraints.maxWidth < 500 ? 1.45 : .92,
          ),
          itemCount: products.length,
          itemBuilder: (_, index) => _ProductCard(product: products[index]),
        );
      })),
    ]);
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.follow.push(
            productDetailsRoute.location((id: product.id, sort: null)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(product.icon, color: appIndigo, size: 30),
                ),
                const SizedBox(height: 18),
                Text(
                  product.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  product.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    height: 1.4,
                  ),
                ),
                const Spacer(),
                Row(children: [
                  Text(
                    'R\$ ${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: appIndigo,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded, size: 19),
                ]),
              ],
            ),
          ),
        ),
      );
}

class ProductDetails extends StatefulWidget {
  const ProductDetails({required this.id, super.key});
  final String id;

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  Future<Report>? report;

  @override
  Widget build(BuildContext context) {
    final follow = context.follow;
    if (follow.featureState is! FeatureReady) return const _CatalogLoading();
    final product = follow.read(catalogToken).byId(widget.id);
    return ListView(children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.follow.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Voltar ao catálogo'),
        ),
      ),
      const SizedBox(height: 14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Wrap(
            spacing: 28,
            runSpacing: 22,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(product.icon, size: 52, color: appIndigo),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 570),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(
                        label: Text('ID ${product.id}'), side: BorderSide.none),
                    Text(
                      product.name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.description,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'R\$ ${product.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: appIndigo,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.query_stats_rounded, color: appIndigo),
                const SizedBox(width: 10),
                Text(
                  'Relatório lazy',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ]),
              const SizedBox(height: 10),
              const Text(
                'A dependência é criada no primeiro acesso. O Future.wait mantém a simulação ativa por cinco segundos.',
                style: TextStyle(color: Color(0xFF667085), height: 1.45),
              ),
              const SizedBox(height: 18),
              if (report == null)
                FilledButton.icon(
                  onPressed: _loadReport,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Carregar relatório lazy'),
                )
              else
                FutureBuilder<Report>(
                  future: report,
                  builder: (_, snapshot) {
                    if (snapshot.hasError) {
                      return Text('Erro: ${snapshot.error}');
                    }
                    if (!snapshot.hasData) {
                      return const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'Inicializando em paralelo… aguarde cerca de 5 segundos.',
                            key: ValueKey('lazy-loading'),
                          ),
                        ],
                      );
                    }
                    return Container(
                      key: const ValueKey('lazy-result'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF039855),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${snapshot.data!.message}. A instância será reutilizada nos próximos acessos.',
                          ),
                        ),
                      ]),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    ]);
  }

  void _loadReport() => setState(() {
        report ??= context.follow.readAsync(reportToken);
      });
}

class _CatalogLoading extends StatelessWidget {
  const _CatalogLoading();

  @override
  Widget build(BuildContext context) => const _InlineState(
        icon: Icons.inventory_2_outlined,
        title: 'Inicializando a feature de produtos',
        message:
            'O catálogo assíncrono simula uma inicialização de 5 segundos. O layout e o outlet já estão montados.',
        busy: true,
      );
}

class _InlineState extends StatelessWidget {
  const _InlineState({
    required this.icon,
    required this.title,
    required this.message,
    this.busy = false,
  });
  final IconData icon;
  final String title;
  final String message;
  final bool busy;

  @override
  Widget build(BuildContext context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (busy)
                  const CircularProgressIndicator()
                else
                  Icon(icon, size: 42, color: appIndigo),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    height: 1.5,
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
