# Implementação da Política DRRIP em FPGA

Projeto desenvolvido na disciplina de **Projeto Integrador IV** do curso de Engenharia de Computação da Universidade Federal do Pampa — UNIPAMPA.

O projeto apresenta uma implementação em Verilog da política de substituição de cache **DRRIP**, comparada com a política tradicional **LRU**.

## Integrantes

- João Pedro Soll Dias
- João Victor da Rosa Schervensquy
- Simony Meira Franco Cogoy da Silva

## Configuração da cache

- Capacidade: 4 KB
- Associatividade: 4 vias
- Tamanho do bloco: 32 bytes
- Quantidade de conjuntos: 32
- Quantidade de linhas: 128
- Endereço: 32 bits
- FPGA utilizado: Cyclone III EP3C25F324C6

## Arquivos principais

### DRRIP

- `drrip_set.v`: representa um conjunto com quatro vias e controla tags, bits válidos, RRPVs, hits, misses e escolha da vítima.
- `cache_drrip.v`: representa a cache completa com 32 conjuntos e controla SRRIP, BRRIP, conjuntos líderes, seguidores e PSEL.

### LRU

- `lru_set.v`: representa um conjunto com quatro vias utilizando a política LRU.
- `cache_lru.v`: representa a cache LRU completa com 32 conjuntos.

### Testbenches

- `tb_drrip_basico.v`: verifica o funcionamento básico do DRRIP.
- `tb_comparativo_drrip_lru.v`: compara DRRIP e LRU em padrões simples.
- `tb_benchmarks_completos.v`: executa os benchmarks utilizados na avaliação final.

## Ferramentas utilizadas

- Verilog
- ModelSim
- Quartus
- Logisim
- Overleaf

## Principais resultados

| Métrica | DRRIP | LRU |
|---|---:|---:|
| Hit rate global | 81,27% | 76,25% |
| Misses | 1.261 | 1.599 |
| Elementos lógicos | 5.289 | 6.257 |
| Registradores | 3.211 | 3.200 |
| Fmax | 117,84 MHz | 133,46 MHz |
| Latência considerada | 1 ciclo | 1 ciclo |

O DRRIP apresentou 338 hits adicionais e evitou 338 misses em relação ao LRU.

## Limitações

A implementação representa somente a estrutura de tags e os metadados das políticas de substituição.

Não foram implementados:

- armazenamento dos dados dos blocos;
- integração com processador RISC-V;
- comunicação com memória principal;
- política de escrita;
- bits dirty;
- análise de potência;
- testes físicos na placa FPGA.

## Relatório

A explicação completa da arquitetura, funcionamento, metodologia, benchmarks e resultados está disponível na pasta "Relatório"