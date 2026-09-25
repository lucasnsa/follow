# Follow: dois exemplos

Execute `flutter run -d chrome` na pasta `example`. A tela inicial (`/`) permite
escolher entre **Follow Playground** e **Clima & Planos**.

## Follow Playground

- `/playground` — visão geral da biblioteca.
- `/products` e `/products/:id` — feature protegida por guard, catálogo compartilhado,
  ordenação via query e relatório lazy.
- `/explore` — laboratório de 404, deny, erros e loading inicial.

O primeiro acesso ao catálogo usa login demonstrativo. O catálogo leva 5 segundos
para ficar pronto; o relatório lazy leva mais 5 segundos ao ser solicitado. As
prévias usam um router isolado e não alteram o histórico principal.

## Clima & Planos

- `/weather` — previsão de São Paulo na abertura, busca de cidades e sugestões
  para caminhada.

A feature de clima usa `Follow` para escopo e descarte do cliente HTTP, repositório
e BLoCs. Os bindings usam `Token<T>()`, com leitura por tipo via
`read<T>()` nos construtores e `context.follow.read<T>()` no shell.
`CitySearchBloc` controla busca com debounce e `ForecastBloc` controla
carregamento, troca de cidade e atualização. A interface recebe esses BLoCs via
`BlocProvider.value`. O aplicativo consulta a [Open-Meteo](https://open-meteo.com/)
para geocodificação e previsão, sem chave de API. Requer internet.

As sugestões analisam as próximas 24 horas no horário da cidade e mostram até
três períodos diurnos com 16–28 °C, chuva abaixo de 30% e vento abaixo de
20 km/h. A ordem prioriza menor chance de chuva, temperatura perto de 22 °C,
menos vento e horário mais próximo. São sugestões baseadas em previsão, não
alertas meteorológicos.
