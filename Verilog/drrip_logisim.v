////////////////////////////////////////////////////////////////////////////////
// Modulo DrRIP Cache 4-vias
// Implementa Dynamic Re-reference Interval Prediction para cache 4-vias
// SRRIP_ou_BRRIP = 0 -> SRRIP (insere/hit com 0)
// SRRIP_ou_BRRIP = 1 -> BRRIP (insere/hit com 2)
////////////////////////////////////////////////////////////////////////////////

module drrip_logisim (
    input  wire       clock,
    input  wire       reset,
    input  wire [3:0] tag_in,
    input  wire       acesso_valido,
    input  wire       SRRIP_ou_BRRIP,

    // Sinais de saida
    output wire       hit0, hit1, hit2, hit3,
    output wire       eh_hit,
    output wire       rrpv0_igual_3, rrpv1_igual_3, rrpv2_igual_3, rrpv3_igual_3,
    output wire       rrpv_igual_3,
    output wire       rrpv0_menor_3, rrpv1_menor_3, rrpv2_menor_3, rrpv3_menor_3,
    output wire [1:0] idade_rrpv0, idade_rrpv1, idade_rrpv2, idade_rrpv3,
    output wire [1:0] rrpv0_mais_1, rrpv1_mais_1, rrpv2_mais_1, rrpv3_mais_1,
    output wire [1:0] rrpv0_hit, rrpv1_hit, rrpv2_hit, rrpv3_hit,
    output wire       invalid0, invalid1, invalid2, invalid3,
    output wire       invalido,
    output wire       miss,
    output wire       envelhecer_rrpvs,
    output wire [1:0] via_vitima,
    output wire       vitima0, vitima1, vitima2, vitima3,
    output wire       vitima_encontrada,
    output wire [1:0] insercao_rrpv,
    output wire       enable_tag,
    output wire       grava_tag0, grava_tag1, grava_tag2, grava_tag3,
    output wire [1:0] prox_rrpv0, prox_rrpv1, prox_rrpv2, prox_rrpv3,
    output wire [1:0] rrpv0_next, rrpv1_next, rrpv2_next, rrpv3_next
);

    // Registradores da cache (atualizados na borda de subida)
    reg [3:0] tag0, tag1, tag2, tag3;
    reg       valid0, valid1, valid2, valid3;
    reg [1:0] rrpv0, rrpv1, rrpv2, rrpv3;

    // 1) Deteccao de hit
    assign hit0 = (tag0 == tag_in) & valid0 & acesso_valido;
    assign hit1 = (tag1 == tag_in) & valid1 & acesso_valido;
    assign hit2 = (tag2 == tag_in) & valid2 & acesso_valido;
    assign hit3 = (tag3 == tag_in) & valid3 & acesso_valido;
    assign eh_hit = hit0 | hit1 | hit2 | hit3;

    // 2) RRPV == 3 e RRPV < 3
    assign rrpv0_igual_3 = (rrpv0 == 2'b11);
    assign rrpv1_igual_3 = (rrpv1 == 2'b11);
    assign rrpv2_igual_3 = (rrpv2 == 2'b11);
    assign rrpv3_igual_3 = (rrpv3 == 2'b11);
    assign rrpv_igual_3 = rrpv0_igual_3 | rrpv1_igual_3 | rrpv2_igual_3 | rrpv3_igual_3;

    assign rrpv0_menor_3 = (rrpv0 < 2'b11);
    assign rrpv1_menor_3 = (rrpv1 < 2'b11);
    assign rrpv2_menor_3 = (rrpv2 < 2'b11);
    assign rrpv3_menor_3 = (rrpv3 < 2'b11);

    // 3) Idade (valor atual do RRPV)
    assign idade_rrpv0 = rrpv0;
    assign idade_rrpv1 = rrpv1;
    assign idade_rrpv2 = rrpv2;
    assign idade_rrpv3 = rrpv3;

    // 4) RRPV + 1 com saturacao em 3
    assign rrpv0_mais_1 = (rrpv0 == 2'b11) ? 2'b11 : (rrpv0 + 1'b1);
    assign rrpv1_mais_1 = (rrpv1 == 2'b11) ? 2'b11 : (rrpv1 + 1'b1);
    assign rrpv2_mais_1 = (rrpv2 == 2'b11) ? 2'b11 : (rrpv2 + 1'b1);
    assign rrpv3_mais_1 = (rrpv3 == 2'b11) ? 2'b11 : (rrpv3 + 1'b1);

    // 5) Valor de RRPV em caso de hit (CORRIGIDO)
    // SRRIP_ou_BRRIP = 0 (SRRIP) -> rrpvX_hit = 0
    // SRRIP_ou_BRRIP = 1 (BRRIP) -> rrpvX_hit = 2
    assign rrpv0_hit = hit0 ? (SRRIP_ou_BRRIP ? 2'd2 : 2'd0) : 2'd0;
    assign rrpv1_hit = hit1 ? (SRRIP_ou_BRRIP ? 2'd2 : 2'd0) : 2'd0;
    assign rrpv2_hit = hit2 ? (SRRIP_ou_BRRIP ? 2'd2 : 2'd0) : 2'd0;
    assign rrpv3_hit = hit3 ? (SRRIP_ou_BRRIP ? 2'd2 : 2'd0) : 2'd0;

    // 6) Bits de invalidade
    assign invalid0 = ~valid0;
    assign invalid1 = ~valid1;
    assign invalid2 = ~valid2;
    assign invalid3 = ~valid3;
    assign invalido = invalid0 | invalid1 | invalid2 | invalid3;

    // 7) Miss e sinal de envelhecimento
    assign miss = acesso_valido & ~eh_hit;
    assign envelhecer_rrpvs = miss & ~rrpv_igual_3;

    // 8) Selecao da vitima
    assign vitima0 = (miss & invalid0) |
                     (miss & ~invalid0 & ~invalid1 & ~invalid2 & ~invalid3 & rrpv0_igual_3);
    assign vitima1 = (miss & ~invalid0 & invalid1) |
                     (miss & ~invalid0 & ~invalid1 & ~invalid2 & ~invalid3 & ~rrpv0_igual_3 & rrpv1_igual_3);
    assign vitima2 = (miss & ~invalid0 & ~invalid1 & invalid2) |
                     (miss & ~invalid0 & ~invalid1 & ~invalid2 & ~invalid3 & ~rrpv0_igual_3 & ~rrpv1_igual_3 & rrpv2_igual_3);
    assign vitima3 = (miss & ~invalid0 & ~invalid1 & ~invalid2 & invalid3) |
                     (miss & ~invalid0 & ~invalid1 & ~invalid2 & ~invalid3 & ~rrpv0_igual_3 & ~rrpv1_igual_3 & ~rrpv2_igual_3 & rrpv3_igual_3);
    assign vitima_encontrada = vitima0 | vitima1 | vitima2 | vitima3;

    assign via_vitima = vitima0 ? 2'd0 :
                        vitima1 ? 2'd1 :
                        vitima2 ? 2'd2 :
                        vitima3 ? 2'd3 : 2'd0;

    // 9) RRPV de insercao (CORRIGIDO)
    // SRRIP_ou_BRRIP = 0 (SRRIP) -> insere com 0
    // SRRIP_ou_BRRIP = 1 (BRRIP) -> insere com 2
    assign insercao_rrpv = SRRIP_ou_BRRIP ? 2'd2 : 2'd0;

    // 10) Gravacao de tag
    assign enable_tag = acesso_valido & miss;
    assign grava_tag0 = acesso_valido & vitima0;
    assign grava_tag1 = acesso_valido & vitima1;
    assign grava_tag2 = acesso_valido & vitima2;
    assign grava_tag3 = acesso_valido & vitima3;

    // 11) Multiplexador do proximo RRPV
    assign prox_rrpv0 = hit0 ? rrpv0_hit :
                        (miss & vitima0) ? insercao_rrpv :
                        (miss & envelhecer_rrpvs & rrpv0_menor_3) ? rrpv0_mais_1 : rrpv0;
    assign prox_rrpv1 = hit1 ? rrpv1_hit :
                        (miss & vitima1) ? insercao_rrpv :
                        (miss & envelhecer_rrpvs & rrpv1_menor_3) ? rrpv1_mais_1 : rrpv1;
    assign prox_rrpv2 = hit2 ? rrpv2_hit :
                        (miss & vitima2) ? insercao_rrpv :
                        (miss & envelhecer_rrpvs & rrpv2_menor_3) ? rrpv2_mais_1 : rrpv2;
    assign prox_rrpv3 = hit3 ? rrpv3_hit :
                        (miss & vitima3) ? insercao_rrpv :
                        (miss & envelhecer_rrpvs & rrpv3_menor_3) ? rrpv3_mais_1 : rrpv3;

    assign rrpv0_next = prox_rrpv0;
    assign rrpv1_next = prox_rrpv1;
    assign rrpv2_next = prox_rrpv2;
    assign rrpv3_next = prox_rrpv3;

    // 12) Logica sequencial
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            tag0 <= 4'b0000; tag1 <= 4'b0000;
            tag2 <= 4'b0000; tag3 <= 4'b0000;
            valid0 <= 1'b0;  valid1 <= 1'b0;
            valid2 <= 1'b0;  valid3 <= 1'b0;
            rrpv0 <= 2'b00;  rrpv1 <= 2'b00;
            rrpv2 <= 2'b00;  rrpv3 <= 2'b00;
        end else begin
            if (grava_tag0) tag0 <= tag_in;
            if (grava_tag1) tag1 <= tag_in;
            if (grava_tag2) tag2 <= tag_in;
            if (grava_tag3) tag3 <= tag_in;

            if (miss & vitima0) valid0 <= 1'b1;
            if (miss & vitima1) valid1 <= 1'b1;
            if (miss & vitima2) valid2 <= 1'b1;
            if (miss & vitima3) valid3 <= 1'b1;

            rrpv0 <= prox_rrpv0;
            rrpv1 <= prox_rrpv1;
            rrpv2 <= prox_rrpv2;
            rrpv3 <= prox_rrpv3;
        end
    end

endmodule
