#ifndef CACHE_H
#define CACHE_H

#include <stdint.h>

/* =========================================================
 * CONSTANTES DAS POLITICAS
 * =========================================================
 * RRPV usa 2 bits:
 *   0 = reuso muito proximo
 *   2 = insercao distante/SRRIP
 *   3 = candidato forte a vitima/BRRIP comum
 */
#define RRPV_PROXIMO   0
#define RRPV_DISTANTE  2
#define RRPV_MORTO     3
#define RRPV_MAX       3

/* DRRIP: BRRIP insere como "distante" 1 vez a cada 32 insercoes. */
#define BRRIP_PROB     32

/* PSEL de 10 bits, como e comum em set dueling. */
#define PSEL_MAX       1023
#define PSEL_MEIO      (PSEL_MAX / 2)

/*
 * Conjuntos monitores por cache.
 * Valor 8 funciona melhor aqui do que 32 porque algumas configuracoes
 * da especificacao tem apenas 32 conjuntos; com 32 nao sobrariam
 * conjuntos seguidores para o PSEL realmente decidir.
 */
#define NUM_MONITORES  8

/* =========================================================
 * ESTRUTURAS DE DADOS
 * ========================================================= */
typedef struct {
    uint32_t etiqueta;
    int      valido;
    int      bit_sujo;

    /* Metadados para politicas */
    int rrpv;
    int idade_lru;
} BlocoCache;

typedef struct {
    BlocoCache *vias;
} ConjuntoCache;

typedef struct {
    ConjuntoCache *conjuntos;

    int tamanho_total_bytes;
    int tamanho_bloco_bytes;
    int num_vias;
    int num_conjuntos;

    int bits_deslocamento;
    int bits_indice;

    char nome[8];

    long long acertos;
    long long falhas;
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

/* Funcoes de politica */
void politica_no_acerto(Cache *cache, ConjuntoCache *conjunto, int indice_via);
int politica_selecionar_vitima(Cache *cache, ConjuntoCache *conjunto);
void politica_na_insercao(Cache *cache, ConjuntoCache *conjunto, int indice_via);

/* API da hierarquia */
HierarquiaCache *hierarquia_criar(int t1, int b1, int v1, int t2, int b2, int v2);
void hierarquia_destruir(HierarquiaCache *h);
int hierarquia_acessar(HierarquiaCache *h, uint32_t endereco);
long long hierarquia_rodar_trace(HierarquiaCache *h, const char *arquivo);
void hierarquia_imprimir_estatisticas(const HierarquiaCache *h);
void hierarquia_resetar_estatisticas(HierarquiaCache *h);

#endif
