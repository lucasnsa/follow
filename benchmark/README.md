# Refatoração conservadora: validação e benchmark

## Executar

Na raiz do package:

```sh
flutter test --no-pub
flutter analyze --no-pub
flutter test --no-pub benchmark/navigation_benchmark.dart
```

O benchmark fica fora de `test/` para não tornar medições de tempo parte da
suíte regular. Não há limite de performance usado como critério de CI.

## Método

Medição local em Linux, Flutter 3.41.9, Dart 3.11.5. A versão original foi
preservada em uma cópia temporária antes da refatoração. O mesmo benchmark
foi executado contra ambas as versões, com o mesmo SDK.

Cada cenário usa somente a API pública: `FollowApp`, `Feature`,
`FeatureRoute`, `StaticRouteSpec` e `FollowContext.go`. Há tabelas de
10, 100 e 1.000 páginas, na raiz ou abaixo de três Features. Cada cenário
aquece com 20 navegações e mede cinco lotes de 40 navegações. O resultado
é a mediana dos lotes dividida por 40. A montagem inicial fica fora da
medição; as Features intermediárias permanecem montadas durante os lotes.

São tempos de ponta a ponta de widget tests em debug, incluindo pumps,
navegação e trabalho do Flutter. Não são tempos de frames em profile/release
nem uma medição isolada do matcher. JIT, GC e a ordem dos cenários influenciam
os resultados: não compare cenários de tamanhos diferentes entre si.

## Resultado local

Última comparação sequencial, original seguida da refatorada, sem outra
suíte executando simultaneamente. Tempos em milissegundos por navegação;
variação negativa indica redução de tempo.

| Rotas | Níveis filhos | Original (ms) | Refatorada (ms) | Variação |
| --- | --- | --- | --- | --- |
| 10 | 0 | 2.857 | 2.875 | +0.7% |
| 10 | 3 | 3.174 | 3.072 | -3.2% |
| 100 | 0 | 1.648 | 1.731 | +5.1% |
| 100 | 3 | 2.272 | 2.082 | -8.3% |
| 1000 | 0 | 1.526 | 1.276 | -16.4% |
| 1000 | 3 | 2.236 | 1.726 | -22.8% |

Uma comparação anterior também mostrou redução nos cenários de 1.000 rotas
(aproximadamente 21% e 23%). Os resultados dos cenários menores oscilaram;
em particular, 100 rotas na raiz passaram de uma melhora na primeira rodada
para aumento de 5,1% na última. Não há evidência suficiente para afirmar ganho
nesses cenários pequenos, nem garantia de que os percentuais se repetirão
em aplicações reais.

A redução de trabalho vem da preparação dos caminhos por definição montada,
reutilização dos segmentos do destino e seleção linear do melhor match.
A separação de arquivos, por si só, não representa ganho de runtime.
Metadados agora ficam retidos pela definição/nó enquanto existirem; consumo
de memória e custo de montagem inicial não foram medidos.

## Compatibilidade e organização

- `router.dart` passou de 611 para 440 linhas. Transações, modelos e integração
  com o Router do Flutter possuem arquivos próprios.
- Os arquivos de `module` foram substituídos por arquivos de `feature`,
  separando declaração, escopo, acesso e resolução de bindings.
- Contratos de rotas, tratamento de caminhos e matching estão separados.
- Notificações, staging, ciclo de vida, readiness, políticas async, descarte
  e o formato de histórico `follow: 1` foram preservados.
- O caso comum de matching não ordena candidatos. Empates na melhor
  especificidade preservam a ordenação anterior, inclusive sua instabilidade
  para tabelas grandes, para não trocar silenciosamente a rota escolhida.
- Diagnósticos obtêm o estado uma vez por preenchimento.

Validação realizada:

- 26 testes originais passaram antes das alterações.
- Oito testes de caracterização passaram tanto na versão original quanto na
  refatorada: empates com 8/64 rotas, precedência lexicográfica, prefixos
  permitidos, parâmetros codificados, barras finais, query e aninhamento.
- Os 34 testes da biblioteca e seis cenários do benchmark passaram.
- Os cinco testes do exemplo e sua análise estática passaram em cópia
  temporária ligada à biblioteca refatorada.
- A análise estática da biblioteca não encontrou problemas.
- Os hashes SHA-256 dos 997 arquivos existentes em `example/` foram
  conferidos sem diferenças. Nenhum arquivo do exemplo foi editado.
- As 36 declarações públicas foram comparadas textualmente, incluindo os
  corpos, sem diferenças. Snapshot ordenado das declarações:
  `49c6da2db7a0d605d3bc0cb9ca1e3dc279e5440948e49c7d7e382939a437d205`.

A execução foi feita no SDK instalado, não numa matriz de versões. As
restrições Dart `^3.6.1` / Flutter `>=3.27.0` e as dependências do package
não foram alteradas.
