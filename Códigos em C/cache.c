#include "cache.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* =========================================================
 * FUNÇÕES INTERNAS — CÁLCULO DE ENDEREÇO
 * ========================================================= */

/* retorna log2 inteiro de n (ex: 32 -> 5, 64 -> 6) */
static int log2_inteiro(int n)
{
    int r = 0;
    while (n > 1) { n >>= 1; r++; }
    return r;
}

/* extrai o índice do conjunto a partir do endereço */
static uint32_t obter_indice(Cache *c, uint32_t endereco)
{
    uint32_t mascara = (1u << c->bits_indice) - 1u;
    return (endereco >> c->bits_deslocamento) & mascara;
}

/* extrai a etiqueta (tag) a partir do endereço */
static uint32_t obter_etiqueta(Cache *c, uint32_t endereco)
{
    return endereco >> (c->bits_deslocamento + c->bits_indice);
}

/* =========================================================
 * API DA CACHE INDIVIDUAL
 * ========================================================= */

Cache *cache_criar(int bytes_totais, int bytes_bloco, int vias,
                    const char *nome)
{
    Cache *c = (Cache *)malloc(sizeof(Cache));
    if (!c) {
        fprintf(stderr, "ERRO: nao foi possivel alocar a cache '%s'\n", nome);
        return NULL;
    }

    c->tamanho_total_bytes = bytes_totais;
    c->tamanho_bloco_bytes = bytes_bloco;
    c->num_vias            = vias;
    c->num_conjuntos       = bytes_totais / (bytes_bloco * vias);
    c->bits_deslocamento   = log2_inteiro(bytes_bloco);
    c->bits_indice         = log2_inteiro(c->num_conjuntos);
    c->acertos             = 0;
    c->falhas              = 0;
    c->acessos_totais      = 0;

    strncpy(c->nome, nome ? nome : "?", 7);
    c->nome[7] = '\0';

    /* aloca os conjuntos */
    c->conjuntos = (ConjuntoCache *)malloc(c->num_conjuntos * sizeof(ConjuntoCache));
    if (!c->conjuntos) {
        fprintf(stderr, "ERRO: nao foi possivel alocar os conjuntos\n");
        free(c);
        return NULL;
    }

    /* aloca e inicializa os blocos de cada conjunto */
    int i, j;
    for (i = 0; i < c->num_conjuntos; i++) {
        c->conjuntos[i].vias = (BlocoCache *)malloc(vias * sizeof(BlocoCache));
        if (!c->conjuntos[i].vias) {
            fprintf(stderr, "ERRO: nao foi possivel alocar blocos do conjunto %d\n", i);
            for (j = 0; j < i; j++) free(c->conjuntos[j].vias);
            free(c->conjuntos);
            free(c);
            return NULL;
        }

        /* todos os blocos começam inválidos */
        for (j = 0; j < vias; j++) {
            c->conjuntos[i].vias[j].etiqueta  = 0;
            c->conjuntos[i].vias[j].valido    = 0;
            c->conjuntos[i].vias[j].sujo      = 0;
            c->conjuntos[i].vias[j].rrpv      = 0;
            c->conjuntos[i].vias[j].idade_lru = 0;
        }
    }

    printf("[%s] %d bytes | bloco %d B | %d vias | %d conjuntos\n",
           c->nome, bytes_totais, bytes_bloco, vias, c->num_conjuntos);
    printf("      deslocamento=%d bits | indice=%d bits | etiqueta=%d bits\n",
           c->bits_deslocamento, c->bits_indice,
           32 - c->bits_deslocamento - c->bits_indice);

    return c;
}

void cache_destruir(Cache *c)
{
    if (!c) return;
    int i;
    for (i = 0; i < c->num_conjuntos; i++)
        free(c->conjuntos[i].vias);
    free(c->conjuntos);
    free(c);
}

int cache_acessar(Cache *c, uint32_t endereco)
{
    c->acessos_totais++;

    /* 1. descobre qual conjunto e qual etiqueta correspondem ao endereço */
    uint32_t indice = obter_indice(c, endereco);
    uint32_t etiqueta = obter_etiqueta(c, endereco);
    ConjuntoCache *conjunto = &c->conjuntos[indice];

    /* 2. procura o bloco no conjunto */
    int i;
    for (i = 0; i < c->num_vias; i++) {
        if (conjunto->vias[i].valido && conjunto->vias[i].etiqueta == etiqueta) {
            /* ===== ACERTO (HIT) ===== */
            c->acertos++;

            /* PONTO DE POLÍTICA — ACERTO */
            politica_no_acerto(c, conjunto, i);

            return 1;
        }
    }

    /* ===== FALHA (MISS) ===== */
    c->falhas++;

    /* 3. procura um slot inválido primeiro */
    int vitima = -1;
    for (i = 0; i < c->num_vias; i++) {
        if (!conjunto->vias[i].valido) {
            vitima = i;
            break;
        }
    }

    /* 4. se não há slot inválido, chama a política para escolher a vítima */
    if (vitima == -1)
        vitima = politica_selecionar_vitima(c, conjunto);

    /* 5. insere o novo bloco no slot escolhido */
    conjunto->vias[vitima].etiqueta = etiqueta;
    conjunto->vias[vitima].valido   = 1;
    conjunto->vias[vitima].sujo     = 0;

    /* PONTO DE POLÍTICA — INSERÇÃO */
    politica_na_insercao(c, conjunto, vitima);

    return 0;
}

void cache_imprimir_estatisticas(const Cache *c)
{
    double taxa_acerto = (c->acessos_totais > 0)
                ? (double)c->acertos / c->acessos_totais * 100.0
                : 0.0;

    printf("  [%s] acessos=%-8lld  acertos=%-8lld  falhas=%-8lld  taxa_acerto=%.2f%%\n",
           c->nome, c->acessos_totais, c->acertos, c->falhas, taxa_acerto);
}

void cache_resetar_estatisticas(Cache *c)
{
    c->acertos = c->falhas = c->acessos_totais = 0;
}

/* =========================================================
 * FUNÇÕES DE POLÍTICA — STUBS (IMPLEMENTAR)
 * ========================================================= */

void politica_no_acerto(Cache *cache, ConjuntoCache *conjunto, int indice_via)
{
    /* TODO: implementar logica de acerto da sua politica */
    (void)cache;
    (void)conjunto;
    (void)indice_via;
}

int politica_selecionar_vitima(Cache *cache, ConjuntoCache *conjunto)
{
    /* TODO: implementar selecao de vitima da sua politica */
    (void)cache;
    (void)conjunto;
    return 0;
}

void politica_na_insercao(Cache *cache, ConjuntoCache *conjunto, int indice_via)
{
    /* TODO: implementar logica de insercao da sua politica */
    (void)cache;
    (void)conjunto;
    (void)indice_via;
}

/* =========================================================
 * API DA HIERARQUIA L1 + L2
 * ========================================================= */

HierarquiaCache *hierarquia_criar(
    int total_l1, int bloco_l1, int vias_l1,
    int total_l2, int bloco_l2, int vias_l2)
{
    HierarquiaCache *h = (HierarquiaCache *)malloc(sizeof(HierarquiaCache));
    if (!h) {
        fprintf(stderr, "ERRO: nao foi possivel alocar a hierarquia\n");
        return NULL;
    }

    printf("=== Criando hierarquia de cache ===\n");
    h->l1 = cache_criar(total_l1, bloco_l1, vias_l1, "L1");
    h->l2 = cache_criar(total_l2, bloco_l2, vias_l2, "L2");
    printf("===================================\n\n");

    if (!h->l1 || !h->l2) {
        cache_destruir(h->l1);
        cache_destruir(h->l2);
        free(h);
        return NULL;
    }

    h->acessos_totais  = 0;
    h->acertos_l1      = 0;
    h->acertos_l2      = 0;
    h->acessos_memoria = 0;

    return h;
}

void hierarquia_destruir(HierarquiaCache *h)
{
    if (!h) return;
    cache_destruir(h->l1);
    cache_destruir(h->l2);
    free(h);
}

int hierarquia_acessar(HierarquiaCache *h, uint32_t endereco)
{
    h->acessos_totais++;

    /* 1. tenta L1 */
    if (cache_acessar(h->l1, endereco)) {
        h->acertos_l1++;
        return 2;
    }

    /* 2. falha na L1 — tenta L2 */
    if (cache_acessar(h->l2, endereco)) {
        h->acertos_l2++;
        return 1;
    }

    /* 3. falha em ambas — acesso a memoria principal */
    h->acessos_memoria++;
    return 0;
}

long long hierarquia_rodar_trace(HierarquiaCache *h, const char *nome_arquivo)
{
    FILE *fp = fopen(nome_arquivo, "r");
    if (!fp) {
        fprintf(stderr, "ERRO: nao foi possivel abrir '%s'\n", nome_arquivo);
        return 0;
    }

    char      linha[64];
    uint32_t  endereco;
    long long contador = 0;

    while (fgets(linha, sizeof(linha), fp)) {
        if (linha[0] == '#' || linha[0] == '\n' || linha[0] == '\r')
            continue;

        char *ptr = linha;
        if (ptr[0] == '0' && (ptr[1] == 'x' || ptr[1] == 'X'))
            ptr += 2;

        if (sscanf(ptr, "%x", &endereco) == 1) {
            hierarquia_acessar(h, endereco);
            contador++;
        }
    }

    fclose(fp);
    return contador;
}

void hierarquia_imprimir_estatisticas(const HierarquiaCache *h)
{
    double l1_taxa = 0.0, l2_taxa = 0.0, global_taxa = 0.0;

    if (h->acessos_totais > 0) {
        l1_taxa     = (double)h->acertos_l1 / h->acessos_totais * 100.0;
        global_taxa = (double)(h->acertos_l1 + h->acertos_l2) / h->acessos_totais * 100.0;
    }
    if (h->l1->falhas > 0)
        l2_taxa = (double)h->acertos_l2 / h->l1->falhas * 100.0;

    printf("============= ESTATISTICAS DA HIERARQUIA =============\n");
    printf("  Total de acessos     : %lld\n",   h->acessos_totais);
    printf("  Acertos na L1        : %lld  (%.2f%% do total)\n",
           h->acertos_l1, l1_taxa);
    printf("  Acertos na L2        : %lld  (%.2f%% das falhas L1)\n",
           h->acertos_l2, l2_taxa);
    printf("  Acessos a memoria    : %lld\n",   h->acessos_memoria);
    printf("  Hit rate global      : %.2f%%\n", global_taxa);
    printf("------------------------------------------------------\n");
    cache_imprimir_estatisticas(h->l1);
    cache_imprimir_estatisticas(h->l2);
    printf("======================================================\n\n");
}

void hierarquia_resetar_estatisticas(HierarquiaCache *h)
{
    cache_resetar_estatisticas(h->l1);
    cache_resetar_estatisticas(h->l2);
    h->acessos_totais = h->acertos_l1 = h->acertos_l2 = h->acessos_memoria = 0;
}