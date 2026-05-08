#include "cache.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* =========================================================
 * cache.c — Implementacao da Hierarquia de Cache
 *
 * Para trocar a politica de substituicao:
 *   Altere APENAS as tres funcoes no final deste arquivo:
 *     politica_no_acerto()
 *     politica_selecionar_vitima()
 *     politica_na_insercao()
 *
 * Politicas incluidas:
 *   Descomente o bloco desejado e comente os demais.
 *
 *   [X] POLITICA_DRRIP  — algoritmo do projeto (padrao)
 *   [ ] POLITICA_LRU    — baseline para comparacao
 *
 * Correspondencia com RTL (Verilog):
 *   politica_no_acerto   → always @(posedge clk) if (hit)
 *   politica_selecionar  → logica combinacional de vitima
 *   politica_na_insercao → always @(posedge clk) if (miss)
 * ========================================================= */

/* =========================================================
 * SELECAO DE POLITICA
 * Descomente UMA das duas linhas abaixo:
 * ========================================================= */
#define POLITICA_DRRIP
/* #define POLITICA_LRU */

/* =========================================================
 * FUNCOES INTERNAS — DECODIFICACAO DE ENDERECO
 *
 * RTL equivalente:
 *   assign index = addr[OFFSET+INDEX-1 : OFFSET];
 *   assign tag   = addr[31 : OFFSET+INDEX];
 * ========================================================= */
static int log2_inteiro(int n)
{
    int r = 0;
    while (n > 1) { n >>= 1; r++; }
    return r;
}

static uint32_t obter_indice(Cache *c, uint32_t endereco)
{
    uint32_t mascara = (1u << c->bits_indice) - 1u;
    return (endereco >> c->bits_deslocamento) & mascara;
}

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
    if (!c) { fprintf(stderr, "ERRO: malloc Cache\n"); return NULL; }

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

    c->conjuntos = (ConjuntoCache *)malloc(
                       c->num_conjuntos * sizeof(ConjuntoCache));
    if (!c->conjuntos) {
        fprintf(stderr, "ERRO: malloc conjuntos\n");
        free(c); return NULL;
    }

    int i, j;
    for (i = 0; i < c->num_conjuntos; i++) {
        c->conjuntos[i].vias =
            (BlocoCache *)malloc(vias * sizeof(BlocoCache));
        if (!c->conjuntos[i].vias) {
            fprintf(stderr, "ERRO: malloc vias conjunto %d\n", i);
            for (j = 0; j < i; j++) free(c->conjuntos[j].vias);
            free(c->conjuntos); free(c); return NULL;
        }
        for (j = 0; j < vias; j++) {
            c->conjuntos[i].vias[j].etiqueta  = 0;
            c->conjuntos[i].vias[j].valido    = 0;
            c->conjuntos[i].vias[j].bit_sujo  = 0;
            c->conjuntos[i].vias[j].rrpv      = RRPV_MAX;
            c->conjuntos[i].vias[j].idade_lru = 0;
        }
    }

    printf("[%s] %d bytes | bloco=%dB | %d vias | %d conjuntos\n",
           c->nome, bytes_totais, bytes_bloco, vias, c->num_conjuntos);
    printf("      offset=%d bits | index=%d bits | tag=%d bits\n",
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

/* =========================================================
 * cache_acessar — nucleo do simulador
 *
 * RTL: este fluxo vira a FSM principal do modulo cache
 *
 *   Estado IDLE    → recebe endereco do processador
 *   Estado LOOKUP  → compara tag com todas as vias (paralelo)
 *   Estado HIT     → chama politica_no_acerto, retorna dado
 *   Estado MISS    → seleciona vitima, busca L2/RAM, insere
 *
 * Retorno:
 *   1 = HIT  (dado encontrado neste nivel)
 *   0 = MISS (dado nao encontrado)
 * ========================================================= */
int cache_acessar(Cache *c, uint32_t endereco)
{
    c->acessos_totais++;

    uint32_t indice   = obter_indice(c, endereco);
    uint32_t etiqueta = obter_etiqueta(c, endereco);
    ConjuntoCache *conjunto = &c->conjuntos[indice];

    /* LOOKUP — paralelo em RTL (um comparador por via) */
    int i;
    for (i = 0; i < c->num_vias; i++) {
        if (conjunto->vias[i].valido &&
            conjunto->vias[i].etiqueta == etiqueta) {
            /* HIT */
            c->acertos++;
            politica_no_acerto(c, conjunto, i);
            return 1;
        }
    }

    /* MISS */
    c->falhas++;

    /* prioridade: slot invalido (warmup) */
    int vitima = -1;
    for (i = 0; i < c->num_vias; i++) {
        if (!conjunto->vias[i].valido) { vitima = i; break; }
    }

    /* se todos validos: politica seleciona vitima */
    if (vitima == -1)
        vitima = politica_selecionar_vitima(c, conjunto);

    /* insere novo bloco */
    conjunto->vias[vitima].etiqueta = etiqueta;
    conjunto->vias[vitima].valido   = 1;
    conjunto->vias[vitima].bit_sujo = 0;
    politica_na_insercao(c, conjunto, vitima);

    return 0;
}

void cache_imprimir_estatisticas(const Cache *c)
{
    double taxa = (c->acessos_totais > 0)
        ? (double)c->acertos / c->acessos_totais * 100.0 : 0.0;
    printf("  [%s] acessos=%-10lld acertos=%-10lld falhas=%-10lld taxa=%.2f%%\n",
           c->nome, c->acessos_totais, c->acertos, c->falhas, taxa);
}

void cache_resetar_estatisticas(Cache *c)
{
    c->acertos = c->falhas = c->acessos_totais = 0;
}

/* =========================================================
 * POLITICAS DE SUBSTITUICAO
 *
 * Cada funcao abaixo corresponde a um bloco RTL:
 *
 * politica_no_acerto   → registra promocao no hit
 * politica_selecionar  → logica de escolha da vitima
 * politica_na_insercao → define metadados do bloco novo
 * ========================================================= */

/* ----- ESTADO GLOBAL DO DRRIP -----
 * RTL: registrador de 10 bits compartilhado entre L1 e L2
 *      (ou um por nivel — decisao de implementacao)         */
#ifdef POLITICA_DRRIP
static int  psel          = PSEL_MEIO;
static int  brrip_counter = 0;

/* retorna 1 = usar SRRIP, 0 = usar BRRIP
 * RTL: logica combinacional baseada em psel e indice_conjunto */
static int usar_srrip(int idx_conjunto)
{
    if (idx_conjunto < NUM_MONITORES)              return 1;
    if (idx_conjunto < 2 * NUM_MONITORES)          return 0;
    return (psel >= PSEL_MEIO) ? 1 : 0;
}

/* atualiza PSEL nos misses dos conjuntos monitor
 * RTL: always @(posedge clk) if (miss && monitor_set) psel <= ... */
static void atualizar_psel(int idx_conjunto)
{
    if (idx_conjunto < NUM_MONITORES) {
        /* miss no monitor SRRIP — SRRIP errando */
        if (psel > 0) psel--;
    } else if (idx_conjunto < 2 * NUM_MONITORES) {
        /* miss no monitor BRRIP — BRRIP errando */
        if (psel < PSEL_MAX) psel++;
    }
}
#endif /* POLITICA_DRRIP */

/* =========================================================
 * politica_no_acerto
 *
 * DRRIP: RRPV = 0  (bloco sera reutilizado em breve)
 * LRU  : idade = 0, envelhece os demais
 *
 * RTL: always @(posedge clk)
 *        if (hit) rrpv[hit_way] <= 2'b00;
 * ========================================================= */
void politica_no_acerto(Cache *cache, ConjuntoCache *conjunto,
                         int indice_via)
{
#ifdef POLITICA_DRRIP
    (void)cache;
    conjunto->vias[indice_via].rrpv = 0;

#elif defined(POLITICA_LRU)
    int i;
    for (i = 0; i < cache->num_vias; i++)
        conjunto->vias[i].idade_lru++;
    conjunto->vias[indice_via].idade_lru = 0;
#endif
}

/* =========================================================
 * politica_selecionar_vitima
 *
 * DRRIP:
 *   1. Atualiza PSEL se conjunto monitor
 *   2. Procura via com RRPV = RRPV_MAX (3)
 *   3. Se nao achar, envelhece todas (+1) e repete
 *
 * LRU:
 *   Retorna via com maior idade_lru
 *
 * RTL (DRRIP):
 *   Logica combinacional com priority encoder
 *   Se nenhuma via tem RRPV=3, sinal age_all=1
 *   age_all dispara incremento de todos os RRPV
 * ========================================================= */
int politica_selecionar_vitima(Cache *cache, ConjuntoCache *conjunto)
{
#ifdef POLITICA_DRRIP
    int idx_conjunto = (int)(conjunto - cache->conjuntos);
    atualizar_psel(idx_conjunto);

    int i;
    while (1) {
        /* procura vitima com RRPV maximo */
        for (i = 0; i < cache->num_vias; i++)
            if (conjunto->vias[i].rrpv == RRPV_MAX)
                return i;

        /* aging: incrementa todos — RTL: age_all pulse */
        for (i = 0; i < cache->num_vias; i++)
            if (conjunto->vias[i].rrpv < RRPV_MAX)
                conjunto->vias[i].rrpv++;
    }

#elif defined(POLITICA_LRU)
    int vitima = 0, i;
    for (i = 1; i < cache->num_vias; i++)
        if (conjunto->vias[i].idade_lru >
            conjunto->vias[vitima].idade_lru)
            vitima = i;
    return vitima;

#else
    (void)cache; (void)conjunto;
    return 0;
#endif
}

/* =========================================================
 * politica_na_insercao
 *
 * DRRIP:
 *   SRRIP → RRPV = 2 (insercao distante)
 *   BRRIP → RRPV = 3 em 31/32 casos
 *           RRPV = 2 em  1/32 casos (probabilidade bimodal)
 *
 * LRU:
 *   idade = 0, envelhece os demais
 *
 * RTL (DRRIP):
 *   always @(posedge clk)
 *     if (miss) begin
 *       if (usar_srrip)       rrpv[victim] <= 2'b10;
 *       else if (brrip_rand)  rrpv[victim] <= 2'b10;
 *       else                  rrpv[victim] <= 2'b11;
 *     end
 *   brrip_rand: LFSR de 5 bits, dispara quando == 5'b00001
 * ========================================================= */
void politica_na_insercao(Cache *cache, ConjuntoCache *conjunto,
                           int indice_via)
{
#ifdef POLITICA_DRRIP
    int idx_conjunto = (int)(conjunto - cache->conjuntos);

    if (usar_srrip(idx_conjunto)) {
        /* SRRIP: insere com RRPV = 2 */
        conjunto->vias[indice_via].rrpv = RRPV_DISTANTE;
    } else {
        /* BRRIP: insere com RRPV = 3, exceto 1 em BRRIP_PROB */
        brrip_counter++;
        if (brrip_counter >= BRRIP_PROB) {
            brrip_counter = 0;
            conjunto->vias[indice_via].rrpv = RRPV_DISTANTE; /* 2 */
        } else {
            conjunto->vias[indice_via].rrpv = RRPV_MORTO;    /* 3 */
        }
    }

#elif defined(POLITICA_LRU)
    int i;
    for (i = 0; i < cache->num_vias; i++)
        conjunto->vias[i].idade_lru++;
    conjunto->vias[indice_via].idade_lru = 0;
#endif
}

/* =========================================================
 * API DA HIERARQUIA L1 + L2
 * ========================================================= */

HierarquiaCache *hierarquia_criar(
    int total_l1, int bloco_l1, int vias_l1,
    int total_l2, int bloco_l2, int vias_l2)
{
    HierarquiaCache *h =
        (HierarquiaCache *)malloc(sizeof(HierarquiaCache));
    if (!h) { fprintf(stderr, "ERRO: malloc hierarquia\n"); return NULL; }

#ifdef POLITICA_DRRIP
    psel = PSEL_MEIO;
    brrip_counter = 0;
    printf("=== Hierarquia de Cache — DRRIP ===\n");
    printf("    PSEL inicial : %d (neutro)\n", psel);
    printf("    Monitor SRRIP: conjuntos 0..%d\n", NUM_MONITORES-1);
    printf("    Monitor BRRIP: conjuntos %d..%d\n",
           NUM_MONITORES, 2*NUM_MONITORES-1);
#else
    printf("=== Hierarquia de Cache — LRU ===\n");
#endif

    h->l1 = cache_criar(total_l1, bloco_l1, vias_l1, "L1");
    h->l2 = cache_criar(total_l2, bloco_l2, vias_l2, "L2");
    printf("===================================\n\n");

    if (!h->l1 || !h->l2) {
        cache_destruir(h->l1);
        cache_destruir(h->l2);
        free(h); return NULL;
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

    if (cache_acessar(h->l1, endereco)) { h->acertos_l1++; return 2; }
    if (cache_acessar(h->l2, endereco)) { h->acertos_l2++; return 1; }

    h->acessos_memoria++;
    return 0;
}

long long hierarquia_rodar_trace(HierarquiaCache *h,
                                  const char *nome_arquivo)
{
    FILE *fp = fopen(nome_arquivo, "r");
    if (!fp) {
        fprintf(stderr, "ERRO: nao foi possivel abrir '%s'\n",
                nome_arquivo);
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
        global_taxa = (double)(h->acertos_l1 + h->acertos_l2)
                      / h->acessos_totais * 100.0;
    }
    if (h->l1->falhas > 0)
        l2_taxa = (double)h->acertos_l2 / h->l1->falhas * 100.0;

    printf("============= ESTATISTICAS DA HIERARQUIA =============\n");
#ifdef POLITICA_DRRIP
    printf("  Politica             : DRRIP  (PSEL final=%d → %s)\n",
           psel, psel >= PSEL_MEIO ? "SRRIP dominante" : "BRRIP dominante");
#else
    printf("  Politica             : LRU (baseline)\n");
#endif
    printf("  Total de acessos     : %lld\n",  h->acessos_totais);
    printf("  Acertos na L1        : %lld  (%.2f%% do total)\n",
           h->acertos_l1, l1_taxa);
    printf("  Acertos na L2        : %lld  (%.2f%% das falhas L1)\n",
           h->acertos_l2, l2_taxa);
    printf("  Acessos a memoria    : %lld\n",  h->acessos_memoria);
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
    h->acessos_totais = h->acertos_l1 =
    h->acertos_l2 = h->acessos_memoria = 0;
}
