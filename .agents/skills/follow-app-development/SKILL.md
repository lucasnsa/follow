---
name: follow-app-development
description: Build or modify Flutter applications using Follow's features, scoped dependencies, typed routes, guards, independent shell navigation stacks, or transitions. Use for application code that consumes Follow, not for maintaining the package internals.
---

# Develop Flutter apps with Follow

Use the public `package:follow/follow.dart` API. Check the app's resolved Follow version before using an API: shell branches and built-in transitions require Follow 0.5.0 or newer. For details, consult the README and `example/lib/src/` of the matching Follow package source. In a Follow source checkout, these are at the repository root. An installed copy of this skill may live outside that checkout, so do not resolve package documentation relative to this `SKILL.md`.

## Structure features and dependencies

- Describe each area with an immutable `Feature`. Declare its `bindings` and choose either `routes` or `shell`. `Feature.builder` wraps content in UI or providers; it does not create a navigation stack.
- Start the root with `FollowApp(feature: ..., builder: (_, config) => MaterialApp.router(routerConfig: config))`. Use `FeatureScope` for a local feature only when it declares neither `routes` nor `shell`.
- Register dependencies with `Bind.value`, `Bind.factory`, `Bind.singleton`, or `Bind.async`. An unnamed `Token<T>()` is the default key for that exact type. Create named tokens once and reuse the same instances when multiple bindings share a type. Choose `Activation` and `AsyncPolicy` according to when a binding must be ready; do not `watch` a factory binding.
- Render the supplied `child` in a feature builder, or `outlet` in a shell builder, exactly once. Keep wrappers inside the intended feature scope.

## Define and navigate routes

- Use `StaticRouteSpec` for destinations without data and `DataRouteSpec<T>` with a decoder and encoder for typed data. Route paths are absolute. Build pages with `FeatureRoute.page` and mount child features with `FeatureRoute.mount`.
- Navigate through `context.follow.push`, `replace`, or `go` with a location produced by a route spec; use `pop` to return. Keep URL serialization in the spec so deep links and browser history can reconstruct route data.
- Put access decisions in typed guards. Handle allow, deny, and redirect outcomes without creating redirect loops.

## Use a shell for independent stacks

- Use `Feature.builder` for shared layout or providers. Use `Feature.shell` for tabs or sections that must retain separate navigation stacks.
- Declare each branch with `FeatureBranch.mount` and unique, non-overlapping absolute route prefixes. Choose `FeatureShell.indexedStack` or `FeatureShell.animated`, render its `outlet` once, and switch branches with `navigation.goBranch(index, reset: ...)`.
- Each branch has its own `Navigator` and dependency scope. It mounts on first visit and stays alive when hidden, including its services and asynchronous work. `reset: true` returns that branch to its initial location. Check deep links, browser back/forward, and `pop` after the active stack is exhausted.

## Configure transitions

- Set a default page transition on `FollowApp.pageTransition`, override it on `Feature.pageTransition`, or set `transition` on a route. The nearest route or feature setting wins. No animation is the default.
- Use `FollowTransition.none`, `fade`, `slide`, or `custom` for pages. Use `BranchTransition.fade` or `custom` with `FeatureShell.animated` for branch changes. Page and branch transitions are separate choices.
- Build effects from packages such as `animations` in the consuming app through the `custom` callbacks; they are not Follow dependencies.

## Do and don't

These are application-code fragments; `productRoute`, `catalogRoute`, and the widgets are defined by the app.

**Typed navigation**

```dart
// Don't: this bypasses Follow's typed route and navigation state.
Navigator.of(context).pushNamed('/products/42');

// Do: let the route spec encode the URL and its arguments.
await context.follow.push(productRoute.location((id: '42', sort: null)));
```

**Named dependency tokens**

```dart
final primaryApi = Token<Api>('primary');
Bind.singleton(primaryApi, (_) => Api());

// Don't: a new named token is a different key, even with the same label.
context.follow.read(Token<Api>('primary'));

// Do: reuse the token instance used by the binding.
context.follow.read(primaryApi);
```

**Independent tabs and their outlet**

```dart
// Don't: a layout wrapper alone does not give each tab its own route stack.
Feature(name: 'tabs', builder: (_, child) => TabsFrame(child: child));

// Do: mount one feature per branch and render the shell outlet once.
Feature(
  name: 'tabs',
  shell: FeatureShell.indexedStack(
    branches: [
      FeatureBranch.mount(
        catalogRoute,
        feature: (_) => catalogFeature,
        initialLocation: catalogHome.location,
      ),
      FeatureBranch.mount(
        savedRoute,
        feature: (_) => savedFeature,
        initialLocation: savedHome.location,
      ),
    ],
    builder: (_, navigation, outlet) => TabsFrame(
      currentIndex: navigation.currentIndex,
      onSelect: (index) => navigation.goBranch(index),
      child: outlet,
    ),
  ),
);
```

## Verify the changed flow

Run `flutter analyze` and relevant app tests. Exercise the affected route through direct URL entry, back/forward navigation, branch switching, dependency lifetimes, and animations where applicable. Check the installed Follow version's README or source when behavior is unclear rather than assuming an API from another version.
