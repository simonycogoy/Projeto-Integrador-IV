#include "cache.h"

/* =========================================================
 * cache_lru.c — Politica LRU baseline
 *
 * Ideia para RTL:
 *   - cada via guarda uma idade pequena;
 *   - no HIT ou insercao, a via acessada recebe idade 0;
 *   - as demais vias validas envelhecem;
 *   - a vitima e a via com maior idade.
 * ========================================================= */

static void lru_inicializar_cache(Cache *cache)
{
    (void)cache;
}

static void lru_destruir_cache(Cache *cache)
{
    (void)cache;
}

static void lru_inicializar_bloco(Cache *cache, BlocoCache *bloco, int via)
{
    (void)cache;
    bloco->idade_lru = (unsigned int)via;
}

static void lru_atualizar(Cache *cache, ConjuntoCache *conjunto, int via_usada)
{
    for (int via = 0; via < cache->num_vias; via++) {
        if (conjunto->vias[via].valido && via != via_usada)
            conjunto->vias[via].idade_lru++;
    }
    conjunto->vias[via_usada].idade_lru = 0;
}

static void lru_no_acerto(Cache *cache, ConjuntoCache *conjunto, int via)
{
    lru_atualizar(cache, conjunto, via);
}

static int lru_selecionar_vitima(Cache *cache, ConjuntoCache *conjunto)
{
    int vitima = 0;
    for (int via = 1; via < cache->num_vias; via++) {
        if (conjunto->vias[via].idade_lru > conjunto->vias[vitima].idade_lru)
            vitima = via;
    }
    return vitima;
}

static void lru_na_insercao(Cache *cache, ConjuntoCache *conjunto, int via)
{
    lru_atualizar(cache, conjunto, via);
}

static void lru_imprimir_extra(const Cache *cache)
{
    (void)cache;
}

const PoliticaCache POLITICA_LRU = {
    "LRU",
    lru_inicializar_cache,
    lru_destruir_cache,
    lru_inicializar_bloco,
    lru_no_acerto,
    lru_selecionar_vitima,
    lru_na_insercao,
    lru_imprimir_extra
};
