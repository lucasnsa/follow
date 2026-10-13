## 0.5.1

* Document the Follow development skill and its installation command in the
  English and Brazilian Portuguese READMEs.

## 0.5.0

* Breaking: rename the Feature shell callback to builder, FeatureShell callback
  type to FeatureBuilder, and buildShell to buildContent.
* Add FeatureShell.indexedStack and typed FeatureBranch.mount declarations with
  lazy, persistent branch navigators and isolated dependency scopes.
* Add FollowShellController and context.follow.shell for selection and reset.
* Support nested shells, transactional guards, deep links and independent stacks.
* Write version 2 navigation-tree history snapshots; keep reading version 1.
* Add unnamed `Token<T>()` keys for default dependencies resolved by exact type.
* Allow omitting the token in `read<T>()`, `readAsync<T>()`, `watch<T>()`,
  `Read.call<T>()`, and `Read.async<T>()`, preserving named-token identity.
* Demonstrate typed reads and unnamed registrations in the weather example.
* Compatibility: custom implementations of `Read` must update `call` and `async`
  to accept an optional positional `Token<T>?` argument (`[Token<T>? token]`).
* Add FollowTransition presets and custom Flutter transition builders, with
  app and feature defaults plus per-route overrides.
* Add FeatureShell.animated and BranchTransition for retained branch animations.
* Coordinate transitions with guards, history restoration, and reduced-motion
  settings; keep exiting feature scopes alive until their page animation finishes.
* Isolate Hero controllers per navigator.
* Expand the example with independent stacks, retained form and scroll state,
  and optional animations-package transitions without adding a Follow dependency.

## 0.4.0

* Replace inheritance-based `Module` declarations with immutable `Feature`
  values and `FeatureScope`.
* Add identity-based `Token<T>` dependency keys and immutable declarations
  through `Bind`.
* Add sealed feature and dependency states with blocking, background, and lazy
  async policies.
* Add typed route specs with record-friendly codecs and typed navigation
  locations.
* Rename mounted diagnostics to `FollowFeatureScope<name>` and include token,
  policy, state, route, and guard information.
* Breaking change: remove `Module`, `Injector`, `Resolver`, `RouteManager`,
  string navigation, and the old readiness properties.

## 0.3.0

* Replace module widgets with declarative `Module` definitions using `binds` and `routes`.
* Add `FollowApp` to own router creation and disposal without requiring application state.
* Add automatic routed module mounting and persistent shells through `buildShell`.
* Add namespaced dependency and navigation access through `context.follow`.
* Add `ModuleScope` for dependency modules in arbitrary non-routed subtrees.
* Add Flutter-native module and runtime diagnostics through `debugDiagnostics`
  and expose mounted module scopes in Flutter Inspector.
* Breaking change: remove the public `Inject`, `ChildRoute`, `ModuleRoute`, `ModuleOutlet`, `ModuleAccess`, and `FollowRouter` APIs.

## 0.2.0

* Add ChildRoute, ModuleRoute and ModuleOutlet with lazy module activation.
* Add FollowRouter, nested page stacks, deep links and browser history snapshots.
* Add async guards, redirects, cancellation and configurable navigation fallbacks.
* Preserve widget-scoped DI and readiness; routing is optional for DI-only modules.
* Add a login/products example and routing lifecycle tests.

## 0.1.0

* Replace experimental routing APIs with widget-tree dependency scopes.
* Add typed injection, ancestor lookup, lazy async singletons and observable readiness.
* Add lifecycle disposal and initialization error reporting.
* Remove GetIt. Breaking change: import package:follow/follow.dart and use Module.
