#include "cache.h"
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

static int log2_inteiro(int n)
{
    int r = 0;
    while (n > 1) { n >>= 1; r++; }
    return r;
}

static int eh_potencia_de_dois(int n)
{
    return n > 0 && (n & (n - 1)) == 0;
}

uint32_t cache_obter_indice(const Cache *cache, uint32_t endereco)
{
    uint32_t mascara = (1u << cache->bits_indice) - 1u;
    return (endereco >> cache->bits_deslocamento) & mascara;
}

uint32_t cache_obter_etiqueta(const Cache *cache, uint32_t endereco)
{
    return endereco >> (cache->bits_deslocamento + cache->bits_indice);
}

int cache_indice_do_conjunto(const Cache *cache, const ConjuntoCache *conjunto)
{
    return (int)(conjunto - cache->conjuntos);
}

Cache *cache_criar(int bytes_totais, int bytes_bloco, int vias,
                   const char *nome, const PoliticaCache *politica)
{
    if (!politica || !eh_potencia_de_dois(bytes_bloco) || !eh_potencia_de_dois(vias)) {
        fprintf(stderr, "ERRO: parametros invalidos para cache.\n");
        return NULL;
    }

    Cache *cache = (Cache *)calloc(1, sizeof(Cache));
    if (!cache) return NULL;

    cache->tamanho_total_bytes = bytes_totais;
    cache->tamanho_bloco_bytes = bytes_bloco;
    cache->num_vias = vias;
    cache->num_conjuntos = bytes_totais / (bytes_bloco * vias);
    cache->bits_deslocamento = log2_inteiro(bytes_bloco);
    cache->bits_indice = log2_inteiro(cache->num_conjuntos);
    cache->politica = politica;
    strncpy(cache->nome, nome ? nome : "CACHE", sizeof(cache->nome) - 1);

    if (cache->num_conjuntos <= 0 || !eh_potencia_de_dois(cache->num_conjuntos)) {
        fprintf(stderr, "ERRO: numero de conjuntos invalido para %s.\n", cache->nome);
        free(cache);
        return NULL;
    }

    cache->conjuntos = (ConjuntoCache *)calloc(cache->num_conjuntos, sizeof(ConjuntoCache));
    if (!cache->conjuntos) {
        free(cache);
        return NULL;
    }

    if (cache->politica->inicializar_cache)
        cache->politica->inicializar_cache(cache);

    for (int i = 0; i < cache->num_conjuntos; i++) {
        cache->conjuntos[i].vias = (BlocoCache *)calloc(cache->num_vias, sizeof(BlocoCache));
        if (!cache->conjuntos[i].vias) {
            for (int j = 0; j < i; j++) free(cache->conjuntos[j].vias);
            if (cache->politica->destruir_cache) cache->politica->destruir_cache(cache);
            free(cache->conjuntos);
            free(cache);
            return NULL;
        }
        for (int v = 0; v < cache->num_vias; v++) {
            cache->conjuntos[i].vias[v].valido = 0;
            cache->conjuntos[i].vias[v].bit_sujo = 0;
            cache->conjuntos[i].vias[v].etiqueta = 0;
            cache->conjuntos[i].vias[v].idade_lru = 0;
            cache->conjuntos[i].vias[v].rrpv = RRPV_MAX;
            if (cache->politica->inicializar_bloco)
                cache->politica->inicializar_bloco(cache, &cache->conjuntos[i].vias[v], v);
        }
    }

    printf("[%s/%s] %dB | bloco=%dB | %d vias | %d conjuntos | off=%d idx=%d tag=%d\n",
           cache->nome, cache->politica->nome,
           cache->tamanho_total_bytes, cache->tamanho_bloco_bytes,
           cache->num_vias, cache->num_conjuntos,
           cache->bits_deslocamento, cache->bits_indice,
           32 - cache->bits_deslocamento - cache->bits_indice);

    return cache;
}

void cache_destruir(Cache *cache)
{
    if (!cache) return;
    for (int i = 0; i < cache->num_conjuntos; i++)
        free(cache->conjuntos[i].vias);
    if (cache->politica && cache->politica->destruir_cache)
        cache->politica->destruir_cache(cache);
    free(cache->conjuntos);
    free(cache);
}

int cache_acessar(Cache *cache, uint32_t endereco, int escrita)
{
    cache->acessos_totais++;

    uint32_t indice = cache_obter_indice(cache, endereco);
    uint32_t etiqueta = cache_obter_etiqueta(cache, endereco);
    ConjuntoCache *conjunto = &cache->conjuntos[indice];

    for (int via = 0; via < cache->num_vias; via++) {
        BlocoCache *b = &conjunto->vias[via];
        if (b->valido && b->etiqueta == etiqueta) {
            cache->acertos++;
            if (escrita) b->bit_sujo = 1;
            cache->politica->no_acerto(cache, conjunto, via);
            return 1;
        }
    }

    cache->falhas++;

    int vitima = -1;
    for (int via = 0; via < cache->num_vias; via++) {
        if (!conjunto->vias[via].valido) { vitima = via; break; }
    }
    if (vitima < 0)
        vitima = cache->politica->selecionar_vitima(cache, conjunto);

    BlocoCache *b = &conjunto->vias[vitima];
    b->etiqueta = etiqueta;
    b->valido = 1;
    b->bit_sujo = escrita ? 1 : 0;
    cache->politica->na_insercao(cache, conjunto, vitima);

    return 0;
}

void cache_imprimir_estatisticas(const Cache *cache)
{
    double taxa = cache->acessos_totais ?
        (double)cache->acertos * 100.0 / (double)cache->acessos_totais : 0.0;
    printf("  %-2s: acessos=%-8lld acertos=%-8lld falhas=%-8lld hit=%.2f%%\n",
           cache->nome, cache->acessos_totais, cache->acertos, cache->falhas, taxa);
    if (cache->politica->imprimir_extra)
        cache->politica->imprimir_extra(cache);
}

HierarquiaCache *hierarquia_criar(const PoliticaCache *politica,
                                  int total_l1, int bloco_l1, int vias_l1,
                                  int total_l2, int bloco_l2, int vias_l2)
{
    HierarquiaCache *h = (HierarquiaCache *)calloc(1, sizeof(HierarquiaCache));
    if (!h) return NULL;
    h->politica = politica;

    printf("\n=== Hierarquia %s ===\n", politica->nome);
    h->l1 = cache_criar(total_l1, bloco_l1, vias_l1, "L1", politica);
    h->l2 = cache_criar(total_l2, bloco_l2, vias_l2, "L2", politica);
    printf("=====================%s\n\n", strlen(politica->nome) > 4 ? "==" : "");

    if (!h->l1 || !h->l2) {
        hierarquia_destruir(h);
        return NULL;
    }
    return h;
}

void hierarquia_destruir(HierarquiaCache *h)
{
    if (!h) return;
    cache_destruir(h->l1);
    cache_destruir(h->l2);
    free(h);
}

int hierarquia_acessar(HierarquiaCache *h, uint32_t endereco, int escrita)
{
    h->acessos_totais++;

    if (cache_acessar(h->l1, endereco, escrita)) {
        h->acertos_l1++;
        return 2;
    }

    if (cache_acessar(h->l2, endereco, escrita)) {
        h->acertos_l2++;
        return 1;
    }

    h->acessos_memoria++;
    return 0;
}

static int parse_linha_trace(char *linha, uint32_t *endereco, int *escrita)
{
    char *p = linha;
    while (isspace((unsigned char)*p)) p++;
    if (*p == '#' || *p == '\0') return 0;

    *escrita = 0;
    if (*p == 'R' || *p == 'r') { *escrita = 0; p++; }
    else if (*p == 'W' || *p == 'w') { *escrita = 1; p++; }

    while (isspace((unsigned char)*p)) p++;
    if (p[0] == '0' && (p[1] == 'x' || p[1] == 'X')) p += 2;

    unsigned int valor = 0;
    if (sscanf(p, "%x", &valor) == 1) {
        *endereco = (uint32_t)valor;
        return 1;
    }
    return 0;
}

long long hierarquia_rodar_trace(HierarquiaCache *h, const char *nome_arquivo,
                                  int verbose, long long limite_verbose)
{
    FILE *fp = fopen(nome_arquivo, "r");
    if (!fp) {
        fprintf(stderr, "ERRO: nao foi possivel abrir '%s'\n", nome_arquivo);
        return 0;
    }

    char linha[128];
    uint32_t endereco;
    int escrita;
    long long n = 0;

    while (fgets(linha, sizeof(linha), fp)) {
        if (!parse_linha_trace(linha, &endereco, &escrita)) continue;
        int resultado = hierarquia_acessar(h, endereco, escrita);
        n++;
        if (verbose && n <= limite_verbose) {
            printf("%6lld  %c 0x%08X -> %s\n", n, escrita ? 'W' : 'R', endereco,
                   resultado == 2 ? "HIT L1" : (resultado == 1 ? "MISS L1 / HIT L2" : "MISS L1 / MISS L2"));
        }
    }

    fclose(fp);
    return n;
}

void hierarquia_imprimir_estatisticas(const HierarquiaCache *h)
{
    double hit_l1 = h->acessos_totais ?
        (double)h->acertos_l1 * 100.0 / (double)h->acessos_totais : 0.0;
    double hit_l2_local = h->l1->falhas ?
        (double)h->acertos_l2 * 100.0 / (double)h->l1->falhas : 0.0;
    double hit_global = h->acessos_totais ?
        (double)(h->acertos_l1 + h->acertos_l2) * 100.0 / (double)h->acessos_totais : 0.0;

    printf("============= RESULTADO %s =============\n", h->politica->nome);
    printf("Total de acessos : %lld\n", h->acessos_totais);
    printf("Acertos L1       : %lld  (%.2f%% do total)\n", h->acertos_l1, hit_l1);
    printf("Acertos L2       : %lld  (%.2f%% das falhas da L1)\n", h->acertos_l2, hit_l2_local);
    printf("Acessos a RAM    : %lld\n", h->acessos_memoria);
    printf("Hit rate global  : %.2f%%\n", hit_global);
    printf("----------------------------------------\n");
    cache_imprimir_estatisticas(h->l1);
    cache_imprimir_estatisticas(h->l2);
    printf("========================================\n\n");
}
