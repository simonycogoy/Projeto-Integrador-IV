#ifndef CACHE_H
#define CACHE_H

#include <stdint.h>

/* =========================================================
 * ESTRUTURAS DE DADOS
 * ========================================================= */

typedef struct {
    uint32_t etiqueta;   /* Tag: identifica o endereço */
    int      valido;     /* 1 = bloco tem dado real | 0 = vazio */
    int      sujo;       /* 1 = modificado (dirty bit) */

    /* Metadados para políticas */
    int rrpv;           
    int idade_lru;      
} BlocoCache;

typedef struct {
    BlocoCache *vias;   /* Array de blocos deste conjunto */
} ConjuntoCache;

typedef struct {
    ConjuntoCache *conjuntos;

    int tamanho_total_bytes;
    int tamanho_bloco_bytes;
    int num_vias;
    int num_conjuntos;

    int bits_deslocamento;     /* Offset bits */
    int bits_indice;           /* Index bits */

    char nome[8];

    /* Métricas */
    long long acertos;         /* Hits */
    long long falhas;          /* Misses */
    long long acessos_totais;
} Cache;

typedef struct {
    Cache *l1;
    Cache *l2;

    long long acessos_totais;
    long long acertos_l1;
    long long acertos_l2;
    long long acessos_memoria;
} HierarquiaCache;

/* =========================================================
 * API DA CACHE
 * ========================================================= */

Cache *cache_criar(int bytes_totais, int bytes_bloco, int vias, const char *nome);
void cache_destruir(Cache *c);
int cache_acessar(Cache *c, uint32_t endereco);
void cache_imprimir_estatisticas(const Cache *c);
void cache_resetar_estatisticas(Cache *c);

/* Funções de Política */
void politica_no_acerto(Cache *cache, ConjuntoCache *conjunto, int indice_via);
int politica_selecionar_vitima(Cache *cache, ConjuntoCache *conjunto);
void politica_na_insercao(Cache *cache, ConjuntoCache *conjunto, int indice_via);

/* API da Hierarquia */
HierarquiaCache *hierarquia_criar(int t1, int b1, int v1, int t2, int b2, int v2);
void hierarquia_destruir(HierarquiaCache *h);
int hierarquia_acessar(HierarquiaCache *h, uint32_t endereco);
long long hierarquia_rodar_trace(HierarquiaCache *h, const char *arquivo);
void hierarquia_imprimir_estatisticas(const HierarquiaCache *h);

#endif