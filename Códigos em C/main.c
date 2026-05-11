#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "cache.h"

/* Blocos fixos conforme especificacao */
#define L1_BLOCO 32
#define L2_BLOCO 64

typedef struct {
    int l1_tamanho;
    int l1_vias;
    int l2_tamanho;
    int l2_vias;
} ConfigCache;

static const ConfigCache CONFIG_BENCHMARK_A = {4096, 2, 32768, 8};

static void imprimir_uso(const char *prog) {
    printf("Uso:\n");
    printf("  %s <trace.txt>\n", prog);
    printf("  %s <trace.txt> --all [saida.csv]\n\n", prog);
    printf("Exemplos:\n");
    printf("  %s trace_streaming.txt\n", prog);
    printf("  %s trace_streaming.txt --all resultados.csv\n\n", prog);
    printf("Modo padrao: roda o Benchmark A: L1 4KB/2 vias e L2 32KB/8 vias.\n");
    printf("Modo --all: roda todas as 16 combinacoes da especificacao.\n");
}

static void calcular_taxas(const HierarquiaCache *h,
                           double *hit_l1,
                           double *hit_l2,
                           double *hit_global) {
    *hit_l1 = 0.0;
    *hit_l2 = 0.0;
    *hit_global = 0.0;

    if (h->acessos_totais > 0) {
        *hit_l1 = (double)h->acertos_l1 / h->acessos_totais * 100.0;
        *hit_global = (double)(h->acertos_l1 + h->acertos_l2) /
                      h->acessos_totais * 100.0;
    }
    if (h->l1 && h->l1->falhas > 0) {
        *hit_l2 = (double)h->acertos_l2 / h->l1->falhas * 100.0;
    }
}

static int rodar_configuracao(const char *trace,
                              ConfigCache cfg,
                              FILE *csv,
                              int mostrar_estatisticas) {
    HierarquiaCache *h = hierarquia_criar(
        cfg.l1_tamanho, L1_BLOCO, cfg.l1_vias,
        cfg.l2_tamanho, L2_BLOCO, cfg.l2_vias
    );

    if (!h) {
        fprintf(stderr, "ERRO: falha ao criar hierarquia de cache.\n");
        return 1;
    }

    long long acessos = hierarquia_rodar_trace(h, trace);
    if (acessos == 0) {
        fprintf(stderr, "AVISO: nenhum acesso lido em '%s'.\n", trace);
        hierarquia_destruir(h);
        return 1;
    }

    double hit_l1, hit_l2, hit_global;
    calcular_taxas(h, &hit_l1, &hit_l2, &hit_global);

    printf("Resumo: L1=%dB/%d vias | L2=%dB/%d vias | acessos=%lld | hit global=%.2f%%\n\n",
           cfg.l1_tamanho, cfg.l1_vias, cfg.l2_tamanho, cfg.l2_vias,
           acessos, hit_global);

    if (mostrar_estatisticas) {
        hierarquia_imprimir_estatisticas(h);
    }

    if (csv) {
        fprintf(csv,
                "%s,%d,%d,%d,%d,%d,%d,%lld,%lld,%lld,%lld,%.4f,%.4f,%.4f\n",
                trace,
                cfg.l1_tamanho, L1_BLOCO, cfg.l1_vias,
                cfg.l2_tamanho, L2_BLOCO, cfg.l2_vias,
                h->acessos_totais,
                h->acertos_l1,
                h->acertos_l2,
                h->acessos_memoria,
                hit_l1, hit_l2, hit_global);
    }

    hierarquia_destruir(h);
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc < 2 || argc > 4) {
        imprimir_uso(argv[0]);
        return 1;
    }

    const char *trace = argv[1];
    int modo_all = (argc >= 3 && strcmp(argv[2], "--all") == 0);

    if (argc >= 3 && !modo_all) {
        imprimir_uso(argv[0]);
        return 1;
    }

    FILE *csv = NULL;
    if (argc == 4) {
        csv = fopen(argv[3], "w");
        if (!csv) {
            fprintf(stderr, "ERRO: nao foi possivel criar CSV '%s'.\n", argv[3]);
            return 1;
        }
        fprintf(csv,
                "trace,l1_bytes,l1_block,l1_ways,l2_bytes,l2_block,l2_ways,accesses,l1_hits,l2_hits,memory_accesses,l1_hit_pct,l2_hit_pct,global_hit_pct\n");
    }

    if (!modo_all) {
        int erro = rodar_configuracao(trace, CONFIG_BENCHMARK_A, csv, 1);
        if (csv) fclose(csv);
        return erro;
    }

    const int l1_tamanhos[] = {4096, 8192};
    const int l1_vias[]     = {2, 4};
    const int l2_tamanhos[] = {32768, 131072};
    const int l2_vias[]     = {8, 16};

    int erros = 0;
    for (int a = 0; a < 2; a++) {
        for (int b = 0; b < 2; b++) {
            for (int c = 0; c < 2; c++) {
                for (int d = 0; d < 2; d++) {
                    ConfigCache cfg = {
                        l1_tamanhos[a],
                        l1_vias[b],
                        l2_tamanhos[c],
                        l2_vias[d]
                    };
                    printf("=== Configuracao: L1=%dB/%d vias | L2=%dB/%d vias ===\n",
                           cfg.l1_tamanho, cfg.l1_vias,
                           cfg.l2_tamanho, cfg.l2_vias);
                    erros += rodar_configuracao(trace, cfg, csv, 0);
                }
            }
        }
    }

    if (csv) {
        fclose(csv);
        printf("CSV salvo com os resultados.\n");
    }

    return erros ? 1 : 0;
}
