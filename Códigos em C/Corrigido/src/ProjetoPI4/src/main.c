#include "cache.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Benchmark A da especificacao */
#define L1_TAMANHO   4096
#define L1_BLOCO       32
#define L1_VIAS         2
#define L2_TAMANHO  32768
#define L2_BLOCO       64
#define L2_VIAS         8

static void uso(const char *prog)
{
    printf("Uso: %s <trace.txt> [lru|drrip|ambos] [--debug N]\n", prog);
    printf("\nExemplos:\n");
    printf("  %s traces/trace_validacao.txt ambos --debug 40\n", prog);
    printf("  %s traces/trace_streaming_hotset.txt ambos\n", prog);
    printf("\nTraces incluidos:\n");
    printf("  trace_validacao.txt          - pequeno, conjunto 0, facil de explicar\n");
    printf("  trace_streaming_hotset.txt   - streaming + dado quente, antagonista ao LRU\n");
    printf("  trace_matrix.txt             - reuso temporal/espacial em matriz\n");
    printf("  trace_linked_list.txt        - saltos de memoria / pointer chasing\n");
    printf("  trace_pattern.txt            - janela curta, parecido com pattern search\n");
    printf("  trace_l2_pressure.txt        - pressao maior na L2 unificada\n");
}

static int rodar_uma_politica(const char *trace, const PoliticaCache *politica,
                              int verbose, long long limite_verbose)
{
    HierarquiaCache *h = hierarquia_criar(politica,
        L1_TAMANHO, L1_BLOCO, L1_VIAS,
        L2_TAMANHO, L2_BLOCO, L2_VIAS);

    if (!h) return 1;

    long long n = hierarquia_rodar_trace(h, trace, verbose, limite_verbose);
    if (n == 0) {
        fprintf(stderr, "AVISO: nenhum acesso lido em '%s'.\n", trace);
        hierarquia_destruir(h);
        return 1;
    }

    printf("Trace: %s | acessos lidos: %lld\n\n", trace, n);
    hierarquia_imprimir_estatisticas(h);
    hierarquia_destruir(h);
    return 0;
}

int main(int argc, char *argv[])
{
    if (argc < 2) {
        uso(argv[0]);
        return 1;
    }

    const char *trace = argv[1];
    const char *modo = (argc >= 3 && argv[2][0] != '-') ? argv[2] : "ambos";
    int verbose = 0;
    long long limite_verbose = 0;

    for (int i = 2; i < argc; i++) {
        if (strcmp(argv[i], "--debug") == 0 && i + 1 < argc) {
            verbose = 1;
            limite_verbose = atoll(argv[i + 1]);
            i++;
        }
    }

    if (strcmp(modo, "lru") == 0) {
        return rodar_uma_politica(trace, &POLITICA_LRU, verbose, limite_verbose);
    }

    if (strcmp(modo, "drrip") == 0) {
        return rodar_uma_politica(trace, &POLITICA_DRRIP, verbose, limite_verbose);
    }

    if (strcmp(modo, "ambos") == 0) {
        int r1 = rodar_uma_politica(trace, &POLITICA_LRU, verbose, limite_verbose);
        int r2 = rodar_uma_politica(trace, &POLITICA_DRRIP, verbose, limite_verbose);
        return r1 || r2;
    }

    uso(argv[0]);
    return 1;
}
