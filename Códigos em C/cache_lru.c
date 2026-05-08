#include "cache.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* =========================================================
 * cache_lru.c — Politica LRU (baseline)
 *
 * Compilar: gcc -O0 -Wall -o simulador_lru cache_lru.c main.c
 *
 * Logica LRU:
 *   idade_lru = 0  → mais recente
 *   idade_lru = N  → mais antigo (vitima)
 *   Hit  → zera quem acertou, envelhece os demais
 *   Miss → zera quem entrou,  envelhece os demais
 *   Vitima → maior idade_lru
 * ========================================================= */

static int log2i(int n){ int r=0; while(n>1){n>>=1;r++;} return r; }

static uint32_t obter_indice(Cache *c, uint32_t e){
    return (e >> c->bits_deslocamento) & ((1u<<c->bits_indice)-1u);
}
static uint32_t obter_etiqueta(Cache *c, uint32_t e){
    return e >> (c->bits_deslocamento + c->bits_indice);
}

Cache *cache_criar(int bt, int bb, int vias, const char *nome){
    Cache *c = calloc(1, sizeof(Cache));
    c->tamanho_total_bytes = bt;
    c->tamanho_bloco_bytes = bb;
    c->num_vias     = vias;
    c->num_conjuntos= bt/(bb*vias);
    c->bits_deslocamento = log2i(bb);
    c->bits_indice  = log2i(c->num_conjuntos);
    strncpy(c->nome, nome?nome:"?", 7);
    c->conjuntos = calloc(c->num_conjuntos, sizeof(ConjuntoCache));
    for(int i=0;i<c->num_conjuntos;i++){
        c->conjuntos[i].vias = calloc(vias, sizeof(BlocoCache));
        for(int j=0;j<vias;j++) c->conjuntos[i].vias[j].idade_lru = j;
    }
    printf("[%s] %dB | bloco=%dB | %d vias | %d conj | off=%d idx=%d tag=%d\n",
        c->nome,bt,bb,vias,c->num_conjuntos,
        c->bits_deslocamento,c->bits_indice,
        32-c->bits_deslocamento-c->bits_indice);
    return c;
}

void cache_destruir(Cache *c){
    if(!c) return;
    for(int i=0;i<c->num_conjuntos;i++) free(c->conjuntos[i].vias);
    free(c->conjuntos); free(c);
}

int cache_acessar(Cache *c, uint32_t end){
    c->acessos_totais++;
    uint32_t idx = obter_indice(c,end);
    uint32_t tag = obter_etiqueta(c,end);
    ConjuntoCache *conj = &c->conjuntos[idx];
    for(int i=0;i<c->num_vias;i++){
        if(conj->vias[i].valido && conj->vias[i].etiqueta==tag){
            c->acertos++;
            politica_no_acerto(c,conj,i);
            return 1;
        }
    }
    c->falhas++;
    int vitima=-1;
    for(int i=0;i<c->num_vias;i++)
        if(!conj->vias[i].valido){ vitima=i; break; }
    if(vitima==-1) vitima=politica_selecionar_vitima(c,conj);
    conj->vias[vitima].etiqueta=tag;
    conj->vias[vitima].valido=1;
    conj->vias[vitima].bit_sujo=0;
    politica_na_insercao(c,conj,vitima);
    return 0;
}

void cache_imprimir_estatisticas(const Cache *c){
    double t=(c->acessos_totais>0)?(double)c->acertos/c->acessos_totais*100.0:0.0;
    printf("  [%s] acessos=%-8lld acertos=%-8lld falhas=%-8lld taxa=%.2f%%\n",
        c->nome,c->acessos_totais,c->acertos,c->falhas,t);
}
void cache_resetar_estatisticas(Cache *c){
    c->acertos=c->falhas=c->acessos_totais=0;
}

/* ===== POLITICA LRU ===== */
void politica_no_acerto(Cache *c, ConjuntoCache *conj, int via){
    for(int i=0;i<c->num_vias;i++) conj->vias[i].idade_lru++;
    conj->vias[via].idade_lru=0;
}
int politica_selecionar_vitima(Cache *c, ConjuntoCache *conj){
    int v=0;
    for(int i=1;i<c->num_vias;i++)
        if(conj->vias[i].idade_lru>conj->vias[v].idade_lru) v=i;
    return v;
}
void politica_na_insercao(Cache *c, ConjuntoCache *conj, int via){
    for(int i=0;i<c->num_vias;i++) conj->vias[i].idade_lru++;
    conj->vias[via].idade_lru=0;
}

/* ===== HIERARQUIA ===== */
HierarquiaCache *hierarquia_criar(int tl1,int bl1,int vl1,int tl2,int bl2,int vl2){
    HierarquiaCache *h=calloc(1,sizeof(HierarquiaCache));
    printf("=== Cache LRU (baseline) ===\n");
    h->l1=cache_criar(tl1,bl1,vl1,"L1");
    h->l2=cache_criar(tl2,bl2,vl2,"L2");
    printf("============================\n\n");
    return h;
}
void hierarquia_destruir(HierarquiaCache *h){
    if(!h) return;
    cache_destruir(h->l1); cache_destruir(h->l2); free(h);
}
int hierarquia_acessar(HierarquiaCache *h, uint32_t e){
    h->acessos_totais++;
    if(cache_acessar(h->l1,e)){ h->acertos_l1++; return 2; }
    if(cache_acessar(h->l2,e)){ h->acertos_l2++; return 1; }
    h->acessos_memoria++; return 0;
}
long long hierarquia_rodar_trace(HierarquiaCache *h, const char *arq){
    FILE *fp=fopen(arq,"r");
    if(!fp){ fprintf(stderr,"ERRO: nao abriu '%s'\n",arq); return 0; }
    char linha[64]; uint32_t end; long long n=0;
    while(fgets(linha,sizeof(linha),fp)){
        if(linha[0]=='#'||linha[0]=='\n'||linha[0]=='\r') continue;
        char *p=linha;
        if(p[0]=='0'&&(p[1]=='x'||p[1]=='X')) p+=2;
        if(sscanf(p,"%x",&end)==1){ hierarquia_acessar(h,end); n++; }
    }
    fclose(fp); return n;
}
void hierarquia_imprimir_estatisticas(const HierarquiaCache *h){
    double l1=0,l2=0,gl=0;
    if(h->acessos_totais>0){
        l1=(double)h->acertos_l1/h->acessos_totais*100.0;
        gl=(double)(h->acertos_l1+h->acertos_l2)/h->acessos_totais*100.0;
    }
    if(h->l1->falhas>0) l2=(double)h->acertos_l2/h->l1->falhas*100.0;
    printf("============= ESTATISTICAS — LRU =============\n");
    printf("  Total de acessos : %lld\n",h->acessos_totais);
    printf("  Acertos L1       : %lld  (%.2f%% do total)\n",h->acertos_l1,l1);
    printf("  Acertos L2       : %lld  (%.2f%% das falhas L1)\n",h->acertos_l2,l2);
    printf("  Acessos a RAM    : %lld\n",h->acessos_memoria);
    printf("  Hit rate global  : %.2f%%\n",gl);
    printf("----------------------------------------------\n");
    cache_imprimir_estatisticas(h->l1);
    cache_imprimir_estatisticas(h->l2);
    printf("==============================================\n\n");
}
void hierarquia_resetar_estatisticas(HierarquiaCache *h){
    cache_resetar_estatisticas(h->l1);
    cache_resetar_estatisticas(h->l2);
    h->acessos_totais=h->acertos_l1=h->acertos_l2=h->acessos_memoria=0;
}
