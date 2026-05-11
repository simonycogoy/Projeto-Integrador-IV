#include "cache.h"
#include <stdlib.h>

/* =========================================================
 * cache_drrip.c — DRRIP: Dynamic Re-Reference Interval Prediction
 *
 * Ideia para RTL:
 *   - cada bloco guarda RRPV de 2 bits;
 *   - HIT: RRPV = 0;
 *   - vitima: procurar RRPV = 3; se nao houver, incrementar RRPVs;
 *   - SRRIP insere em RRPV = 2;
 *   - BRRIP insere quase sempre em RRPV = 3, raramente em 2;
 *   - PSEL escolhe dinamicamente SRRIP ou BRRIP para os conjuntos seguidores.
 * ========================================================= */

typedef struct EstadoDRRIP {
    unsigned int psel;
    unsigned int brrip_counter;
    int monitores_por_politica;
} EstadoDRRIP;

static EstadoDRRIP *estado(const Cache *cache)
{
    return (EstadoDRRIP *)cache->estado_politica;
}

static void drrip_inicializar_cache(Cache *cache)
{
    EstadoDRRIP *e = (EstadoDRRIP *)calloc(1, sizeof(EstadoDRRIP));
    if (!e) return;
    e->psel = PSEL_MEIO;
    e->brrip_counter = 0;

    /* Para caches pequenas, nao adianta reservar conjuntos demais para dueling. */
    e->monitores_por_politica = cache->num_conjuntos / 16;
    if (e->monitores_por_politica < 1) e->monitores_por_politica = 1;
    if (e->monitores_por_politica > 8) e->monitores_por_politica = 8;

    cache->estado_politica = e;
}

static void drrip_destruir_cache(Cache *cache)
{
    free(cache->estado_politica);
    cache->estado_politica = NULL;
}

static void drrip_inicializar_bloco(Cache *cache, BlocoCache *bloco, int via)
{
    (void)cache; (void)via;
    bloco->rrpv = RRPV_MAX;
}

static int drrip_tipo_conjunto(Cache *cache, int idx)
{
    EstadoDRRIP *e = estado(cache);
    if (idx < e->monitores_por_politica) return 1; /* monitor SRRIP */
    if (idx < 2 * e->monitores_por_politica) return 0; /* monitor BRRIP */
    return -1; /* seguidor */
}

static int drrip_usar_srrip(Cache *cache, int idx)
{
    int tipo = drrip_tipo_conjunto(cache, idx);
    EstadoDRRIP *e = estado(cache);

    if (tipo == 1) return 1;
    if (tipo == 0) return 0;

    /* Seguidor: usa a politica que esta vencendo no PSEL. */
    return e->psel >= PSEL_MEIO;
}

static void drrip_atualizar_psel_no_miss(Cache *cache, int idx)
{
    EstadoDRRIP *e = estado(cache);
    int tipo = drrip_tipo_conjunto(cache, idx);

    /* Convencao: miss em monitor SRRIP favorece BRRIP, miss em monitor BRRIP favorece SRRIP. */
    if (tipo == 1) {
        if (e->psel > 0) e->psel--;
    } else if (tipo == 0) {
        if (e->psel < PSEL_MAX) e->psel++;
    }
}

static void drrip_no_acerto(Cache *cache, ConjuntoCache *conjunto, int via)
{
    (void)cache;
    conjunto->vias[via].rrpv = 0;
}

static int drrip_selecionar_vitima(Cache *cache, ConjuntoCache *conjunto)
{
    int idx = cache_indice_do_conjunto(cache, conjunto);
    drrip_atualizar_psel_no_miss(cache, idx);

    while (1) {
        for (int via = 0; via < cache->num_vias; via++) {
            if (conjunto->vias[via].rrpv == RRPV_MAX)
                return via;
        }
        for (int via = 0; via < cache->num_vias; via++) {
            if (conjunto->vias[via].rrpv < RRPV_MAX)
                conjunto->vias[via].rrpv++;
        }
    }
}

static void drrip_na_insercao(Cache *cache, ConjuntoCache *conjunto, int via)
{
    EstadoDRRIP *e = estado(cache);
    int idx = cache_indice_do_conjunto(cache, conjunto);

    if (drrip_usar_srrip(cache, idx)) {
        conjunto->vias[via].rrpv = RRPV_DISTANTE; /* 2 */
    } else {
        /* BRRIP: 31/32 vezes entra como 'morto' e 1/32 como 'distante'. */
        e->brrip_counter = (e->brrip_counter + 1) % BRRIP_PROB;
        conjunto->vias[via].rrpv = (e->brrip_counter == 0) ? RRPV_DISTANTE : RRPV_MORTO;
    }
}

static void drrip_imprimir_extra(const Cache *cache)
{
    const EstadoDRRIP *e = (const EstadoDRRIP *)cache->estado_politica;
    if (!e) return;
    printf("      DRRIP: PSEL=%u (%s), monitores por politica=%d\n",
           e->psel,
           e->psel >= PSEL_MEIO ? "SRRIP dominante" : "BRRIP dominante",
           e->monitores_por_politica);
}

const PoliticaCache POLITICA_DRRIP = {
    "DRRIP",
    drrip_inicializar_cache,
    drrip_destruir_cache,
    drrip_inicializar_bloco,
    drrip_no_acerto,
    drrip_selecionar_vitima,
    drrip_na_insercao,
    drrip_imprimir_extra
};
