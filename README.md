# Follow

Immutable features, typed routes, and dependencies whose lifetimes follow the
widget tree. No global container or external package dependencies.

## Application

A `Feature` describes bindings, navigation, and UI composition. Its live state is
created when it enters the widget tree:

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

`FollowApp` owns the router and root scope. Changing its `Key` recreates both.

## Token-scoped dependencies

`Token<T>()` registers the default dependency for the exact type `T`. You can
read it by type without keeping the token instance:

```dart
Bind.singleton(Token<Api>(), (_) => Api());
Bind.singleton(Token<Repository>(), (read) => Repository(read<Api>()));
Bind.async(Token<Report>(), (read) async => Report(await read.async<Repository>()));

final repository = context.follow.read<Repository>();
final report = await context.follow.readAsync<Report>();
final state = context.follow.watch<Report>();
```

Unnamed tokens of the same type are equivalent. A feature accepts only one
default binding per type; a child may override an ancestor's default binding.
Lookup uses the exact registered type: `Token<List<int>>()` differs from
`Token<List<num>>()`, and registering an implementation does not register its
interface. Specify the type explicitly or use a context that can infer it.

Named tokens have their own identity and allow multiple dependencies of the
same type, alongside a default binding:

```dart
final primaryApi = Token<Api>('primary-api');
final reportsApi = Token<Api>('reports-api');

Bind.singleton(Token<Api>(), (_) => Api());
Bind.singleton(primaryApi, (_) => Api());
Bind.singleton(reportsApi, (_) => Api());

final defaultApi = context.follow.read<Api>();
final primary = context.follow.read(primaryApi);
```

Names are diagnostic labels: reuse the same named token instance. Two tokens
with the same name are still distinct. `read<Api>()` looks only for the default
binding; it does not automatically choose a named one, even if it is the only
binding available.

`Bind` provides four declarations:

| Declaration | Behavior |
| --- | --- |
| `Bind.value` | Existing value, optionally disposable |
| `Bind.factory` | New instance on every read |
| `Bind.singleton` | Eager or lazy singleton |
| `Bind.async` | Blocking, background, or lazy async singleton |

Factories receive `Read`, which supports synchronous and asynchronous access:

```dart
Bind.singleton(repository, (read) => Repository(read(primaryApi)));
Bind.async(report, (read) async => Report(await read.async(repository)));
```

Lookup starts in the current feature and continues through its ancestors. A
child feature can override a token; sibling scopes remain isolated.

Inside widgets:

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
    return Text('Error: $error');
}
```

`watch` activates lazy singletons and rebuilds the widget when their state
changes. Factories must be accessed with `read` and cannot be watched.

## State and lifecycle

`context.follow.featureState` is a sealed union that observes the active
feature chain:

```dart
switch (context.follow.featureState) {
  case FeatureInitializing(:final pending):
    return Text('Waiting for ${pending.length} dependencies');
  case FeatureReady():
    return const Content();
  case FeatureFailed(:final error):
    return Text('Failed: $error');
}
```

`AsyncPolicy.blocking` contributes to this state. `background` starts when the
feature mounts without blocking it; `lazy` starts on the first `watch` or
`readAsync`. Use the `ready` getter to wait for the entire blocking chain.

Instances are disposed once, in reverse creation order. Async results that
complete after unmount are disposed too.

To mount a feature without routes in any subtree:

```dart
FeatureScope(feature: checkoutFeature, child: const CheckoutPanel())
```

## Typed routes

Routes use absolute paths. A dynamic route decodes deep links and encodes
navigation arguments, typically using records:

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

Navigation does not accept arbitrary strings:

```dart
await context.follow.push(
  productRoute.location((id: '42', sort: 'price')),
);
await context.follow.go(homeRoute.location);
await context.follow.pop();
```

`StaticRouteSpec` represents routes without arguments. `RouteData.of(context)`
and `context.follow.route` expose the URI, raw path parameters, and query
parameters. External deep links are decoded by the same specs, and serialized
state restores navigation stacks.

## Builders and shells with independent stacks

`Feature.builder` wraps feature content inside its dependency scope. Use it
for layouts and providers. In a `FeatureScope` it receives the `child`; in a
routed feature it receives the navigation outlet.

`Feature.shell` declares branches with independent navigation. Each branch is
a feature mounted on first visit, with its own `Navigator`, widget state, and
bindings. Declare either `routes` or `shell` on a feature; both support
`builder` and bindings.

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
          NavigationDestination(icon: Icon(Icons.store), label: 'Catalog'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Favorites'),
        ],
      ),
    ),
  ),
);
```

Mount `tabs` with `FeatureRoute.mount`, or use it as the root of `FollowApp`.
Branch paths are absolute, must extend beyond the shell base, and must not have
overlapping prefixes. `initialIndex` defaults to `0`. The shell builder
receives a stable controller and must include the outlet exactly once;
`Feature.builder` must likewise include its content exactly once.

- `navigation.goBranch(index)` restores the last stack visited in that branch.
  Selecting the current branch leaves its stack unchanged and also cancels a
  pending switch.
- `navigation.goBranch(index, reset: true)` returns to that branch's initial
  location while preserving its scope if the mount identity remains the same.
- `context.follow.shell` observes the nearest ancestor shell controller. It
  throws `StateError` outside a shell.
- `push`, `replace`, and `go` select the destination branch. `go` rebuilds the
  destination stack and preserves sibling branches of shells that stay mounted.
- `pop` exhausts the active chain before delegating to the parent navigator; it
  does not switch tabs.
- Deep links open directly at the destination without inventing preceding
  pages. The shell base opens the initial location of the branch selected by
  `initialIndex`.
- Guards are reevaluated before a branch becomes active. Denial, errors, and
  cancellation preserve the previous navigation state. Shells can be nested.

Hidden branches receive no focus, interaction, semantics, or ticker updates,
but their services and asynchronous work remain alive. Removing the shell
disposes all its branches. Full-screen routes can be declared in an ancestor
of the shell.

The URL follows the visible page; switching branches creates a web history
entry. Back and forward navigation restore stacks and selected branches from
the history snapshot. Older snapshots remain readable. After a reload,
navigation can be reconstructed from the snapshot, but DI instances and
arbitrary widget state are recreated. An inactive branch denied during
restoration loses its retained state.

### Migrating to 0.5.0

Replace the former `shell: (context, outlet) => ...` callback with
`builder: (context, child) => ...`. Rename the former `FeatureShell` callback
typedef to `FeatureBuilder` and `buildShell` calls to `buildContent`. The
`FeatureShell` name now identifies the branch declaration; the `shell`
parameter no longer accepts the old callback.

See the **Independent stacks** screen in the example app.

## Page and branch transitions

Follow does not animate by default. Set an app-wide default:

```dart
FollowApp(
  feature: appFeature,
  pageTransition: FollowTransition.fade(),
  builder: (_, config) => MaterialApp.router(routerConfig: config),
)
```

`Feature.pageTransition` overrides the default for its pages and descendant
features. `FeatureRoute.page` and `FeatureRoute.mount` accept a per-route
`transition`. Precedence is **route → owning feature → nearest configured
ancestor → app**. Use `const FollowTransition.none()` to explicitly disable an
inherited animation. A mount transition animates the entire feature in its
parent navigator without changing the default for its internal pages.

Presets are `FollowTransition.none()`, `.fade()`, and `.slide()`. Fade and slide
use `Curves.easeInOutCubic`; slide respects text direction. The default
`duration` is 300 ms, and `reverseDuration` uses the same value when omitted.
Negative durations are rejected.

To integrate another package, use `FollowTransition.custom`. Its callback
receives linear Flutter animations and can apply custom curves:

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

To animate tab changes, use `FeatureShell.animated` with
`BranchTransition.fade()` or `BranchTransition.custom(...)`:

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
  builder: (context, navigation, outlet) => MyLayout(child: outlet),
);
```

`animations` is a dependency only for apps using this example; Follow itself
still depends only on Flutter. The shell callback follows
`PageTransitionSwitcher` semantics: when the index increases, the primary
animation drives the incoming branch and the secondary animation drives the
outgoing one; the motion reverses when the index decreases. Each branch stays
mounted in the same position in the widget tree.

Behavior:

- `push` animates entry; `pop` uses the reverse duration. `replace` and `go`
  animate visible pages and remove intermediate pages without animation.
- The URL, selection, and logical stack change at commit time. Navigation
  futures do not wait for animation. An exiting page and its dependencies stay
  alive until the Navigator completes their visual removal.
- Initial pages, initial deep links, fallbacks, provisional mounts, and history
  restoration do not animate. Guards must approve navigation before motion
  begins.
- When switching branches, only the shell transition runs; internal changes
  in the destination branch appear complete. For nested shells, only the
  outermost visible shell whose selection changed animates.
- Rapid branch switches finish the previous visual transition before starting
  the latest one, without queuing animations or duplicating Navigators.
- Only the selected branch receives focus, interaction, and semantics.
  Inactive content has muted tickers even while visually exiting.
- `MediaQuery.disableAnimations` removes motion and finishes any transition in
  progress.
- Heroes animate within a stack and are isolated by Navigator. They do not
  cross branches. Custom transitions do not add native Material or Cupertino
  back gestures.

The **Independent stacks** example shows `SharedAxisTransition` and
`FadeThroughTransition` in use.

## Guards and fallbacks

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

Guards receive already-decoded arguments and access to dependency injection.
They return allow, deny, or a typed redirect. A newer navigation request
cancels the previous one.

`FollowApp` accepts `loadingBuilder`, `notFoundBuilder`, `deniedBuilder`,
`errorBuilder`, and an external `RouteInformationProvider` for isolated routers.

## Diagnostics

`Feature.debugDiagnostics` describes the declaration. Print the active
runtime with:

```dart
debugPrint(context.follow.debugDiagnostics.toStringDeep());
```

In Flutter Inspector, each scope appears as `FollowFeatureScope<name>` with
its state, base path, tokens, policies, routes, and guards. Inspection does not
activate lazy bindings or print dependency values.

See the runnable dashboard in `example/`.
