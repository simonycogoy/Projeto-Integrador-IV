#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "cache.h"

/* L1 — opcoes validas: 4096 ou 8192 bytes, bloco 32 B, 2 ou 4 vias */
#define L1_TAMANHO_BYTES   4096
#define L1_BLOCO_BYTES     32
#define L1_VIAS            2

/* L2 — opcoes validas: 32768 a 131072 bytes, bloco 64 B, 8 ou 16 vias */
#define L2_TAMANHO_BYTES   32768
#define L2_BLOCO_BYTES     64
#define L2_VIAS            8

int main(int argc, char *argv[])
{
    if (argc != 2) {
        printf("Uso: %s <arquivo_trace>\n\n", argv[0]);
        return 1;
    }

    const char *arquivo_trace = argv[1];

    /* cria a hierarquia com os nomes traduzidos */
    HierarquiaCache *h = hierarquia_criar(
        L1_TAMANHO_BYTES, L1_BLOCO_BYTES, L1_VIAS,
        L2_TAMANHO_BYTES, L2_BLOCO_BYTES, L2_VIAS);

    if (!h) return 1;

    /* roda o trace usando o nome traduzido */
    long long n = hierarquia_rodar_trace(h, arquivo_trace);

    if (n == 0) {
        fprintf(stderr, "AVISO: nenhum acesso processado.\n"
                        "Verifique o arquivo '%s'.\n", arquivo_trace);
    } else {
        printf("Acessos processados: %lld\n\n", n);
        hierarquia_imprimir_estatisticas(h);
    }

    hierarquia_destruir(h);
    return 0;
}