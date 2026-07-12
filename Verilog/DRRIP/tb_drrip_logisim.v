// timescale removido para compilar no Quartus, verificar se é um erro que sempre da
module tb_drrip_logisim;
    reg         clock;
    reg         reset;
    reg  [3:0]  tag_in;
    reg         acesso_valido;
    reg         SRRIP_ou_BRRIP;
    wire        hit0, hit1, hit2, hit3;
    wire        eh_hit;
    wire        rrpv0_igual_3, rrpv1_igual_3, rrpv2_igual_3, rrpv3_igual_3;
    wire        rrpv_igual_3;
    wire        rrpv0_menor_3, rrpv1_menor_3, rrpv2_menor_3, rrpv3_menor_3;
    wire [1:0]  idade_rrpv0, idade_rrpv1, idade_rrpv2, idade_rrpv3;
    wire [1:0]  rrpv0_mais_1, rrpv1_mais_1, rrpv2_mais_1, rrpv3_mais_1;
    wire [1:0]  rrpv0_hit, rrpv1_hit, rrpv2_hit, rrpv3_hit;
    wire        invalid0, invalid1, invalid2, invalid3;
    wire        invalido;
    wire        miss;
    wire        envelhecer_rrpvs;
    wire [1:0]  via_vitima;
    wire        vitima0, vitima1, vitima2, vitima3;
    wire        vitima_encontrada;
    wire [1:0]  insercao_rrpv;
    wire        enable_tag;
    wire        grava_tag0, grava_tag1, grava_tag2, grava_tag3;
    wire [1:0]  prox_rrpv0, prox_rrpv1, prox_rrpv2, prox_rrpv3;
    wire [1:0]  rrpv0_next, rrpv1_next, rrpv2_next, rrpv3_next;
    drrip_logisim dut (
        .clock(clock), .reset(reset), .tag_in(tag_in),
        .acesso_valido(acesso_valido), .SRRIP_ou_BRRIP(SRRIP_ou_BRRIP),
        .hit0(hit0), .hit1(hit1), .hit2(hit2), .hit3(hit3),
        .eh_hit(eh_hit),
        .rrpv0_igual_3(rrpv0_igual_3), .rrpv1_igual_3(rrpv1_igual_3),
        .rrpv2_igual_3(rrpv2_igual_3), .rrpv3_igual_3(rrpv3_igual_3),
        .rrpv_igual_3(rrpv_igual_3),
        .rrpv0_menor_3(rrpv0_menor_3), .rrpv1_menor_3(rrpv1_menor_3),
        .rrpv2_menor_3(rrpv2_menor_3), .rrpv3_menor_3(rrpv3_menor_3),
        .idade_rrpv0(idade_rrpv0), .idade_rrpv1(idade_rrpv1),
        .idade_rrpv2(idade_rrpv2), .idade_rrpv3(idade_rrpv3),
        .rrpv0_mais_1(rrpv0_mais_1), .rrpv1_mais_1(rrpv1_mais_1),
        .rrpv2_mais_1(rrpv2_mais_1), .rrpv3_mais_1(rrpv3_mais_1),
        .rrpv0_hit(rrpv0_hit), .rrpv1_hit(rrpv1_hit),
        .rrpv2_hit(rrpv2_hit), .rrpv3_hit(rrpv3_hit),
        .invalid0(invalid0), .invalid1(invalid1),
        .invalid2(invalid2), .invalid3(invalid3),
        .invalido(invalido),
        .miss(miss), .envelhecer_rrpvs(envelhecer_rrpvs),
        .via_vitima(via_vitima),
        .vitima0(vitima0), .vitima1(vitima1),
        .vitima2(vitima2), .vitima3(vitima3),
        .vitima_encontrada(vitima_encontrada),
        .insercao_rrpv(insercao_rrpv), .enable_tag(enable_tag),
        .grava_tag0(grava_tag0), .grava_tag1(grava_tag1),
        .grava_tag2(grava_tag2), .grava_tag3(grava_tag3),
        .prox_rrpv0(prox_rrpv0), .prox_rrpv1(prox_rrpv1),
        .prox_rrpv2(prox_rrpv2), .prox_rrpv3(prox_rrpv3),
        .rrpv0_next(rrpv0_next), .rrpv1_next(rrpv1_next),
        .rrpv2_next(rrpv2_next), .rrpv3_next(rrpv3_next)
    );
    initial begin
        clock = 0;
        forever #10 clock = ~clock;
    end
    initial begin
        reset = 1;
        #30;
        reset = 0;
    end
    initial begin
        $dumpfile("drrip_logisim_tb.vcd");
        $dumpvars(0, tb_drrip_logisim);
    end
    // Task corrigida: aplica no posedge, verifica APÓS o próximo posedge
    task aplicar_acesso;
        input [3:0] tag;
        input modo;
        begin
            @(posedge clock);
            tag_in = tag;
            SRRIP_ou_BRRIP = modo;
            acesso_valido = 1;
            @(posedge clock);   // módulo processa neste posedge
            acesso_valido = 0;  // desativa após processar
            // AGORA os registradores já foram atualizados
        end
    endtask
    // Task auxiliar: checa coerência da via vítima após uma substituição.
    // Usa apenas inteiros/regs simples para máxima compatibilidade.
    // num_teste: identificador numérico do teste (sem string).
    task checar_coerencia_vitima;
        input [7:0] num_teste;
        integer num_vitimas;
        integer via_esperada;
        reg grava_esperado;
        begin
            // Conta quantas vias vítimas estão ativas (deve ser exatamente 1)
            num_vitimas = vitima0 + vitima1 + vitima2 + vitima3;
            // Determina qual via é a vítima ativa e o grava_tag correspondente
            via_esperada = 0;
            grava_esperado = grava_tag0;
            if (vitima1) begin
                via_esperada = 1;
                grava_esperado = grava_tag1;
            end
            if (vitima2) begin
                via_esperada = 2;
                grava_esperado = grava_tag2;
            end
            if (vitima3) begin
                via_esperada = 3;
                grava_esperado = grava_tag3;
            end
            // Verifica todas as condições de coerência da vítima:
            //   miss=1, invalido=0, vitima_encontrada=1,
            //   exatamente uma vítima ativa,
            //   via_vitima compatível com a vítima ativa,
            //   grava_tag da via escolhida ativo.
            if (miss == 1 && invalido == 0 && vitima_encontrada == 1 &&
                num_vitimas == 1 && via_vitima == via_esperada &&
                grava_esperado == 1)
                $display("PASSOU: Teste %0d - vitima coerente (via %0d)", num_teste, via_esperada);
            else
                $display("FALHOU: Teste %0d - vitima incoerente (miss=%b invalido=%b encontrada=%b num_vit=%0d via=%0d esp=%0d grava=%b)",
                         num_teste, miss, invalido, vitima_encontrada, num_vitimas, via_vitima, via_esperada, grava_esperado);
        end
    endtask
    initial begin
        acesso_valido = 0;
        SRRIP_ou_BRRIP = 0;
        tag_in = 4'h0;
        #40;  // espera reset
        // Teste 1: tag=4'hA, SRRIP -> miss, via_vitima=0
        aplicar_acesso(4'hA, 0);
        if (miss == 1 && via_vitima == 0)
            $display("PASSOU: Teste 1 - Miss via 0");
        else
            $display("FALHOU: Teste 1 - Miss via 0 (miss=%b, via_vitima=%d)", miss, via_vitima);
        #40;
        // Teste 2: tag=4'hB, SRRIP -> miss, via_vitima=1
        aplicar_acesso(4'hB, 0);
        if (miss == 1 && via_vitima == 1)
            $display("PASSOU: Teste 2 - Miss via 1");
        else
            $display("FALHOU: Teste 2 - Miss via 1 (miss=%b, via_vitima=%d)", miss, via_vitima);
        #40;
        // Teste 3: tag=4'hC, SRRIP -> miss, via_vitima=2
        aplicar_acesso(4'hC, 0);
        if (miss == 1 && via_vitima == 2)
            $display("PASSOU: Teste 3 - Miss via 2");
        else
            $display("FALHOU: Teste 3 - Miss via 2 (miss=%b, via_vitima=%d)", miss, via_vitima);
        #40;
        // Teste 4: tag=4'hD, SRRIP -> miss, via_vitima=3
        aplicar_acesso(4'hD, 0);
        if (miss == 1 && via_vitima == 3)
            $display("PASSOU: Teste 4 - Miss via 3");
        else
            $display("FALHOU: Teste 4 - Miss via 3 (miss=%b, via_vitima=%d)", miss, via_vitima);
        #40;
        // Teste 5: tag=4'hA, SRRIP -> HIT
        aplicar_acesso(4'hA, 0);
        if (eh_hit == 1 && hit0 == 1)
            $display("PASSOU: Teste 5 - Hit via 0");
        else
            $display("FALHOU: Teste 5 - Hit via 0 (eh_hit=%b, hit0=%b)", eh_hit, hit0);
        #40;
        // Teste 6: tag=4'hE, SRRIP -> miss com envelhecimento
        aplicar_acesso(4'hE, 0);
        if (miss == 1 && envelhecer_rrpvs == 1)
            $display("PASSOU: Teste 6 - Miss com envelhecimento");
        else
            $display("FALHOU: Teste 6 - Miss com envelhecimento (miss=%b, envelhecer=%b)", miss, envelhecer_rrpvs);
        #40;
        // Teste 7: tag=4'hB, BRRIP -> HIT
        aplicar_acesso(4'hB, 1);
        if (eh_hit == 1 && hit1 == 1 && rrpv1_next == 2)
            $display("PASSOU: Teste 7 - Hit via 1 BRRIP");
        else
            $display("FALHOU: Teste 7 - Hit via 1 BRRIP (eh_hit=%b, hit1=%b, rrpv1_next=%d)", eh_hit, hit1, rrpv1_next);
        #40;
        // Teste 8: tag=4'hF, BRRIP -> miss
        aplicar_acesso(4'hF, 1);
        if (miss == 1 && insercao_rrpv == 2)
            $display("PASSOU: Teste 8 - Miss BRRIP insercao_rrpv=2");
        else
            $display("FALHOU: Teste 8 - Miss BRRIP (miss=%b, insercao=%d)", miss, insercao_rrpv);
        #40;
        // Teste 9: tag=4'h1, SRRIP -> miss com substituição (todas as vias válidas)
        // Valida coerência da seleção da via vítima:
        //   miss=1, invalido=0, vitima_encontrada=1,
        //   exatamente uma vítima ativa, via_vitima compatível,
        //   grava_tag da via escolhida ativo.
        aplicar_acesso(4'h1, 0);
        checar_coerencia_vitima(8'd9);
        #40;
        // Teste 10: tag=4'h2, BRRIP -> miss com substituição
        // Mesma validação de coerência da vítima + insercao_rrpv==2.
        aplicar_acesso(4'h2, 1);
        checar_coerencia_vitima(8'd10);
        if (insercao_rrpv == 2)
            $display("PASSOU: Teste 10 - BRRIP insercao_rrpv=2");
        else
            $display("FALHOU: Teste 10 - BRRIP insercao_rrpv=%0d (esperado 2)", insercao_rrpv);
        #40;
        $finish;
    end
endmodule
