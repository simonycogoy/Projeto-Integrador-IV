# Simulador simples de cache LRU x DRRIP — PI4

Este pacote foi montado para a etapa de modelagem em C antes do RTL.
A ideia é comparar o baseline LRU com o DRRIP usando traces fixos, sem gerador de trace.

## Compilar

```bash
make
```

## Rodar

```bash
./sim_cache traces/trace_validacao.txt ambos --debug 60
./sim_cache traces/trace_streaming_hotset.txt ambos
./sim_cache traces/trace_matrix.txt ambos
./sim_cache traces/trace_linked_list.txt ambos
./sim_cache traces/trace_pattern.txt ambos
./sim_cache traces/trace_l2_pressure.txt ambos
```

Também é possível rodar uma política só:

```bash
./sim_cache traces/trace_validacao.txt lru
./sim_cache traces/trace_validacao.txt drrip
```

## Arquivos principais

- `src/cache.h`: estruturas da cache, hierarquia e interface das políticas.
- `src/cache.c`: núcleo comum da cache e da hierarquia L1 + L2.
- `src/cache_lru.c`: política LRU baseline.
- `src/cache_drrip.c`: política DRRIP com RRPV de 2 bits e PSEL.
- `src/main.c`: lê o trace e roda LRU, DRRIP ou ambos.

## Formato do trace

Cada linha pode ser:

```text
0x00000000
R 0x00000000
W 0x00000000
```

Linhas começando com `#` são ignoradas.

## Observação importante

O DRRIP usa conjuntos monitor para decidir entre SRRIP e BRRIP. Por isso, o trace `trace_validacao.txt`
é didático, mas o melhor para mostrar diferença acumulada entre LRU e DRRIP é `trace_streaming_hotset.txt`.


## Uso com Makefile completo

Agora o alvo padrão já compila e roda todos os traces:

```bash
make
```

Para rodar a validação com debug linha a linha:

```bash
make validacao
```

Para gerar um arquivo de resultados para o relatório:

```bash
make report
```

O arquivo será salvo em:

```text
resultados/resultados_cache.txt
```

Outros atalhos disponíveis:

```bash
make streaming
make matrix
make linked
make pattern
make l2
make clean
```
