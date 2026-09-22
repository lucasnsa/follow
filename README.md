# Follow

Features imutáveis, rotas tipadas e dependências com ciclo de vida ligado à
árvore de widgets. Não há container global nem dependências externas.

## Aplicação

Uma `Feature` é somente a descrição de bindings, rotas e shell. O estado vivo é
criado quando ela entra na árvore:

```dart
final api = Token<Api>('api');
final session = Token<Session>('session');

final home = StaticRouteSpec('/');
final products = StaticRouteSpec('/products');

final appFeature = Feature(
  name: 'app',
  bindings: [
    Bind.singleton(api, (_) => Api(), dispose: (api) => api.close()),
    Bind.async(session, (read) => Session.load(read(api))),
  ],
  routes: [
    FeatureRoute.page(home, builder: (_, __) => const HomePage()),
    FeatureRoute.mount(products, feature: (_) => productsFeature),
  ],
);

void main() {
  runApp(FollowApp(
    feature: appFeature,
    builder: (_, routerConfig) =>
        MaterialApp.router(routerConfig: routerConfig),
  ));
}
```

`FollowApp` possui o router e o escopo raiz. Trocar sua `Key` recria ambos.

## Dependências por token

Tokens têm identidade, não apenas tipo. Isso permite registrar mais de uma
dependência do mesmo tipo sem nomes mágicos:

```dart
final primaryApi = Token<Api>('primary-api');
final reportsApi = Token<Api>('reports-api');
```

`Bind` oferece quatro declarações:

| Declaração | Comportamento |
| --- | --- |
| `Bind.value` | valor existente e opcionalmente descartável |
| `Bind.factory` | nova instância em cada leitura |
| `Bind.singleton` | singleton `eager` ou `lazy` |
| `Bind.async` | singleton async `blocking`, `background` ou `lazy` |

Factories recebem `Read`, que pode ser chamado como função ou assincronamente:

```dart
Bind.singleton(repository, (read) => Repository(read(primaryApi)));
Bind.async(report, (read) async => Report(await read.async(repository)));
```

A busca começa na Feature atual e continua pelos ancestrais. Uma Feature filha
pode sobrescrever um token; escopos irmãos continuam isolados.

Dentro de widgets:

```dart
final api = context.follow.read(primaryApi);
final report = await context.follow.readAsync(reportToken);

switch (context.follow.watch(reportToken)) {
  case DependencyIdle():
  case DependencyLoading():
    return const CircularProgressIndicator();
  case DependencyReady(:final value):
    return Text(value.title);
  case DependencyFailed(:final error):
    return Text('Erro: $error');
}
```

`watch` ativa singletons lazy e reconstrói o widget nas transições. Factories
devem ser acessadas com `read` e não podem ser observadas.

## Estado e ciclo de vida

`context.follow.featureState` é uma união selada e observa a cadeia ativa:

```dart
switch (context.follow.featureState) {
  case FeatureInitializing(:final pending):
    return Text('Aguardando ${pending.length} dependências');
  case FeatureReady():
    return const Content();
  case FeatureFailed(:final error):
    return Text('Falhou: $error');
}
```

`AsyncPolicy.blocking` participa desse estado; `background` inicia ao montar sem
bloquear a Feature; `lazy` inicia no primeiro `watch` ou `readAsync`. O getter
`ready` permite aguardar toda a cadeia bloqueante.

Instâncias são descartadas uma vez, em ordem inversa de criação. Resultados
assíncronos concluídos depois do unmount também são descartados.

Para montar uma Feature sem rotas em qualquer subtree:

```dart
FeatureScope(feature: checkoutFeature, child: const CheckoutPanel())
```

## Rotas tipadas

Rotas possuem caminhos absolutos. Uma rota dinâmica decodifica deep links e
codifica argumentos de navegação, normalmente usando records:

```dart
final productRoute = DataRouteSpec<({String id, String? sort})>(
  '/products/:id',
  decoder: (data) => (
    id: data.params['id']!,
    sort: data.query['sort'],
  ),
  encoder: (args) => (
    path: {'id': args.id},
    query: args.sort == null ? const {} : {'sort': args.sort!},
  ),
);

final productsFeature = Feature(
  name: 'products',
  routes: [
    FeatureRoute.page(
      productRoute,
      builder: (_, args) => ProductPage(id: args.id, sort: args.sort),
    ),
  ],
  shell: (_, outlet) => ProductsShell(outlet: outlet),
);
```

Navegação não aceita strings livres:

```dart
await context.follow.push(
  productRoute.location((id: '42', sort: 'price')),
);
await context.follow.go(homeRoute.location);
await context.follow.pop();
```

`StaticRouteSpec` representa rotas sem argumentos. `RouteData.of(context)` ou
`context.follow.route` expõe a URI, parâmetros crus e query. Deep links externos
são decodificados pelas mesmas specs, e o estado serializado restaura as pilhas
do navegador.

## Guards e fallbacks

```dart
FeatureRoute.mount(
  productsRoute,
  guards: [
    (_, read) async {
      final value = await read.async(sessionToken);
      return value.signedIn
          ? const GuardResult.allow()
          : GuardResult.redirect(loginRoute.location('/products'));
    },
  ],
  feature: (_) => productsFeature,
)
```

Guards recebem argumentos já decodificados e acesso à DI. Eles retornam
`allow`, `deny` ou um redirect tipado. Uma navegação mais nova cancela a
anterior.

`FollowApp` aceita `loadingBuilder`, `notFoundBuilder`, `deniedBuilder`,
`errorBuilder` e um `RouteInformationProvider` externo para routers isolados.

## Diagnóstico

`Feature.debugDiagnostics` descreve a declaração. O runtime ativo pode ser
impresso com:

```dart
debugPrint(context.follow.debugDiagnostics.toStringDeep());
```

No Flutter Inspector, cada escopo aparece como `FollowFeatureScope<nome>`, com
estado, base, tokens, políticas, rotas e guards. A inspeção não ativa bindings
lazy nem imprime os valores das dependências.

Veja o dashboard executável em `example/`.
