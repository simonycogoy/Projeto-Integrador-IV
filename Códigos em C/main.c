#include <stdio.h>
#include <stdlib.h>
#include "cache.h"

/* Benchmark A da especificacao */
#define L1_TAMANHO   4096
#define L1_BLOCO       32
#define L1_VIAS         2
#define L2_TAMANHO  32768
#define L2_BLOCO       64
#define L2_VIAS         8

int main(int argc, char *argv[]){
    if(argc!=2){
        printf("Uso: %s <trace.txt>\n",argv[0]);
        printf("Traces disponiveis:\n");
        printf("  trace_validacao.txt  — pequeno, comportamento visivel\n");
        printf("  trace_streaming.txt  — scan longo, LRU vs DRRIP\n");
        printf("  trace_matrix.txt     — convolucao 2D\n");
        printf("  trace_linked_list.txt\n");
        printf("  trace_pattern.txt\n");
        return 1;
    }
    HierarquiaCache *h=hierarquia_criar(
        L1_TAMANHO,L1_BLOCO,L1_VIAS,
        L2_TAMANHO,L2_BLOCO,L2_VIAS);
    if(!h) return 1;
    long long n=hierarquia_rodar_trace(h,argv[1]);
    if(n==0) fprintf(stderr,"AVISO: nenhum acesso em '%s'\n",argv[1]);
    else{ printf("Acessos: %lld\n\n",n); hierarquia_imprimir_estatisticas(h); }
    hierarquia_destruir(h);
    return 0;
}
