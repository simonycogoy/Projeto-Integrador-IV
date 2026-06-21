//============================================================================
// Testbench simples para ModelSim
//============================================================================
// Módulo: tb_drrip_4way_ctrl
//----------------------------------------------------------------------------
// Gera clock/reset e estimula os quatro cenários solicitados:
//   a) hit em uma way e atualização para RRPV=00;
//   b) refill com way inválida disponível;
//   c) refill com todas válidas e escolha por RRPV máximo;
//   d) caso que force aging antes de encontrar vítima.
//----------------------------------------------------------------------------

`timescale 1ns/1ps

module tb_drrip_4way_ctrl;

    // Parâmetros
    localparam SETS      = 16;
    localparam IDX_W     = 4;
    localparam RRPV_BITS = 2;
    localparam PSEL_BITS = 4;

    // Sinais do DUT
    reg                  clk;
    reg                  rst;
    reg                  access_valid;
    reg                  access_is_hit;
    reg  [IDX_W-1:0]     set_idx;
    reg  [3:0]           valid_vec;
    reg  [1:0]           hit_way;
    reg                  refill_valid;
    wire [1:0]           victim_way;
    wire                 victim_found;
    wire [RRPV_BITS-1:0] insert_rrpv;
    wire                 psel_msb_policy;

    // Instanciação do DUT
    drrip_4way_ctrl
    #(
        .SETS(SETS),
        .IDX_W(IDX_W),
        .RRPV_BITS(RRPV_BITS),
        .PSEL_BITS(PSEL_BITS)
    )
    dut
    (
        .clk(clk),
        .rst(rst),
        .access_valid(access_valid),
        .access_is_hit(access_is_hit),
        .set_idx(set_idx),
        .valid_vec(valid_vec),
        .hit_way(hit_way),
        .refill_valid(refill_valid),
        .victim_way(victim_way),
        .victim_found(victim_found),
        .insert_rrpv(insert_rrpv),
        .psel_msb_policy(psel_msb_policy)
    );

    // Geração de clock (período 10 ns)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Tarefa utilitária: aplica um ciclo de estimulo
    task apply_cycle;
        input av;
        input ah;
        input [IDX_W-1:0] idx;
        input [3:0] vv;
        input [1:0] hw;
        input rv;
        begin
            @(posedge clk);
            access_valid  <= av;
            access_is_hit <= ah;
            set_idx       <= idx;
            valid_vec     <= vv;
            hit_way       <= hw;
            refill_valid  <= rv;
            @(posedge clk);
            access_valid  <= 1'b0;
            access_is_hit <= 1'b0;
            refill_valid  <= 1'b0;
        end
    endtask

    // Teste principal
    initial begin
        // Inicialização
        rst           = 1'b1;
        access_valid  = 1'b0;
        access_is_hit = 1'b0;
        set_idx       = 4'd0;
        valid_vec     = 4'b0000;
        hit_way       = 2'd0;
        refill_valid  = 1'b0;

        #20;
        rst = 1'b0;
        #10;

        $display("==============================================");
        $display("Inicio da simulacao DRRIP 4-way controller");
        $display("==============================================");
        $display("Tempo | set | valid_vec | hit | refill | victim_way | found | insert_rrpv | policy");

        //-----------------------------------------------------------------
        // Cenário (a): hit na way 0, set 0 -> RRPV deve ir para 00
        //-----------------------------------------------------------------
        // Preparação: fazemos um refill inicial para que a way 0 exista.
        apply_cycle(1'b0, 1'b0, 4'd0, 4'b0000, 2'd0, 1'b1);
        $display("%0t | %0d | %b | - | 1 | %0d | %b | %b | %b (preparacao refill way invalida)",
                 $time, set_idx, valid_vec, victim_way, victim_found, insert_rrpv, psel_msb_policy);

        // Agora a way 0 é válida.  Vamos simular um hit nela.
        apply_cycle(1'b1, 1'b1, 4'd0, 4'b0001, 2'd0, 1'b0);
        $display("%0t | %0d | %b | 0 | 0 | %0d | %b | %b | %b (hit way0 -> RRPV=00)",
                 $time, set_idx, valid_vec, victim_way, victim_found, insert_rrpv, psel_msb_policy);

        //-----------------------------------------------------------------
        // Cenário (b): refill com way inválida disponível, set 1
        //-----------------------------------------------------------------
        apply_cycle(1'b0, 1'b0, 4'd1, 4'b0010, 2'd0, 1'b1);
        $display("%0t | %0d | %b | - | 1 | %0d | %b | %b | %b (refill way invalida -> way 0?)",
                 $time, set_idx, valid_vec, victim_way, victim_found, insert_rrpv, psel_msb_policy);

        //-----------------------------------------------------------------
        // Cenário (c): refill com todas válidas, set 2; vítima = RRPV máximo
        //-----------------------------------------------------------------
        // Preenche o set 2 com 4 refills, todas as ways válidas.
        apply_cycle(1'b0, 1'b0, 4'd2, 4'b0000, 2'd0, 1'b1); // way 0
        apply_cycle(1'b0, 1'b0, 4'd2, 4'b0001, 2'd0, 1'b1); // way 1
        apply_cycle(1'b0, 1'b0, 4'd2, 4'b0011, 2'd0, 1'b1); // way 2
        apply_cycle(1'b0, 1'b0, 4'd2, 4'b0111, 2'd0, 1'b1); // way 3
        // Refill extra: todas as ways já são válidas -> escolhe a com RRPV=11
        apply_cycle(1'b0, 1'b0, 4'd2, 4'b1111, 2'd0, 1'b1);
        $display("%0t | %0d | %b | - | 1 | %0d | %b | %b | %b (refill todas validas -> RRPV max)",
                 $time, set_idx, valid_vec, victim_way, victim_found, insert_rrpv, psel_msb_policy);

        //-----------------------------------------------------------------
        // Cenário (d): forçar aging.  set 3 com todas válidas e RRPVs baixos.
        // Primeiro inserimos quatro blocos com SRRIP (RRPV=10).  Depois
        // fazemos refill sem nenhuma 11 -> aging incrementa todos para 11.
        //-----------------------------------------------------------------
        apply_cycle(1'b0, 1'b0, 4'd3, 4'b0000, 2'd0, 1'b1); // way0=10
        apply_cycle(1'b0, 1'b0, 4'd3, 4'b0001, 2'd0, 1'b1); // way1=10
        apply_cycle(1'b0, 1'b0, 4'd3, 4'b0011, 2'd0, 1'b1); // way2=10
        apply_cycle(1'b0, 1'b0, 4'd3, 4'b0111, 2'd0, 1'b1); // way3=10

        // Dá um hit na way0 para forçá-la a RRPV=00, mantendo as outras em 10.
        apply_cycle(1'b1, 1'b1, 4'd3, 4'b1111, 2'd0, 1'b0);

        // Agora refill: nenhuma way com RRPV=11 (ways 1,2,3=10; way0=00).
        // Aging deve incrementar todas até aparecer 11; vítima será uma delas.
        apply_cycle(1'b0, 1'b0, 4'd3, 4'b1111, 2'd0, 1'b1);
        $display("%0t | %0d | %b | - | 1 | %0d | %b | %b | %b (refill forca aging)",
                 $time, set_idx, valid_vec, victim_way, victim_found, insert_rrpv, psel_msb_policy);

        // Mais alguns ciclos para observar estabilidade
        repeat (5) @(posedge clk);

        $display("==============================================");
        $display("Fim da simulacao");
        $display("==============================================");
        $stop;
    end

    // Opcional: monitor contínuo para depuração
    initial begin
        $monitor("MON %0t | set=%0d valid=%b hit=%b refill=%b victim=%0d found=%b insert=%b policy=%b",
                 $time, set_idx, valid_vec, access_is_hit, refill_valid,
                 victim_way, victim_found, insert_rrpv, psel_msb_policy);
    end

endmodule
