//==============================================================================
// ARQUIVO 1: cache_unica.v
//------------------------------------------------------------------------------
// L2 Cache Simplificada (4 conjuntos) baseada no modulo drrip_logisim.
//
// Arquitetura minima e defensavel academicamente:
//  - 4 conjuntos (sets), cada conjunto eh uma instancia de drrip_logisim.
//  - Cada instancia de drrip_logisim implementa UM conjunto 4-way com
//    politica de substituicao SRRIP/BRRIP (ja existente).
//  - Endereco de 8 bits com o seguinte formato:
//        addr_in[7:4] = tag           (4 bits)
//        addr_in[3:2] = indice do conjunto (2 bits)
//        addr_in[1:0] = offset       (ignorado nesta abstracao)
//  - O wrapper seleciona qual conjunto recebe "acesso_valido" com base no
//    indice extraido do endereco.
//  - As saidas globais da L2 refletem SOMENTE o conjunto selecionado no acesso
//    atual (multiplexacao simples).
//
// Esta L2 nao implementa processador nem memoria real: ela apenas organiza
// 4 conjuntos DRRIP e expoe as metricas do conjunto acessado. O testbench
// sera o gerador de acessos.
//==============================================================================
module cache_unica (
    input  wire        clock,
    input  wire        reset,
    input  wire [7:0]  addr_in,
    input  wire        acesso_valido,
    input  wire        SRRIP_ou_BRRIP,   // 0 = SRRIP, 1 = BRRIP

    // Saidas globais (do conjunto selecionado no acesso atual)
    output wire        eh_hit,
    output wire        miss,
    output wire        invalido,
    output wire [1:0]  via_vitima,
    output wire        vitima_encontrada,
    output wire [1:0]  insercao_rrpv,
    output wire [1:0]  set_index,        // indice do conjunto selecionado
    output wire [3:0]  tag_extraida,     // tag extraida do endereco

    // Saidas opcionais: hits por via do conjunto selecionado
    output wire        hit0,
    output wire        hit1,
    output wire        hit2,
    output wire        hit3
);

    // -----------------------------------------------------------------------
    // Extracao de campos do endereco (formato definido na arquitetura)
    // -----------------------------------------------------------------------
    wire [3:0] tag = addr_in[7:4];   // tag
    wire [1:0] idx = addr_in[3:2];   // indice do conjunto (0..3)
    // addr_in[1:0] = offset -> ignorado nesta abstracao

    assign set_index    = idx;
    assign tag_extraida = tag;

    // -----------------------------------------------------------------------
    // Demux de acesso_valido: so a instancia cujo indice bate recebe 1.
    // -----------------------------------------------------------------------
    wire valid_set0 = acesso_valido & (idx == 2'b00);
    wire valid_set1 = acesso_valido & (idx == 2'b01);
    wire valid_set2 = acesso_valido & (idx == 2'b10);
    wire valid_set3 = acesso_valido & (idx == 2'b11);

    // -----------------------------------------------------------------------
    // Sinais internos de cada instancia de drrip_logisim.
    // Mantemos apenas as saidas essenciais para a L2 simplificada.
    // -----------------------------------------------------------------------
    wire        s0_eh_hit, s0_miss, s0_invalido, s0_vitima_encontrada;
    wire [1:0]  s0_via_vitima, s0_insercao_rrpv;
    wire        s0_hit0, s0_hit1, s0_hit2, s0_hit3;

    wire        s1_eh_hit, s1_miss, s1_invalido, s1_vitima_encontrada;
    wire [1:0]  s1_via_vitima, s1_insercao_rrpv;
    wire        s1_hit0, s1_hit1, s1_hit2, s1_hit3;

    wire        s2_eh_hit, s2_miss, s2_invalido, s2_vitima_encontrada;
    wire [1:0]  s2_via_vitima, s2_insercao_rrpv;
    wire        s2_hit0, s2_hit1, s2_hit2, s2_hit3;

    wire        s3_eh_hit, s3_miss, s3_invalido, s3_vitima_encontrada;
    wire [1:0]  s3_via_vitima, s3_insercao_rrpv;
    wire        s3_hit0, s3_hit1, s3_hit2, s3_hit3;

    // -----------------------------------------------------------------------
    // Instanciacao dos 4 conjuntos. A tag_in eh a mesma para todos, mas so o
    // conjunto selecionado recebe acesso_valido = 1.
    // -----------------------------------------------------------------------
    drrip_logisim set0 (
        .clock(clock),
        .reset(reset),
        .tag_in(tag),
        .acesso_valido(valid_set0),
        .SRRIP_ou_BRRIP(SRRIP_ou_BRRIP),
        .eh_hit(s0_eh_hit),
        .miss(s0_miss),
        .invalido(s0_invalido),
        .via_vitima(s0_via_vitima),
        .vitima_encontrada(s0_vitima_encontrada),
        .insercao_rrpv(s0_insercao_rrpv),
        .hit0(s0_hit0), .hit1(s0_hit1), .hit2(s0_hit2), .hit3(s0_hit3)
    );

    drrip_logisim set1 (
        .clock(clock),
        .reset(reset),
        .tag_in(tag),
        .acesso_valido(valid_set1),
        .SRRIP_ou_BRRIP(SRRIP_ou_BRRIP),
        .eh_hit(s1_eh_hit),
        .miss(s1_miss),
        .invalido(s1_invalido),
        .via_vitima(s1_via_vitima),
        .vitima_encontrada(s1_vitima_encontrada),
        .insercao_rrpv(s1_insercao_rrpv),
        .hit0(s1_hit0), .hit1(s1_hit1), .hit2(s1_hit2), .hit3(s1_hit3)
    );

    drrip_logisim set2 (
        .clock(clock),
        .reset(reset),
        .tag_in(tag),
        .acesso_valido(valid_set2),
        .SRRIP_ou_BRRIP(SRRIP_ou_BRRIP),
        .eh_hit(s2_eh_hit),
        .miss(s2_miss),
        .invalido(s2_invalido),
        .via_vitima(s2_via_vitima),
        .vitima_encontrada(s2_vitima_encontrada),
        .insercao_rrpv(s2_insercao_rrpv),
        .hit0(s2_hit0), .hit1(s2_hit1), .hit2(s2_hit2), .hit3(s2_hit3)
    );

    drrip_logisim set3 (
        .clock(clock),
        .reset(reset),
        .tag_in(tag),
        .acesso_valido(valid_set3),
        .SRRIP_ou_BRRIP(SRRIP_ou_BRRIP),
        .eh_hit(s3_eh_hit),
        .miss(s3_miss),
        .invalido(s3_invalido),
        .via_vitima(s3_via_vitima),
        .vitima_encontrada(s3_vitima_encontrada),
        .insercao_rrpv(s3_insercao_rrpv),
        .hit0(s3_hit0), .hit1(s3_hit1), .hit2(s3_hit2), .hit3(s3_hit3)
    );

    // -----------------------------------------------------------------------
    // Multiplexacao das saidas globais com base no indice selecionado.
    // As saidas globais refletem SOMENTE o conjunto acessado no ciclo atual.
    // -----------------------------------------------------------------------
    assign eh_hit            = (idx == 2'b00) ? s0_eh_hit :
                               (idx == 2'b01) ? s1_eh_hit :
                               (idx == 2'b10) ? s2_eh_hit :
                                                s3_eh_hit;

    assign miss              = (idx == 2'b00) ? s0_miss :
                               (idx == 2'b01) ? s1_miss :
                               (idx == 2'b10) ? s2_miss :
                                                s3_miss;

    assign invalido         = (idx == 2'b00) ? s0_invalido :
                               (idx == 2'b01) ? s1_invalido :
                               (idx == 2'b10) ? s2_invalido :
                                                s3_invalido;

    assign via_vitima       = (idx == 2'b00) ? s0_via_vitima :
                               (idx == 2'b01) ? s1_via_vitima :
                               (idx == 2'b10) ? s2_via_vitima :
                                                s3_via_vitima;

    assign vitima_encontrada= (idx == 2'b00) ? s0_vitima_encontrada :
                               (idx == 2'b01) ? s1_vitima_encontrada :
                               (idx == 2'b10) ? s2_vitima_encontrada :
                                                s3_vitima_encontrada;

    assign insercao_rrpv    = (idx == 2'b00) ? s0_insercao_rrpv :
                               (idx == 2'b01) ? s1_insercao_rrpv :
                               (idx == 2'b10) ? s2_insercao_rrpv :
                                                s3_insercao_rrpv;

    assign hit0             = (idx == 2'b00) ? s0_hit0 :
                               (idx == 2'b01) ? s1_hit0 :
                               (idx == 2'b10) ? s2_hit0 :
                                                s3_hit0;

    assign hit1             = (idx == 2'b00) ? s0_hit1 :
                               (idx == 2'b01) ? s1_hit1 :
                               (idx == 2'b10) ? s2_hit1 :
                                                s3_hit1;

    assign hit2             = (idx == 2'b00) ? s0_hit2 :
                               (idx == 2'b01) ? s1_hit2 :
                               (idx == 2'b10) ? s2_hit2 :
                                                s3_hit2;

    assign hit3             = (idx == 2'b00) ? s0_hit3 :
                               (idx == 2'b01) ? s1_hit3 :
                               (idx == 2'b10) ? s2_hit3 :
                                                s3_hit3;

endmodule
