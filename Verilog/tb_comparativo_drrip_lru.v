// tb_comparativo_drrip_lru.v
// Compara DRRIP e LRU recebendo os mesmos acessos.
//
// O resultado de hit ou miss e lido antes da borda
// de subida. Na borda, a cache atualiza seu estado.

`timescale 1ns/1ps

module tb_comparativo_drrip_lru;

    reg         clock;
    reg         reset;
    reg  [31:0] addr_in;
    reg         acesso_valido;

    // Saidas do DRRIP.
    wire        hit_drrip;
    wire        miss_drrip;
    wire [1:0]  vitima_drrip;
    wire        vitima_encontrada_drrip;
    wire [1:0]  insercao_drrip;
    wire        politica_brrip;
    wire [5:0]  psel;
    wire [4:0]  set_drrip;
    wire [21:0] tag_drrip;

    // Saidas do LRU.
    wire        hit_lru;
    wire        miss_lru;
    wire [1:0]  vitima_lru;
    wire        vitima_encontrada_lru;
    wire [4:0]  set_lru;
    wire [21:0] tag_lru;

    integer total_acessos;
    integer hits_drrip;
    integer misses_drrip;
    integer hits_lru;
    integer misses_lru;
    integer erros_contagem;

    integer i;
    integer j;

    real taxa_drrip;
    real taxa_lru;

    cache_drrip cache_inteligente (
        .clock(clock),
        .reset(reset),
        .addr_in(addr_in),
        .acesso_valido(acesso_valido),

        .eh_hit(hit_drrip),
        .miss(miss_drrip),
        .via_vitima(vitima_drrip),

        .vitima_encontrada(
            vitima_encontrada_drrip
        ),

        .rrpv_insercao_usado(
            insercao_drrip
        ),

        .politica_brrip_usada(
            politica_brrip
        ),

        .psel_atual(psel),
        .set_index(set_drrip),
        .tag_extraida(tag_drrip)
    );

    cache_lru cache_referencia (
        .clock(clock),
        .reset(reset),
        .addr_in(addr_in),
        .acesso_valido(acesso_valido),

        .eh_hit(hit_lru),
        .miss(miss_lru),
        .via_vitima(vitima_lru),

        .vitima_encontrada(
            vitima_encontrada_lru
        ),

        .set_index(set_lru),
        .tag_extraida(tag_lru)
    );

    // Clock de 10 ns.
    initial begin
        clock = 1'b0;

        forever
            #5 clock = ~clock;
    end

    // Timeout de seguranca.
    initial begin
        #2000000;

        $display("ERRO: timeout da simulacao.");
        $finish;
    end

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

    task zerar_contadores;
        begin
            total_acessos  = 0;

            hits_drrip     = 0;
            misses_drrip   = 0;

            hits_lru       = 0;
            misses_lru     = 0;

            erros_contagem = 0;
        end
    endtask

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

        begin
            // Coloca o endereco na borda de descida.
            @(negedge clock);

            addr_in       = endereco;
            acesso_valido = 1'b1;

            #1;

            // Le hit e miss antes da atualizacao.
            total_acessos = total_acessos + 1;

            if (hit_drrip)
                hits_drrip = hits_drrip + 1;

            if (miss_drrip)
                misses_drrip = misses_drrip + 1;

            if (hit_lru)
                hits_lru = hits_lru + 1;

            if (miss_lru)
                misses_lru = misses_lru + 1;

            // Deve existir exatamente um resultado:
            // hit ou miss.
            if (!(hit_drrip ^ miss_drrip)) begin
                $display(
                    "ERRO de contagem no DRRIP: %h",
                    endereco
                );

                erros_contagem =
                    erros_contagem + 1;
            end

            if (!(hit_lru ^ miss_lru)) begin
                $display(
                    "ERRO de contagem no LRU: %h",
                    endereco
                );

                erros_contagem =
                    erros_contagem + 1;
            end

            // A atualizacao acontece nesta borda.
            @(posedge clock);

            #1;
            acesso_valido = 1'b0;
        end
    endtask

    task mostrar_resultado;
        input [8*80-1:0] nome;

        begin
            if (total_acessos > 0) begin
                taxa_drrip =
                    (100.0 * hits_drrip) /
                    total_acessos;

                taxa_lru =
                    (100.0 * hits_lru) /
                    total_acessos;
            end
            else begin
                taxa_drrip = 0.0;
                taxa_lru   = 0.0;
            end

            $display(
                "------------------------------------------------"
            );

            $display("Benchmark: %s", nome);

            $display(
                "Total de acessos: %0d",
                total_acessos
            );

            $display(
                "DRRIP: hits=%0d misses=%0d taxa=%0.2f%%",
                hits_drrip,
                misses_drrip,
                taxa_drrip
            );

            $display(
                "LRU: hits=%0d misses=%0d taxa=%0.2f%%",
                hits_lru,
                misses_lru,
                taxa_lru
            );

            $display(
                "PSEL final: %0d",
                psel
            );

            $display(
                "Erros de contagem: %0d",
                erros_contagem
            );
        end
    endtask

    // Quatro blocos cabem no conjunto.
    task benchmark_reuso;
        begin
            aplicar_reset;
            zerar_contadores;

            for (i = 0; i < 10; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    fazer_acesso(
                        cria_endereco(j, 5'd10)
                    );
                end
            end

            mostrar_resultado(
                "Reuso de quatro blocos"
            );
        end
    endtask

    // Cinco blocos disputam quatro vias.
    task benchmark_conflito;
        begin
            aplicar_reset;
            zerar_contadores;

            for (i = 0; i < 12; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    fazer_acesso(
                        cria_endereco(j, 5'd10)
                    );
                end
            end

            mostrar_resultado(
                "Cinco blocos em quatro vias"
            );
        end
    endtask

    // Bloco quente misturado com streaming.
    task benchmark_quente_streaming;
        begin
            aplicar_reset;

            // Faz o PSEL favorecer BRRIP nos seguidores.
            for (i = 0; i < 8; i = i + 1) begin
                fazer_acesso(
                    cria_endereco(
                        i + 22'd100,
                        5'd0
                    )
                );
            end

            // Os acessos de treinamento nao entram no resultado.
            zerar_contadores;

            // Primeiro acesso e miss.
            fazer_acesso(
                cria_endereco(22'd1, 5'd10)
            );

            // Segundo acesso e hit, deixando o bloco quente.
            fazer_acesso(
                cria_endereco(22'd1, 5'd10)
            );

            for (i = 0; i < 15; i = i + 1) begin
                fazer_acesso(
                    cria_endereco(
                        i + 22'd20,
                        5'd10
                    )
                );

                fazer_acesso(
                    cria_endereco(
                        i + 22'd50,
                        5'd10
                    )
                );

                fazer_acesso(
                    cria_endereco(
                        i + 22'd80,
                        5'd10
                    )
                );

                fazer_acesso(
                    cria_endereco(
                        i + 22'd110,
                        5'd10
                    )
                );

                fazer_acesso(
                    cria_endereco(
                        22'd1,
                        5'd10
                    )
                );
            end

            mostrar_resultado(
                "Bloco quente com streaming"
            );
        end
    endtask

    // Utiliza todos os conjuntos.
    task benchmark_distribuido;
        begin
            aplicar_reset;
            zerar_contadores;

            // Primeira passagem.
            for (i = 0; i < 32; i = i + 1) begin
                fazer_acesso(
                    cria_endereco(22'd1, i)
                );

                fazer_acesso(
                    cria_endereco(22'd2, i)
                );
            end

            // Segunda passagem.
            for (i = 0; i < 32; i = i + 1) begin
                fazer_acesso(
                    cria_endereco(22'd1, i)
                );

                fazer_acesso(
                    cria_endereco(22'd2, i)
                );
            end

            mostrar_resultado(
                "Acessos nos 32 conjuntos"
            );
        end
    endtask

    initial begin
        reset         = 1'b0;
        addr_in       = 32'd0;
        acesso_valido = 1'b0;

        $display(
            "================================================"
        );

        $display("COMPARACAO ENTRE DRRIP E LRU");

        $display(
            "Cache: 4 KB, 4 vias, bloco de 32 bytes"
        );

        $display(
            "================================================"
        );

        benchmark_reuso;
        benchmark_conflito;
        benchmark_quente_streaming;
        benchmark_distribuido;

        $display(
            "------------------------------------------------"
        );

        $display("Simulacao finalizada.");

        $finish;
    end

endmodule