# Projeto Cache

## Compilar

make

## Gerar traces

./gerar_trace 1   # trace_streaming.txt
./gerar_trace 2   # trace_matrix.txt
./gerar_trace 3   # trace_linked_list.txt
./gerar_trace 4   # trace_pattern.txt
./gerar_trace 5   # trace_todos.txt
./gerar_trace 6   # trace_validacao.txt

## Rodar uma configuração padrão

./simulador_lru trace_streaming.txt
./simulador_drrip trace_streaming.txt

## Rodar todas as 16 combinações da especificação e salvar CSV

./simulador_lru trace_streaming.txt --all resultados_lru.csv
./simulador_drrip trace_streaming.txt --all resultados_drrip.csv

As combinações usam:
- L1: 4 KB ou 8 KB; bloco 32 B; 2 ou 4 vias.
- L2: 32 KB ou 128 KB; bloco 64 B; 8 ou 16 vias.
