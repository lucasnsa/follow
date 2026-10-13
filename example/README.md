# Follow examples

Run `flutter run -d chrome` from the `example` directory. The home screen
(`/`) lets you choose between three demos.

## Independent stacks

- `/stacks` — two shell branches with separate navigation stacks.

Switch between Catalog and Favorites after opening a detail page, typing a
note, or scrolling the list. Each branch retains its own page and widget state.
The app uses `FollowTransition.custom` with `SharedAxisTransition` for pages
and `BranchTransition.custom` with `FadeThroughTransition` for branch
changes. The `animations` package is a dependency of the example app only.

## Follow Playground

- `/playground` — overview of the library.
- `/products` and `/products/:id` — guarded feature, shared catalog, query
  parameter sorting, and a lazy report.
- `/explore` — experiments with not-found and denied routes, errors, and
  initial loading.

The first visit to the catalog uses a demo login. The catalog takes five
seconds to become ready; the lazy report takes another five seconds after it
is requested. Previews use an isolated router and do not change the main
history.

## Weather & Plans

- `/weather` — a São Paulo forecast at startup, city search, and walking
  suggestions.

The weather feature uses Follow to scope and dispose of its HTTP client,
repository, and BLoCs. Bindings use `Token<T>()`, with type-based reads through
`read<T>()` in constructors and `context.follow.read<T>()` in the shell.
`CitySearchBloc` handles debounced search, while `ForecastBloc` handles
loading, city changes, and refreshes. The UI receives these BLoCs through
`BlocProvider.value`. The app uses [Open-Meteo](https://open-meteo.com/) for
geocoding and forecasts without an API key. Internet access is required.

Suggestions evaluate the next 24 hours in the city's local time and show up
to three daytime periods with temperatures of 16–28 °C, rain probability below
30%, and wind speed below 20 km/h. They prioritize lower rain probability,
temperatures closer to 22 °C, lower wind speed, and earlier times. These are
forecast-based suggestions, not weather alerts.
