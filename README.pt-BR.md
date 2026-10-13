# Follow

[English](README.md) · Português (Brasil)

Features imutáveis, rotas tipadas e dependências com ciclo de vida ligado à
árvore de widgets. Não há container global nem dependências externas ao Flutter.

## Aplicação

Uma `Feature` descreve bindings, navegação e composição visual. O estado vivo é
criado quando ela entra na árvore de widgets:

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

`Token<T>()` registra a dependência padrão do tipo exato `T`. Você pode lê-la
pelo tipo, sem guardar a instância do token:

```dart
Bind.singleton(Token<Api>(), (_) => Api());
Bind.singleton(Token<Repository>(), (read) => Repository(read<Api>()));
Bind.async(Token<Report>(), (read) async => Report(await read.async<Repository>()));

final repository = context.follow.read<Repository>();
final report = await context.follow.readAsync<Report>();
final state = context.follow.watch<Report>();
```

Tokens sem nome do mesmo tipo são equivalentes. Cada feature aceita apenas um
registro padrão por tipo; uma filha pode sobrescrever o registro padrão de um
ancestral. A busca usa o tipo exato registrado: `Token<List<int>>()` difere de
`Token<List<num>>()`, e registrar uma implementação não registra sua interface.
Informe o tipo explicitamente ou use um contexto que permita inferi-lo.

Tokens nomeados mantêm identidade própria e permitem várias dependências do
mesmo tipo, inclusive junto com um registro padrão:

```dart
final primaryApi = Token<Api>('primary-api');
final reportsApi = Token<Api>('reports-api');

Bind.singleton(Token<Api>(), (_) => Api());
Bind.singleton(primaryApi, (_) => Api());
Bind.singleton(reportsApi, (_) => Api());

final defaultApi = context.follow.read<Api>();
final primary = context.follow.read(primaryApi);
```

Nomes são rótulos de diagnóstico: reutilize a mesma instância de um token
nomeado. Mesmo dois tokens com o mesmo nome são distintos. `read<Api>()`
procura apenas o registro padrão; não escolhe automaticamente um nomeado,
mesmo que seja o único registro disponível.

`Bind` oferece quatro declarações:

| Declaração | Comportamento |
| --- | --- |
| `Bind.value` | Valor existente e opcionalmente descartável |
| `Bind.factory` | Nova instância em cada leitura |
| `Bind.singleton` | Singleton eager ou lazy |
| `Bind.async` | Singleton assíncrono blocking, background ou lazy |

As factories recebem `Read`, que permite acesso síncrono e assíncrono:

```dart
Bind.singleton(repository, (read) => Repository(read(primaryApi)));
Bind.async(report, (read) async => Report(await read.async(repository)));
```

A busca começa na feature atual e continua pelos ancestrais. Uma feature filha
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

`watch` ativa singletons lazy e reconstrói o widget quando o estado muda.
Factories devem ser acessadas com `read` e não podem ser observadas.

## Estado e ciclo de vida

`context.follow.featureState` é uma união selada que observa a cadeia ativa
de features:

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

`AsyncPolicy.blocking` participa desse estado. `background` inicia ao montar
sem bloquear a feature; `lazy` inicia no primeiro `watch` ou `readAsync`. Use o
getter `ready` para aguardar toda a cadeia bloqueante.

Instâncias são descartadas uma vez, em ordem inversa de criação. Resultados
assíncronos concluídos depois do unmount também são descartados.

Para montar uma feature sem rotas em qualquer subtree:

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
  builder: (_, child) => ProductsShell(outlet: child),
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

`StaticRouteSpec` representa rotas sem argumentos. `RouteData.of(context)` e
`context.follow.route` expõem a URI, parâmetros crus do caminho e parâmetros
de query. Deep links externos são decodificados pelas mesmas specs, e o estado
serializado restaura as pilhas de navegação.

## Builders e shells com pilhas independentes

`Feature.builder` envolve o conteúdo da feature dentro do seu escopo de
dependências. Use-o para layouts e providers. Em `FeatureScope`, ele recebe
o `child`; em uma feature roteada, recebe o outlet de navegação.

`Feature.shell` declara branches com navegação independente. Cada branch é uma
feature montada na primeira visita, com `Navigator`, estado dos widgets e
bindings próprios. Declare `routes` ou `shell` na feature; ambos aceitam
`builder` e bindings.

```dart
final tabs = Feature(
  name: 'tabs',
  shell: FeatureShell.indexedStack(
    branches: [
      FeatureBranch.mount(
        catalogRoute,
        feature: (_) => catalogFeature,
        initialLocation: catalogListRoute.location,
      ),
      FeatureBranch.mount(
        favoritesRoute,
        feature: (_) => favoritesFeature,
        initialLocation: favoritesListRoute.location,
      ),
    ],
    builder: (context, navigation, outlet) => Scaffold(
      body: outlet,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigation.currentIndex,
        onDestinationSelected: (index) => navigation.goBranch(index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.store), label: 'Catálogo'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Favoritos'),
        ],
      ),
    ),
  ),
);
```

Monte `tabs` com `FeatureRoute.mount`, ou use-a como raiz de `FollowApp`.
Os caminhos das branches são absolutos, devem avançar além da base do shell
e não podem ter prefixos sobrepostos. `initialIndex` é `0` por padrão.
O builder do shell recebe um controller estável e deve incluir o outlet
exatamente uma vez; `Feature.builder` também deve incluir seu conteúdo
exatamente uma vez.

- `navigation.goBranch(index)` recupera a última pilha visitada nessa branch.
  Selecionar a branch atual não altera sua pilha e também cancela uma troca
  pendente.
- `navigation.goBranch(index, reset: true)` volta à localização inicial daquela
  branch, preservando seu escopo quando a identidade do mount continua igual.
- `context.follow.shell` observa o controller do shell ancestral mais próximo.
  Fora de um shell, esse getter lança `StateError`.
- `push`, `replace` e `go` selecionam a branch do destino. `go` reconstrói a
  pilha do destino e preserva as branches irmãs dos shells que continuarem
  montados.
- `pop` esgota a cadeia ativa antes de delegar ao navegador pai; não troca
  de aba.
- Deep links abrem diretamente o destino, sem inventar páginas anteriores.
  A base do shell abre a localização inicial da branch escolhida por
  `initialIndex`.
- Guards são reavaliados antes de ativar a branch. Negação, erros e cancelamento
  preservam a navegação anterior. Shells podem ser aninhados.

Branches ocultas não recebem foco, interação, semântica ou ticks de animação,
mas seus serviços e tarefas assíncronas continuam vivos. Remover o shell
descarta todas as branches. Rotas de tela inteira podem ser declaradas em
um ancestral do shell.

A URL acompanha a página visível; trocar de branch cria uma entrada no
histórico web. Voltar e avançar restauram pilhas e seleções a partir do
snapshot do histórico. Snapshots antigos continuam legíveis. Após recarregar,
a navegação pode ser reconstruída pelo snapshot, mas instâncias de DI e
estados arbitrários de widgets são recriados. Uma branch inativa negada
durante a restauração perde seu estado retido.

### Migração para 0.5.0

Substitua o antigo callback `shell: (context, outlet) => ...` por
`builder: (context, child) => ...`. Renomeie o antigo typedef de callback
`FeatureShell` para `FeatureBuilder`, e chamadas de `buildShell` para
`buildContent`. O nome `FeatureShell` agora identifica a declaração de
branches; o parâmetro `shell` não aceita mais o callback antigo.

Veja a tela **Pilhas independentes** no aplicativo de exemplo.

## Animações de páginas e branches

A Follow não anima por padrão. Configure um padrão para o aplicativo:

```dart
FollowApp(
  feature: appFeature,
  pageTransition: FollowTransition.fade(),
  builder: (_, config) => MaterialApp.router(routerConfig: config),
)
```

`Feature.pageTransition` sobrescreve o padrão para suas páginas e features
descendentes. `FeatureRoute.page` e `FeatureRoute.mount` aceitam
`transition` por rota. A precedência é **rota → feature proprietária →
ancestral configurado mais próximo → aplicativo**. Use
`const FollowTransition.none()` para desligar explicitamente uma animação
herdada. A transição do mount anima a feature inteira no navegador pai,
sem mudar o padrão das suas páginas internas.

Os presets são `FollowTransition.none()`, `.fade()` e `.slide()`. Fade e slide
usam `Curves.easeInOutCubic`; slide respeita a direção de leitura. A
`duration` padrão é de 300 ms e `reverseDuration` assume o mesmo valor
quando omitida. Durações negativas são rejeitadas.

Para integrar outro pacote, use `FollowTransition.custom`. Seu callback
recebe animações lineares do Flutter e pode aplicar curvas próprias:

```dart
import 'package:animations/animations.dart';

final sharedAxis = FollowTransition.custom(
  duration: const Duration(milliseconds: 300),
  reverseDuration: const Duration(milliseconds: 250),
  builder: (context, animation, secondaryAnimation, child) =>
      SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal,
        child: child,
      ),
);

FeatureRoute.page(
  detailsRoute,
  transition: sharedAxis,
  builder: (_, args) => DetailsPage(args: args),
);
```

Para animar a troca de abas, use `FeatureShell.animated` com
`BranchTransition.fade()` ou `BranchTransition.custom(...)`:

```dart
FeatureShell.animated(
  transition: BranchTransition.custom(
    builder: (context, animation, secondaryAnimation, child) =>
        FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        ),
  ),
  branches: [...],
  builder: (context, navigation, outlet) => MeuLayout(child: outlet),
);
```

`animations` é dependência apenas dos aplicativos que usam esse exemplo;
a Follow continua dependendo somente de Flutter. O callback do shell segue
a semântica de `PageTransitionSwitcher`: quando o índice aumenta, a animação
primária faz a entrada da branch e a secundária faz a saída; o movimento se
inverte quando o índice diminui. Cada branch permanece montada na mesma
posição da árvore de widgets.

Comportamento:

- `push` anima a entrada; `pop` usa a duração reversa. `replace` e `go`
  animam as páginas visíveis e removem páginas intermediárias sem animação.
- A URL, a seleção e a pilha lógica mudam no commit. Os Futures de navegação
  não aguardam a animação. Uma página de saída e suas dependências permanecem
  vivas até o Navigator concluir sua remoção visual.
- Primeiras páginas, deep links iniciais, fallbacks, montagens provisórias e
  restauração do histórico não animam. Guards precisam aprovar a navegação
  antes do movimento começar.
- Ao trocar de branch, somente a transição do shell anima; alterações internas
  do destino já aparecem concluídas. Em shells aninhados, somente o shell
  visível mais externo cuja seleção mudou é animado.
- Trocas rápidas concluem a transição visual anterior antes de iniciar a mais
  recente, sem enfileirar animações nem duplicar Navigators.
- Somente a branch selecionada recebe foco, interação e semântica.
  O conteúdo inativo permanece com tickers silenciados, mesmo quando participa
  da saída visual.
- `MediaQuery.disableAnimations` elimina o movimento e conclui transições
  em curso.
- Heroes animam dentro de uma pilha e ficam isolados por Navigator. Não
  atravessam branches. Transições customizadas não adicionam gestos nativos
  de voltar do Material ou Cupertino.

O exemplo **Pilhas independentes** mostra `SharedAxisTransition` e
`FadeThroughTransition` em uso.

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

Guards recebem argumentos já decodificados e acesso à injeção de
dependências. Eles retornam allow, deny ou um redirecionamento tipado.
Uma solicitação de navegação mais nova cancela a anterior.

`FollowApp` aceita `loadingBuilder`, `notFoundBuilder`, `deniedBuilder`,
`errorBuilder` e um `RouteInformationProvider` externo para routers isolados.

## Diagnóstico

`Feature.debugDiagnostics` descreve a declaração. Imprima o runtime ativo com:

```dart
debugPrint(context.follow.debugDiagnostics.toStringDeep());
```

No Flutter Inspector, cada escopo aparece como `FollowFeatureScope<name>`,
com estado, caminho base, tokens, políticas, rotas e guards. A inspeção não
ativa bindings lazy nem imprime os valores das dependências.

Veja o dashboard executável em `example/`.

## Agentes de código com IA

Instale a [skill de desenvolvimento da Follow](https://skills.sh/lucasnsa/follow/follow-app-development)
no projeto do seu aplicativo para orientar o agente sobre features, dependências
por escopo, rotas tipadas, navegação em shells e transições:

```bash
npx skills add lucasnsa/follow --skill follow-app-development
```

A skill inclui exemplos do que fazer e evitar e orienta o agente a conferir
a versão da Follow usada pelo aplicativo antes de recomendar APIs.
