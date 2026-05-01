#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "cache.h"

/* =========================================================
 *  CONFIGURACOES DO PROJETO
 *
 *  Ajuste estes defines para testar as combinacoes
 *  exigidas pela especificacao (Benchmark A, B, etc.)
 * ========================================================= */

/* L1 — opcoes validas: 4096 ou 8192 bytes, bloco 32 B, 2 ou 4 vias */
#define L1_SIZE_BYTES   4096
#define L1_BLOCK_BYTES  32
#define L1_WAYS         2

/* L2 — opcoes validas: 32768 a 131072 bytes, bloco 64 B, 8 ou 16 vias */
#define L2_SIZE_BYTES   32768
#define L2_BLOCK_BYTES  64
#define L2_WAYS         8

/* =========================================================
 *  MAIN
 * ========================================================= */

int main(int argc, char *argv[])
{
    if (argc != 2) {
        printf("Uso: %s <arquivo_trace>\n\n", argv[0]);
        printf("Formato do trace (um endereco por linha):\n");
        printf("  0x1A2B3C\n");
        printf("  1A2B3C\n");
        printf("  # comentarios sao ignorados\n");
        return 1;
    }

    const char *tracefile = argv[1];

    /* cria a hierarquia com os parametros definidos acima */
    CacheHierarchy *h = hierarchy_create(
        L1_SIZE_BYTES, L1_BLOCK_BYTES, L1_WAYS,
        L2_SIZE_BYTES, L2_BLOCK_BYTES, L2_WAYS);

    if (!h) return 1;

    /* roda o trace */
    long long n = hierarchy_run_trace(h, tracefile);

    if (n == 0) {
        fprintf(stderr, "AVISO: nenhum acesso processado.\n"
                        "Verifique o arquivo '%s'.\n", tracefile);
    } else {
        printf("Acessos processados: %lld\n\n", n);
        hierarchy_print_stats(h);
    }

    hierarchy_destroy(h);
    return 0;
}
