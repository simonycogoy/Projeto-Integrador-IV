#ifndef CACHE_H
#define CACHE_H

#include <stdint.h>

/* =========================================================
 *  ESTRUTURAS DE DADOS
 * ========================================================= */

/*
 * Bloco: unidade minima do cache.
 * Cada via (way) de um conjunto e representada por um bloco.
 *
 * Os campos de metadado (rrpv, lru_age, etc.) ficam aqui.
 * Cada grupo vai preencher os que precisar para sua politica.
 */
typedef struct {
    uint32_t tag;       /* identifica qual endereco de memoria esta aqui */
    int      valid;     /* 1 = bloco tem dado real | 0 = slot vazio      */
    int      dirty;     /* 1 = dado foi modificado (write-back pendente) */

    /*
     * Campos de metadado para as politicas.
     * Cada grupo usa o que precisar — os demais ficam ignorados.
     */
    int rrpv;           /* Re-reference Prediction Value (SRRIP/BRRIP/DRRIP) */
    int lru_age;        /* idade para LRU (0 = MRU, maior = mais antigo)      */
} CacheBlock;

/*
 * Conjunto (Set): grupo de 'num_ways' blocos lado a lado.
 * A associatividade do cache e o numero de blocos por conjunto.
 */
typedef struct {
    CacheBlock *ways;   /* array de blocos deste conjunto */
} CacheSet;

/*
 * Cache: estrutura principal.
 * Agrupa todos os conjuntos e os parametros de configuracao.
 */
typedef struct {
    CacheSet *sets;             /* array de conjuntos                         */

    int total_size_bytes;       /* capacidade total  (ex: 4096 para 4 KB)     */
    int block_size_bytes;       /* tamanho do bloco  (ex: 32 bytes na L1)     */
    int num_ways;               /* associatividade   (ex: 2, 4, 8, 16)        */
    int num_sets;               /* calculado: total / (bloco * vias)          */

    int offset_bits;            /* bits menos significativos do endereco      */
    int index_bits;             /* bits do meio do endereco                   */
    /* os bits restantes (mais significativos) formam a tag */

    char name[8];               /* rotulo para impressao: "L1" ou "L2"       */

    /* metricas */
    long long hits;
    long long misses;
    long long total_accesses;
} Cache;

/*
 * Hierarquia L1 + L2.
 * Um acesso passa primeiro pela L1; se falhar, vai para a L2;
 * se falhar novamente, conta como acesso a memoria principal.
 */
typedef struct {
    Cache *l1;
    Cache *l2;

    long long total_accesses;
    long long l1_hits;
    long long l2_hits;
    long long mem_accesses;     /* misses em ambas -> memoria principal */
} CacheHierarchy;

/* =========================================================
 *  API DA CACHE INDIVIDUAL
 * ========================================================= */

/*
 * Cria e inicializa uma cache com os parametros fornecidos.
 * Todos os blocos comecam invalidos (valid = 0).
 *
 *   total_bytes - capacidade total em bytes
 *   block_bytes - tamanho de cada bloco em bytes
 *   ways        - numero de vias (associatividade)
 *   name        - rotulo para impressao ("L1" ou "L2")
 */
Cache *cache_create(int total_bytes, int block_bytes, int ways,
                    const char *name);

/*
 * Libera toda a memoria alocada pela cache.
 */
void cache_destroy(Cache *cache);

/*
 * Acessa um endereco na cache.
 *
 * Esta funcao faz a parte estrutural:
 *   1. Calcula qual conjunto e qual tag correspondem ao endereco
 *   2. Verifica se algum bloco valido tem aquela tag (hit ou miss)
 *   3. Em caso de miss, chama select_victim() para escolher a vitima
 *   4. Insere o novo bloco no lugar da vitima
 *
 * A LOGICA DE POLITICA (como escolher a vitima, como atualizar
 * metadados em hits/misses) fica em funcoes separadas que
 * cada grupo vai implementar.
 *
 * Retorna: 1 se hit, 0 se miss.
 */
int cache_access(Cache *cache, uint32_t address);

/*
 * Imprime as metricas acumuladas (hits, misses, hit rate).
 */
void cache_print_stats(const Cache *cache);

/*
 * Zera os contadores de metricas sem destruir a cache.
 */
void cache_reset_stats(Cache *cache);

/* =========================================================
 *  FUNCOES DE POLITICA — IMPLEMENTAR NO SEU ARQUIVO
 *
 *  Estas funcoes sao chamadas por cache_access() nos
 *  momentos certos. Cada grupo implementa as suas aqui
 *  (ou em um .c separado, como preferirem).
 * ========================================================= */

/*
 * Chamada em todo acerto (hit).
 * Aqui voce atualiza os metadados do bloco que foi acertado.
 *
 * Exemplos:
 *   LRU   -> move o bloco para MRU (lru_age = 0)
 *   SRRIP -> seta rrpv = 0 (hit promotion)
 */
void policy_on_hit(Cache *cache, CacheSet *set, int way_index);

/*
 * Chamada em toda falta (miss), antes da insercao.
 * Escolhe qual via sera substituida e retorna seu indice.
 *
 * Exemplos:
 *   LRU   -> retorna a via com maior lru_age
 *   SRRIP -> procura rrpv == 3, envelhece se nao achar
 */
int policy_select_victim(Cache *cache, CacheSet *set);

/*
 * Chamada logo apos a insercao de um novo bloco.
 * Aqui voce define os metadados iniciais do bloco inserido.
 *
 * Exemplos:
 *   LRU   -> lru_age = 0, envelhece os demais
 *   SRRIP -> rrpv = 2 (insercao longa)
 *   BRRIP -> rrpv = 3 na maioria, rrpv = 2 com prob. 1/32
 */
void policy_on_insert(Cache *cache, CacheSet *set, int way_index);

/* =========================================================
 *  API DA HIERARQUIA
 * ========================================================= */

/*
 * Cria a hierarquia com dois niveis de cache.
 * As politicas de cada nivel sao configuradas separadamente
 * (via as funcoes policy_* acima ou por parametros proprios).
 */
CacheHierarchy *hierarchy_create(
    int total_l1, int block_l1, int ways_l1,
    int total_l2, int block_l2, int ways_l2);

/*
 * Libera hierarquia e as duas caches.
 */
void hierarchy_destroy(CacheHierarchy *h);

/*
 * Acesso na hierarquia: L1 -> L2 -> Memoria.
 *
 * Retorna:
 *   2 = hit na L1
 *   1 = miss na L1, hit na L2
 *   0 = miss em ambas (acesso a memoria)
 */
int hierarchy_access(CacheHierarchy *h, uint32_t address);

/*
 * Le um arquivo de trace e executa todos os acessos na hierarquia.
 *
 * Formato do arquivo — um endereco por linha:
 *   0x1A2B3C   (com prefixo hex)
 *   1A2B3C     (sem prefixo)
 *   # comentario  (linhas com # sao ignoradas)
 *
 * Retorna o numero de acessos processados.
 */
long long hierarchy_run_trace(CacheHierarchy *h, const char *filename);

/*
 * Imprime estatisticas completas da hierarquia (L1, L2 e totais).
 */
void hierarchy_print_stats(const CacheHierarchy *h);

/*
 * Zera todos os contadores da hierarquia.
 */
void hierarchy_reset_stats(CacheHierarchy *h);

#endif /* CACHE_H */
