// tb_benchmarks_completos.v
//
// Compara DRRIP e LRU usando uma unica configuracao de cache:
// - 4 KB
// - 4 vias
// - blocos de 32 bytes
// - 32 conjuntos
//
// Benchmarks incluidos:
// 1. Reuso de quatro blocos
// 2. Conflito de cinco blocos em quatro vias
// 3. Streaming + HotSet
// 4. Convolucao de matriz
// 5. Lista encadeada / pointer chasing
// 6. Busca de padroes
// 7. Acessos distribuidos
// 8. Mudanca de fase do DRRIP

`timescale 1ns/1ps

module tb_benchmarks_completos;

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

    // Contadores usados nos resultados.
    integer total_acessos;
    integer hits_drrip;
    integer misses_drrip;
    integer hits_lru;
    integer misses_lru;
    integer erros_contagem;

    integer i;
    integer j;
    integer y;
    integer x;
    integer node;

    real taxa_drrip;
    real taxa_lru;
    real diferenca_pp;

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

    // Clock com periodo de 10 ns.
    initial begin
        clock = 1'b0;

        forever
            #5 clock = ~clock;
    end

    // Timeout de seguranca.
    initial begin
        #5000000;

        $display("ERRO: timeout da simulacao.");
        $finish;
    end

    // Monta um endereco escolhendo diretamente
    // a tag e o conjunto.
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

    // Realiza o mesmo acesso nas duas caches.
    //
    // contar = 1:
    // o acesso entra nos resultados.
    //
    // contar = 0:
    // acesso usado somente para treinar o PSEL.
    task fazer_acesso;
        input [31:0] endereco;
        input        contar;

        begin
            @(negedge clock);

            addr_in       = endereco;
            acesso_valido = 1'b1;

            // Espera a logica combinacional estabilizar.
            #1;

            if (contar) begin
                total_acessos =
                    total_acessos + 1;

                if (hit_drrip)
                    hits_drrip =
                        hits_drrip + 1;

                if (miss_drrip)
                    misses_drrip =
                        misses_drrip + 1;

                if (hit_lru)
                    hits_lru =
                        hits_lru + 1;

                if (miss_lru)
                    misses_lru =
                        misses_lru + 1;

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
            end

            // Atualiza os metadados nesta borda.
            @(posedge clock);

            // Desliga o acesso sem gerar o pequeno
            // pulso observado anteriormente.
            acesso_valido <= 1'b0;
            addr_in       <= 32'd0;

            #1;
        end
    endtask

    // Misses nos conjuntos lideres SRRIP aumentam
    // o PSEL e fazem os seguidores escolherem BRRIP.
    task treinar_para_brrip;
        begin
            for (i = 0; i < 16; i = i + 1) begin
                fazer_acesso(
                    cria_endereco(
                        i + 22'd500,
                        5'd0
                    ),
                    1'b0
                );
            end
        end
    endtask

    // Misses nos conjuntos lideres BRRIP diminuem
    // o PSEL e fazem os seguidores escolherem SRRIP.
    task treinar_para_srrip;
        begin
            for (i = 0; i < 40; i = i + 1) begin
                fazer_acesso(
                    cria_endereco(
                        i + 22'd800,
                        5'd2
                    ),
                    1'b0
                );
            end
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

                diferenca_pp =
                    taxa_drrip - taxa_lru;
            end
            else begin
                taxa_drrip   = 0.0;
                taxa_lru     = 0.0;
                diferenca_pp = 0.0;
            end

            $display(
                "------------------------------------------------------------"
            );

            $display(
                "Benchmark: %s",
                nome
            );

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
                "LRU:   hits=%0d misses=%0d taxa=%0.2f%%",
                hits_lru,
                misses_lru,
                taxa_lru
            );

            $display(
                "Diferenca DRRIP - LRU: %0.2f pontos percentuais",
                diferenca_pp
            );

            $display(
                "PSEL final: %0d",
                psel
            );

            $display(
                "Erros de contagem: %0d",
                erros_contagem
            );

            if (
                (hits_drrip + misses_drrip)
                != total_acessos
            ) begin
                $display(
                    "ERRO: soma do DRRIP diferente do total."
                );
            end

            if (
                (hits_lru + misses_lru)
                != total_acessos
            ) begin
                $display(
                    "ERRO: soma do LRU diferente do total."
                );
            end
        end
    endtask

    // ==========================================================
    // 1. REUSO DE QUATRO BLOCOS
    //
    // Quatro blocos cabem exatamente nas quatro vias.
    // ==========================================================
    task benchmark_reuso_quatro_blocos;
        begin
            aplicar_reset;
            zerar_contadores;

            for (i = 0; i < 10; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    fazer_acesso(
                        cria_endereco(
                            j,
                            5'd10
                        ),
                        1'b1
                    );
                end
            end

            mostrar_resultado(
                "Reuso de quatro blocos"
            );
        end
    endtask

    // ==========================================================
    // 2. CINCO BLOCOS EM QUATRO VIAS
    //
    // Os cinco blocos disputam o mesmo conjunto.
    // ==========================================================
    task benchmark_cinco_blocos;
        begin
            aplicar_reset;
            zerar_contadores;

            for (i = 0; i < 12; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    fazer_acesso(
                        cria_endereco(
                            j,
                            5'd10
                        ),
                        1'b1
                    );
                end
            end

            mostrar_resultado(
                "Cinco blocos em quatro vias"
            );
        end
    endtask

    // ==========================================================
    // 3. STREAMING + HOTSET
    //
    // Dois blocos quentes sao reutilizados enquanto blocos
    // usados somente uma vez passam pelo mesmo conjunto.
    // ==========================================================
    task benchmark_streaming_hotset;
        begin
            aplicar_reset;

            // Coloca os conjuntos seguidores em modo BRRIP.
            treinar_para_brrip;

            zerar_contadores;

            for (i = 0; i < 32; i = i + 1) begin

                // Primeiro bloco quente.
                fazer_acesso(
                    cria_endereco(
                        22'd1,
                        5'd10
                    ),
                    1'b1
                );

                // Segundo bloco quente.
                fazer_acesso(
                    cria_endereco(
                        22'd2,
                        5'd10
                    ),
                    1'b1
                );

                // Quatro blocos diferentes de streaming.
                for (j = 0; j < 4; j = j + 1) begin
                    fazer_acesso(
                        cria_endereco(
                            22'd100 +
                            (i * 4) +
                            j,

                            5'd10
                        ),
                        1'b1
                    );
                end

                // Reutiliza os dois blocos quentes.
                fazer_acesso(
                    cria_endereco(
                        22'd1,
                        5'd10
                    ),
                    1'b1
                );

                fazer_acesso(
                    cria_endereco(
                        22'd2,
                        5'd10
                    ),
                    1'b1
                );
            end

            mostrar_resultado(
                "Streaming + HotSet"
            );
        end
    endtask

    // ==========================================================
    // 4. CONVOLUCAO DE MATRIZ
    //
    // Simula uma janela vertical com tres elementos
    // e uma escrita na matriz de saida.
    // ==========================================================
    task benchmark_convolucao_matriz;
        begin
            aplicar_reset;
            zerar_contadores;

            // Largura da matriz: 64 inteiros.
            // Cada inteiro ocupa 4 bytes.
            for (y = 1; y < 9; y = y + 1) begin
                for (x = 1; x < 63; x = x + 1) begin

                    // Linha anterior.
                    fazer_acesso(
                        32'h00100000 +
                        (
                            (
                                ((y - 1) * 64) + x
                            ) * 4
                        ),
                        1'b1
                    );

                    // Linha atual.
                    fazer_acesso(
                        32'h00100000 +
                        (
                            (
                                (y * 64) + x
                            ) * 4
                        ),
                        1'b1
                    );

                    // Linha seguinte.
                    fazer_acesso(
                        32'h00100000 +
                        (
                            (
                                ((y + 1) * 64) + x
                            ) * 4
                        ),
                        1'b1
                    );

                    // Matriz de saida.
                    fazer_acesso(
                        32'h00200000 +
                        (
                            (
                                (y * 64) + x
                            ) * 4
                        ),
                        1'b1
                    );
                end
            end

            mostrar_resultado(
                "Convolucao de matriz 2D"
            );
        end
    endtask

    // ==========================================================
    // 5. LISTA ENCADEADA
    //
    // Os nos sao acessados em ordem espalhada.
    // Cada no ocupa um bloco completo de 32 bytes.
    // ==========================================================
    task benchmark_lista_encadeada;
        begin
            aplicar_reset;
            zerar_contadores;

            for (i = 0; i < 1024; i = i + 1) begin

                // Sequencia deterministica,
                // mas espalhada na memoria.
                node =
                    ((i * 73) + 19) % 256;

                fazer_acesso(
                    32'h00300000 +
                    (node * 32),
                    1'b1
                );
            end

            mostrar_resultado(
                "Lista encadeada / Pointer Chasing"
            );
        end
    endtask

    // ==========================================================
    // 6. BUSCA DE PADROES
    //
    // Para cada posicao atual, consulta as oito
    // posicoes anteriores.
    // ==========================================================
    task benchmark_busca_padroes;
        begin
            aplicar_reset;
            zerar_contadores;

            for (i = 64; i < 256; i = i + 1) begin
                for (j = 1; j <= 8; j = j + 1) begin

                    // Posicao atual.
                    fazer_acesso(
                        32'h00400000 + i,
                        1'b1
                    );

                    // Posicao anterior.
                    fazer_acesso(
                        32'h00400000 + i - j,
                        1'b1
                    );
                end
            end

            mostrar_resultado(
                "Busca de padroes em memoria"
            );
        end
    endtask

    // ==========================================================
    // 7. ACESSOS DISTRIBUIDOS
    //
    // Dois blocos sao colocados em cada conjunto.
    // Na segunda passagem, eles devem estar presentes.
    // ==========================================================
    task benchmark_distribuido;
        begin
            aplicar_reset;
            zerar_contadores;

            // Primeira passagem.
            for (i = 0; i < 32; i = i + 1) begin
                fazer_acesso(
                    cria_endereco(
                        22'd1,
                        i
                    ),
                    1'b1
                );

                fazer_acesso(
                    cria_endereco(
                        22'd2,
                        i
                    ),
                    1'b1
                );
            end

            // Segunda passagem.
            for (i = 0; i < 32; i = i + 1) begin
                fazer_acesso(
                    cria_endereco(
                        22'd1,
                        i
                    ),
                    1'b1
                );

                fazer_acesso(
                    cria_endereco(
                        22'd2,
                        i
                    ),
                    1'b1
                );
            end

            mostrar_resultado(
                "Acessos nos 32 conjuntos"
            );
        end
    endtask

    // ==========================================================
    // 8. MUDANCA DE FASE
    //
    // Primeiro o PSEL favorece BRRIP.
    // Depois o PSEL e deslocado para SRRIP.
    // ==========================================================
    task benchmark_mudanca_fase;
        begin
            aplicar_reset;

            // ---------------- FASE BRRIP ----------------

            treinar_para_brrip;

            $display(
                "------------------------------------------------------------"
            );

            $display(
                "Mudanca de fase: PSEL apos treino BRRIP = %0d",
                psel
            );

            zerar_contadores;

            for (i = 0; i < 16; i = i + 1) begin

                // Blocos quentes.
                fazer_acesso(
                    cria_endereco(
                        22'd10,
                        5'd12
                    ),
                    1'b1
                );

                fazer_acesso(
                    cria_endereco(
                        22'd11,
                        5'd12
                    ),
                    1'b1
                );

                // Streaming.
                for (j = 0; j < 4; j = j + 1) begin
                    fazer_acesso(
                        cria_endereco(
                            22'd300 +
                            (i * 4) +
                            j,

                            5'd12
                        ),
                        1'b1
                    );
                end

                // Reuso dos blocos quentes.
                fazer_acesso(
                    cria_endereco(
                        22'd10,
                        5'd12
                    ),
                    1'b1
                );

                fazer_acesso(
                    cria_endereco(
                        22'd11,
                        5'd12
                    ),
                    1'b1
                );
            end

            mostrar_resultado(
                "Mudanca de fase - fase BRRIP"
            );

            // ---------------- FASE SRRIP ----------------

            treinar_para_srrip;

            $display(
                "------------------------------------------------------------"
            );

            $display(
                "Mudanca de fase: PSEL apos treino SRRIP = %0d",
                psel
            );

            zerar_contadores;

            // Quatro blocos com forte reuso.
            for (i = 0; i < 10; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    fazer_acesso(
                        cria_endereco(
                            22'd20 + j,
                            5'd14
                        ),
                        1'b1
                    );
                end
            end

            mostrar_resultado(
                "Mudanca de fase - fase SRRIP"
            );
        end
    endtask

    initial begin
        reset         = 1'b0;
        addr_in       = 32'd0;
        acesso_valido = 1'b0;

        $display(
            "============================================================"
        );

        $display(
            "BENCHMARKS COMPLETOS: DRRIP X LRU"
        );

        $display(
            "Cache: 4 KB, 4 vias, blocos de 32 bytes"
        );

        $display(
            "============================================================"
        );

        benchmark_reuso_quatro_blocos;
        benchmark_cinco_blocos;
        benchmark_streaming_hotset;
        benchmark_convolucao_matriz;
        benchmark_lista_encadeada;
        benchmark_busca_padroes;
        benchmark_distribuido;
        benchmark_mudanca_fase;

        $display(
            "============================================================"
        );

        $display(
            "SIMULACAO FINALIZADA."
        );

        $display(
            "============================================================"
        );

        $finish;
    end

endmodule