# Follow playground

Um dashboard responsivo para experimentar a API da biblioteca. Execute:

```sh
flutter run -d chrome
```

## Rotas

- `/` — visão geral e atalhos para os principais recursos.
- `/products` — feature protegida por guard, catálogo e ordenação via query.
- `/products/42` — link direto tipado, ativando a feature sob demanda.
- `/explore` — laboratório de 404, deny, erros e loading inicial.

O exemplo usa `FollowApp` com uma `Feature` imutável; nenhum widget da
aplicação cria ou descarta o router. O primeiro acesso a produtos passa por um
login demonstrativo. O catálogo leva
5 segundos para ficar pronto, enquanto o layout e o outlet permanecem
montados. Nos detalhes, o relatório lazy usa `Future.wait` para simular mais
5 segundos e compartilha a instância entre as páginas da feature.

A área **Explorar recursos** executa guards reais e configura os builders de
loading, página não encontrada, acesso negado e erro. As prévias usam um router
isolado com `RouteInformationProvider` em memória, por isso não alteram o
histórico principal. Use voltar/avançar do navegador para conferir a restauração
das pilhas.

O `shell` de `productsFeature` recebe automaticamente o outlet das rotas filhas.
O layout usa navegação lateral a partir de
800 px e menu compacto no celular.
Não há autenticação, backend, imagens ou dependências visuais externas.
