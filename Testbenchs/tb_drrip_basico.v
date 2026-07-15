// tb_drrip_basico.v
// Testa:
// 1. Primeiro acesso produz miss.
// 2. Segundo acesso igual produz hit.
// 3. PSEL aumenta em misses do lider SRRIP.
// 4. PSEL diminui em misses do lider BRRIP.

`timescale 1ns/1ps

module tb_drrip_basico;

    reg         clock;
    reg         reset;
    reg  [31:0] addr_in;
    reg         acesso_valido;

    wire        eh_hit;
    wire        miss;
    wire [1:0]  via_vitima;
    wire        vitima_encontrada;
    wire [1:0]  rrpv_insercao_usado;
    wire        politica_brrip_usada;
    wire [5:0]  psel_atual;
    wire [4:0]  set_index;
    wire [21:0] tag_extraida;

    integer erros;
    integer i;

    cache_drrip dut (
        .clock(clock),
        .reset(reset),
        .addr_in(addr_in),
        .acesso_valido(acesso_valido),

        .eh_hit(eh_hit),
        .miss(miss),
        .via_vitima(via_vitima),
        .vitima_encontrada(vitima_encontrada),

        .rrpv_insercao_usado(
            rrpv_insercao_usado
        ),

        .politica_brrip_usada(
            politica_brrip_usada
        ),

        .psel_atual(psel_atual),
        .set_index(set_index),
        .tag_extraida(tag_extraida)
    );

    // Clock com periodo de 10 ns.
    initial begin
        clock = 1'b0;

        forever
            #5 clock = ~clock;
    end

    // Monta um endereco escolhendo tag e conjunto.
    function [31:0] cria_endereco;
        input [21:0] tag;
        input [4:0]  conjunto;

        begin
            cria_endereco = {
                tag,
                conjunto,
                5'b00000
            };
        end
    endfunction

    task aplicar_reset;
        begin
            reset         = 1'b1;
            acesso_valido = 1'b0;
            addr_in       = 32'd0;

            repeat (2)
                @(posedge clock);

            #1;
            reset = 1'b0;
        end
    endtask

    task fazer_acesso;
        input [31:0] endereco;
        input        hit_esperado;

        begin
            // Coloca o endereco na borda de descida.
            @(negedge clock);

            addr_in       = endereco;
            acesso_valido = 1'b1;

            #1;

            // Verifica o resultado antes da atualizacao.
            if (hit_esperado && !eh_hit) begin
                $display(
                    "ERRO: era esperado HIT no endereco %h",
                    endereco
                );

                erros = erros + 1;
            end

            if (!hit_esperado && !miss) begin
                $display(
                    "ERRO: era esperado MISS no endereco %h",
                    endereco
                );

                erros = erros + 1;
            end

            // A cache atualiza na borda de subida.
            @(posedge clock);

            #1;
            acesso_valido = 1'b0;
        end
    endtask

    initial begin
        erros         = 0;
        reset         = 1'b0;
        addr_in       = 32'd0;
        acesso_valido = 1'b0;

        aplicar_reset;

        $display("========================================");
        $display("TESTE BASICO DO DRRIP");
        $display("PSEL inicial = %0d", psel_atual);
        $display("========================================");

        // O conjunto 10 e um conjunto seguidor.
        // Primeiro acesso: miss.
        fazer_acesso(
            cria_endereco(22'd1, 5'd10),
            1'b0
        );

        // Mesmo endereco: hit.
        fazer_acesso(
            cria_endereco(22'd1, 5'd10),
            1'b1
        );

        // Misses no lider SRRIP fazem PSEL aumentar.
        for (i = 0; i < 6; i = i + 1) begin
            fazer_acesso(
                cria_endereco(
                    i + 22'd10,
                    5'd0
                ),
                1'b0
            );
        end

        $display(
            "PSEL depois do lider SRRIP = %0d",
            psel_atual
        );

        if (psel_atual <= 6'd31) begin
            $display(
                "ERRO: PSEL deveria ter aumentado."
            );

            erros = erros + 1;
        end

        // Misses no lider BRRIP fazem PSEL diminuir.
        for (i = 0; i < 10; i = i + 1) begin
            fazer_acesso(
                cria_endereco(
                    i + 22'd30,
                    5'd2
                ),
                1'b0
            );
        end

        $display(
            "PSEL depois do lider BRRIP = %0d",
            psel_atual
        );

        if (psel_atual >= 6'd37) begin
            $display(
                "ERRO: PSEL deveria ter diminuido."
            );

            erros = erros + 1;
        end

        if (erros == 0) begin
            $display(
                "RESULTADO: TODOS OS TESTES PASSARAM."
            );
        end
        else begin
            $display(
                "RESULTADO: %0d ERRO(S).",
                erros
            );
        end

        $finish;
    end

endmodule