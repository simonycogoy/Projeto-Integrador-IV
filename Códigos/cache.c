#include "cache.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* =========================================================
 *  FUNCOES INTERNAS — CALCULO DE ENDERECO
 * ========================================================= */

/* retorna log2 inteiro de n (ex: 32 -> 5, 64 -> 6) */
static int log2_int(int n)
{
    int r = 0;
    while (n > 1) { n >>= 1; r++; }
    return r;
}

/* extrai o indice do conjunto a partir do endereco */
static uint32_t get_index(Cache *c, uint32_t addr)
{
    uint32_t mask = (1u << c->index_bits) - 1u;
    return (addr >> c->offset_bits) & mask;
}

/* extrai a tag a partir do endereco */
static uint32_t get_tag(Cache *c, uint32_t addr)
{
    return addr >> (c->offset_bits + c->index_bits);
}

/* =========================================================
 *  API DA CACHE INDIVIDUAL
 * ========================================================= */

Cache *cache_create(int total_bytes, int block_bytes, int ways,
                    const char *name)
{
    Cache *c = (Cache *)malloc(sizeof(Cache));
    if (!c) {
        fprintf(stderr, "ERRO: nao foi possivel alocar a cache '%s'\n", name);
        return NULL;
    }

    c->total_size_bytes = total_bytes;
    c->block_size_bytes = block_bytes;
    c->num_ways         = ways;
    c->num_sets         = total_bytes / (block_bytes * ways);
    c->offset_bits      = log2_int(block_bytes);
    c->index_bits       = log2_int(c->num_sets);
    c->hits             = 0;
    c->misses           = 0;
    c->total_accesses   = 0;

    strncpy(c->name, name ? name : "?", 7);
    c->name[7] = '\0';

    /* aloca os conjuntos */
    c->sets = (CacheSet *)malloc(c->num_sets * sizeof(CacheSet));
    if (!c->sets) {
        fprintf(stderr, "ERRO: nao foi possivel alocar os conjuntos\n");
        free(c);
        return NULL;
    }

    /* aloca e inicializa os blocos de cada conjunto */
    int i, j;
    for (i = 0; i < c->num_sets; i++) {
        c->sets[i].ways = (CacheBlock *)malloc(ways * sizeof(CacheBlock));
        if (!c->sets[i].ways) {
            fprintf(stderr, "ERRO: nao foi possivel alocar blocos do conjunto %d\n", i);
            for (j = 0; j < i; j++) free(c->sets[j].ways);
            free(c->sets);
            free(c);
            return NULL;
        }

        /* todos os blocos comecam invalidos */
        for (j = 0; j < ways; j++) {
            c->sets[i].ways[j].tag     = 0;
            c->sets[i].ways[j].valid   = 0;
            c->sets[i].ways[j].dirty   = 0;
            c->sets[i].ways[j].rrpv    = 0;
            c->sets[i].ways[j].lru_age = 0;
        }
    }

    printf("[%s] %d bytes | bloco %d B | %d vias | %d conjuntos\n",
           c->name, total_bytes, block_bytes, ways, c->num_sets);
    printf("      offset=%d bits | index=%d bits | tag=%d bits\n",
           c->offset_bits, c->index_bits,
           32 - c->offset_bits - c->index_bits);

    return c;
}

void cache_destroy(Cache *c)
{
    if (!c) return;
    int i;
    for (i = 0; i < c->num_sets; i++)
        free(c->sets[i].ways);
    free(c->sets);
    free(c);
}

int cache_access(Cache *c, uint32_t address)
{
    c->total_accesses++;

    /* 1. descobre qual conjunto e qual tag correspondem ao endereco */
    uint32_t idx = get_index(c, address);
    uint32_t tag = get_tag(c, address);
    CacheSet *set = &c->sets[idx];

    /* 2. procura o bloco no conjunto */
    int i;
    for (i = 0; i < c->num_ways; i++) {
        if (set->ways[i].valid && set->ways[i].tag == tag) {
            /* ===== HIT ===== */
            c->hits++;

            /*
             * PONTO DE POLITICA — HIT
             * Chama a funcao que cada grupo vai implementar.
             * Ex: LRU atualiza lru_age, SRRIP seta rrpv = 0.
             */
            policy_on_hit(c, set, i);

            return 1;
        }
    }

    /* ===== MISS ===== */
    c->misses++;

    /*
     * 3. procura um slot invalido primeiro.
     * Slot invalido tem prioridade total — nao precisa expulsar ninguem.
     */
    int victim = -1;
    for (i = 0; i < c->num_ways; i++) {
        if (!set->ways[i].valid) {
            victim = i;
            break;
        }
    }

    /*
     * 4. se nao ha slot invalido, chama a politica para escolher a vitima.
     *
     * PONTO DE POLITICA — SELECAO DE VITIMA
     * Cada grupo implementa esta funcao com sua logica.
     * Ex: LRU retorna a via com maior lru_age.
     *     SRRIP procura rrpv == 3, envelhece se nao achar.
     */
    if (victim == -1)
        victim = policy_select_victim(c, set);

    /* 5. insere o novo bloco no slot escolhido */
    set->ways[victim].tag   = tag;
    set->ways[victim].valid = 1;
    set->ways[victim].dirty = 0;

    /*
     * PONTO DE POLITICA — INSERCAO
     * Define os metadados iniciais do bloco recem-inserido.
     * Ex: LRU seta lru_age = 0 e envelhece os demais.
     *     SRRIP seta rrpv = 2.
     *     BRRIP seta rrpv = 3 na maioria, rrpv = 2 com prob. 1/32.
     */
    policy_on_insert(c, set, victim);

    return 0;
}

void cache_print_stats(const Cache *c)
{
    double hr = (c->total_accesses > 0)
                ? (double)c->hits / c->total_accesses * 100.0
                : 0.0;

    printf("  [%s] acessos=%-8lld  hits=%-8lld  misses=%-8lld  hit_rate=%.2f%%\n",
           c->name, c->total_accesses, c->hits, c->misses, hr);
}

void cache_reset_stats(Cache *c)
{
    c->hits = c->misses = c->total_accesses = 0;
}

/* =========================================================
 *  FUNCOES DE POLITICA — STUBS
 *
 *  Estas funcoes estao vazias de proposito.
 *  Cada grupo substitui o corpo delas pela logica da sua politica.
 *
 *  Se preferirem, podem mover estas funcoes para um arquivo
 *  separado (ex: policy_brrip.c) e apenas declarar os prototipos
 *  no cache.h. O importante e que os nomes batem.
 * ========================================================= */

void policy_on_hit(Cache *cache, CacheSet *set, int way_index)
{
    /* TODO: implementar logica de hit da sua politica */
    (void)cache;
    (void)set;
    (void)way_index;
}

int policy_select_victim(Cache *cache, CacheSet *set)
{
    /* TODO: implementar selecao de vitima da sua politica */
    /* retorna 0 como fallback (substitui sempre a via 0) */
    (void)cache;
    (void)set;
    return 0;
}

void policy_on_insert(Cache *cache, CacheSet *set, int way_index)
{
    /* TODO: implementar logica de insercao da sua politica */
    (void)cache;
    (void)set;
    (void)way_index;
}

/* =========================================================
 *  API DA HIERARQUIA L1 + L2
 * ========================================================= */

CacheHierarchy *hierarchy_create(
    int total_l1, int block_l1, int ways_l1,
    int total_l2, int block_l2, int ways_l2)
{
    CacheHierarchy *h = (CacheHierarchy *)malloc(sizeof(CacheHierarchy));
    if (!h) {
        fprintf(stderr, "ERRO: nao foi possivel alocar a hierarquia\n");
        return NULL;
    }

    printf("=== Criando hierarquia de cache ===\n");
    h->l1 = cache_create(total_l1, block_l1, ways_l1, "L1");
    h->l2 = cache_create(total_l2, block_l2, ways_l2, "L2");
    printf("===================================\n\n");

    if (!h->l1 || !h->l2) {
        cache_destroy(h->l1);
        cache_destroy(h->l2);
        free(h);
        return NULL;
    }

    h->total_accesses = 0;
    h->l1_hits        = 0;
    h->l2_hits        = 0;
    h->mem_accesses   = 0;

    return h;
}

void hierarchy_destroy(CacheHierarchy *h)
{
    if (!h) return;
    cache_destroy(h->l1);
    cache_destroy(h->l2);
    free(h);
}

int hierarchy_access(CacheHierarchy *h, uint32_t address)
{
    h->total_accesses++;

    /* 1. tenta L1 */
    if (cache_access(h->l1, address)) {
        h->l1_hits++;
        return 2;
    }

    /* 2. miss na L1 — tenta L2 */
    if (cache_access(h->l2, address)) {
        h->l2_hits++;
        return 1;
    }

    /* 3. miss em ambas — acesso a memoria principal */
    h->mem_accesses++;
    return 0;
}

long long hierarchy_run_trace(CacheHierarchy *h, const char *filename)
{
    FILE *fp = fopen(filename, "r");
    if (!fp) {
        fprintf(stderr, "ERRO: nao foi possivel abrir '%s'\n", filename);
        return 0;
    }

    char     line[64];
    uint32_t address;
    long long count = 0;

    while (fgets(line, sizeof(line), fp)) {
        /* ignora linhas vazias e comentarios */
        if (line[0] == '#' || line[0] == '\n' || line[0] == '\r')
            continue;

        /* aceita "0x1A2B3C" ou "1A2B3C" */
        char *ptr = line;
        if (ptr[0] == '0' && (ptr[1] == 'x' || ptr[1] == 'X'))
            ptr += 2;

        if (sscanf(ptr, "%x", &address) == 1) {
            hierarchy_access(h, address);
            count++;
        }
    }

    fclose(fp);
    return count;
}

void hierarchy_print_stats(const CacheHierarchy *h)
{
    double l1_hr  = 0.0, l2_hr = 0.0, global_hr = 0.0;

    if (h->total_accesses > 0) {
        l1_hr     = (double)h->l1_hits / h->total_accesses * 100.0;
        global_hr = (double)(h->l1_hits + h->l2_hits) / h->total_accesses * 100.0;
    }
    if (h->l1->misses > 0)
        l2_hr = (double)h->l2_hits / h->l1->misses * 100.0;

    printf("============= ESTATISTICAS DA HIERARQUIA =============\n");
    printf("  Total de acessos     : %lld\n",   h->total_accesses);
    printf("  Hits na L1           : %lld  (%.2f%% do total)\n",
           h->l1_hits, l1_hr);
    printf("  Hits na L2           : %lld  (%.2f%% dos misses L1)\n",
           h->l2_hits, l2_hr);
    printf("  Acessos a memoria    : %lld\n",   h->mem_accesses);
    printf("  Hit rate global      : %.2f%%\n", global_hr);
    printf("------------------------------------------------------\n");
    cache_print_stats(h->l1);
    cache_print_stats(h->l2);
    printf("======================================================\n\n");
}

void hierarchy_reset_stats(CacheHierarchy *h)
{
    cache_reset_stats(h->l1);
    cache_reset_stats(h->l2);
    h->total_accesses = h->l1_hits = h->l2_hits = h->mem_accesses = 0;
}
