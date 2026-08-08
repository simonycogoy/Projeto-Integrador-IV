#ifndef CACHE_H
#define CACHE_H

#include <stdint.h>
#include <stdio.h>

#define RRPV_MAX       3
#define RRPV_DISTANTE  2
#define RRPV_MORTO     3
#define PSEL_BITS      10
#define PSEL_MAX       ((1 << PSEL_BITS) - 1)
#define PSEL_MEIO      (PSEL_MAX / 2)
#define BRRIP_PROB     32

typedef struct BlocoCache {
    uint32_t etiqueta;
    unsigned char valido;
    unsigned char bit_sujo;

    /* LRU: 0 = mais recente; valor maior = mais antigo */
    unsigned int idade_lru;

    /* DRRIP: 0 = reuso proximo; 3 = candidato a vitima */
    unsigned char rrpv;
} BlocoCache;

typedef struct ConjuntoCache {
    BlocoCache *vias;
} ConjuntoCache;

struct Cache;

typedef struct PoliticaCache {
    const char *nome;
    void (*inicializar_cache)(struct Cache *cache);
    void (*destruir_cache)(struct Cache *cache);
    void (*inicializar_bloco)(struct Cache *cache, BlocoCache *bloco, int via);
    void (*no_acerto)(struct Cache *cache, ConjuntoCache *conjunto, int via);
    int  (*selecionar_vitima)(struct Cache *cache, ConjuntoCache *conjunto);
    void (*na_insercao)(struct Cache *cache, ConjuntoCache *conjunto, int via);
    void (*imprimir_extra)(const struct Cache *cache);
} PoliticaCache;

typedef struct Cache {
    int tamanho_total_bytes;
    int tamanho_bloco_bytes;
    int num_vias;
    int num_conjuntos;
    int bits_deslocamento;
    int bits_indice;
    char nome[16];

    ConjuntoCache *conjuntos;
    const PoliticaCache *politica;
    void *estado_politica;

    long long acessos_totais;
    long long acertos;
    long long falhas;
} Cache;

typedef struct HierarquiaCache {
    Cache *l1;
    Cache *l2;
    const PoliticaCache *politica;

    long long acessos_totais;
    long long acertos_l1;
    long long acertos_l2;
    long long acessos_memoria;
} HierarquiaCache;

extern const PoliticaCache POLITICA_LRU;
extern const PoliticaCache POLITICA_DRRIP;

Cache *cache_criar(int bytes_totais, int bytes_bloco, int vias,
                   const char *nome, const PoliticaCache *politica);
void cache_destruir(Cache *cache);
int cache_acessar(Cache *cache, uint32_t endereco, int escrita);
void cache_imprimir_estatisticas(const Cache *cache);

HierarquiaCache *hierarquia_criar(const PoliticaCache *politica,
                                  int total_l1, int bloco_l1, int vias_l1,
                                  int total_l2, int bloco_l2, int vias_l2);
void hierarquia_destruir(HierarquiaCache *h);
int hierarquia_acessar(HierarquiaCache *h, uint32_t endereco, int escrita);
long long hierarquia_rodar_trace(HierarquiaCache *h, const char *nome_arquivo,
                                  int verbose, long long limite_verbose);
void hierarquia_imprimir_estatisticas(const HierarquiaCache *h);

uint32_t cache_obter_indice(const Cache *cache, uint32_t endereco);
uint32_t cache_obter_etiqueta(const Cache *cache, uint32_t endereco);
int cache_indice_do_conjunto(const Cache *cache, const ConjuntoCache *conjunto);

#endif
