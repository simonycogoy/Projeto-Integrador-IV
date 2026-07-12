// tb_microbench.v
// Versao final corrigida do testbench para a cache L1 unificada (cache_unica).
// Compativel com Quartus 13 / ModelSim antigos (Verilog basico).
//
// DUT: cache_unica
//   Entradas : clock, reset, addr_in[13:0], acesso_valido, SRRIP_ou_BRRIP
//   Saidas   : eh_hit, miss, invalido, via_vitima[1:0], vitima_encontrada,
//              insercao_rrpv[1:0], set_index[4:0], tag_extraida[3:0],
//              hit0, hit1, hit2, hit3
//
// Mapeamento de endereco (14 bits):
//   {tag[3:0], indice[4:0], offset[4:0]}
//   tag    = addr_in[13:10]
//   indice = addr_in[9:5]
//   offset = addr_in[4:0]
//
// Este testbench executa TODOS os 4 benchmarks em DUAS politicas:
//   1) SRRIP com SRRIP_ou_BRRIP = 0
//   2) BRRIP com SRRIP_ou_BRRIP = 1
// O codigo anterior errado usava sempre 1'b1. Corrigido aqui.

`timescale 1ns / 1ps

module tb_microbench;

    // ------------------------------------------------------------------
    // Sinais do DUT
    // ------------------------------------------------------------------
    reg         clock;
    reg         reset;
    reg  [13:0] addr_in;
    reg         acesso_valido;
    reg         SRRIP_ou_BRRIP;

    wire        eh_hit;
    wire        miss;
    wire        invalido;
    wire [1:0]  via_vitima;
    wire        vitima_encontrada;
    wire [1:0]  insercao_rrpv;
    wire [4:0]  set_index;
    wire [3:0]  tag_extraida;
    wire        hit0;
    wire        hit1;
    wire        hit2;
    wire        hit3;

    // ------------------------------------------------------------------
    // Strings para relatorio (compativel com Quartus 13 / ModelSim antigos)
    // ------------------------------------------------------------------
    reg [255*8-1:0] str_politica;
    reg [255*8-1:0] str_bench;

    // ------------------------------------------------------------------
    // Contadores de relatorio por benchmark/politica
    // ------------------------------------------------------------------
    integer total_acessos;
    integer total_hits;
    integer total_miss;
    integer total_invalido;

    // ------------------------------------------------------------------
    // Timeout de seguranca (em ciclos)
    // ------------------------------------------------------------------
    integer ciclo_count;
    integer timeout_max;
    reg     timeout_ocorreu;

    // ------------------------------------------------------------------
    // Instanciacao do DUT
    // ------------------------------------------------------------------
    cache_unica dut (
        .clock(clock),
        .reset(reset),
        .addr_in(addr_in),
        .acesso_valido(acesso_valido),
        .SRRIP_ou_BRRIP(SRRIP_ou_BRRIP),
        .eh_hit(eh_hit),
        .miss(miss),
        .invalido(invalido),
        .via_vitima(via_vitima),
        .vitima_encontrada(vitima_encontrada),
        .insercao_rrpv(insercao_rrpv),
        .set_index(set_index),
        .tag_extraida(tag_extraida),
        .hit0(hit0),
        .hit1(hit1),
        .hit2(hit2),
        .hit3(hit3)
    );

    // ------------------------------------------------------------------
    // Geracao de clock
    // ------------------------------------------------------------------
    initial begin
        clock = 1'b0;
        forever #5 clock = ~clock;
    end

    // ------------------------------------------------------------------
    // Contador de ciclos e timeout de seguranca
    // ------------------------------------------------------------------
    always @(posedge clock) begin
        ciclo_count = ciclo_count + 1;
        if (timeout_max > 0 && ciclo_count >= timeout_max) begin
            timeout_ocorreu = 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // Task: aplicar_reset
    // ------------------------------------------------------------------
    task aplicar_reset;
        begin
            reset          = 1'b1;
            addr_in        = 14'd0;
            acesso_valido  = 1'b0;
            SRRIP_ou_BRRIP = 1'b0;
            @(posedge clock);
            #1;
            reset = 1'b0;
            #1;
        end
    endtask

    // ------------------------------------------------------------------
    // Task: iniciar_benchmark
    // ------------------------------------------------------------------
    task iniciar_benchmark;
        input [255*8-1:0] nome_bench;
        input [255*8-1:0] nome_politica;
        begin
            str_bench     = nome_bench;
            str_politica  = nome_politica;
            total_acessos = 0;
            total_hits    = 0;
            total_miss    = 0;
            total_invalido= 0;
            ciclo_count   = 0;
            timeout_max   = 100000;
            timeout_ocorreu = 1'b0;
            $display("==================================================");
            $display("Iniciando benchmark L1/cache unica: %0s", str_bench);
            $display("Politica de insercao: %0s", str_politica);
            $display("==================================================");
        end
    endtask

    // ------------------------------------------------------------------
    // Task: aplicar_acesso_endereco
    // Aplica um acesso de leitura a um endereco de 14 bits.
    // Mantem #1 apos posedge para estabilizar saidas.
    // ------------------------------------------------------------------
    task aplicar_acesso_endereco;
        input [13:0] endereco;
        begin
            @(posedge clock);
            #1;
            addr_in       = endereco;
            acesso_valido = 1'b1;
            @(posedge clock);
            #1;
            // Amostra as saidas estabilizadas
            total_acessos  = total_acessos + 1;
            if (eh_hit)     total_hits     = total_hits + 1;
            if (miss)       total_miss     = total_miss + 1;
            if (invalido)   total_invalido = total_invalido + 1;

            // Desativa acesso para evitar acesso fantasma
            acesso_valido = 1'b0;
            #1;
        end
    endtask

    // ------------------------------------------------------------------
    // Task: imprimir_relatorio
    // ------------------------------------------------------------------
    task imprimir_relatorio;
        begin
            $display("--------------------------------------------------");
            $display("Relatorio L1/cache unica");
            $display("Benchmark : %0s", str_bench);
            $display("Politica  : %0s", str_politica);
            $display("Acessos   : %0d", total_acessos);
            $display("Hits      : %0d", total_hits);
            $display("Miss      : %0d", total_miss);
            $display("Invalidos : %0d", total_invalido);
            if (total_acessos > 0) begin
                $display("Hit rate  : %0d%%", (total_hits * 100) / total_acessos);
                $display("Miss rate : %0d%%", (total_miss * 100) / total_acessos);
            end
            if (timeout_ocorreu) begin
                $display("AVISO: timeout de seguranca acionado.");
            end
            $display("--------------------------------------------------");
            $display("");
        end
    endtask

    // ------------------------------------------------------------------
    // Benchmark 1: working set com reuso
    // Mesmo conjunto (indice 0), tags 0..3, repeticoes.
    // ------------------------------------------------------------------
    task bench_working_set_reuso;
        integer t;
        integer r;
        begin
            iniciar_benchmark("1) working_set_reuso", str_politica);
            for (r = 0; r < 4; r = r + 1) begin
                for (t = 0; t < 4; t = t + 1) begin
                    aplicar_acesso_endereco({t[3:0], 5'd0, 5'd0});
                end
            end
            imprimir_relatorio;
        end
    endtask

    // ------------------------------------------------------------------
    // Benchmark 2: streaming sem reuso
    // Variando tags e conjuntos (acessos sequenciais distintos).
    // ------------------------------------------------------------------
    task bench_streaming_sem_reuso;
        integer t;
        integer s;
        begin
            iniciar_benchmark("2) streaming_sem_reuso", str_politica);
            for (t = 0; t < 8; t = t + 1) begin
                for (s = 0; s < 8; s = s + 1) begin
                    aplicar_acesso_endereco({t[3:0], s[4:0], 5'd0});
                end
            end
            imprimir_relatorio;
        end
    endtask

    // ------------------------------------------------------------------
    // Benchmark 3: hot/cold
    // Um endereco quente repetido e alguns frios.
    // ------------------------------------------------------------------
    task bench_hot_cold;
        integer i;
        begin
            iniciar_benchmark("3) hot_cold", str_politica);
            // Endereco quente: tag 1, indice 1, offset 0
            for (i = 0; i < 8; i = i + 1) begin
                aplicar_acesso_endereco({4'd1, 5'd1, 5'd0});
                // Acessos frios variados
                aplicar_acesso_endereco({4'd2, 5'd2, 5'd0});
                aplicar_acesso_endereco({4'd3, 5'd3, 5'd0});
                aplicar_acesso_endereco({4'd4, 5'd4, 5'd0});
            end
            imprimir_relatorio;
        end
    endtask

    // ------------------------------------------------------------------
    // Benchmark 4: conflito no mesmo conjunto
    // Tags 0..7 no mesmo conjunto (indice 0).
    // ------------------------------------------------------------------
    task bench_conflito_mesmo_conjunto;
        integer t;
        integer r;
        begin
            iniciar_benchmark("4) conflito_mesmo_conjunto", str_politica);
            for (r = 0; r < 2; r = r + 1) begin
                for (t = 0; t < 8; t = t + 1) begin
                    aplicar_acesso_endereco({t[3:0], 5'd0, 5'd0});
                end
            end
            imprimir_relatorio;
        end
    endtask

    // ------------------------------------------------------------------
    // Bloco principal: executa os 4 benchmarks nas 2 politicas
    // ------------------------------------------------------------------
    integer p;
    initial begin
        $display("##########################################################");
        $display("# tb_microbench - Testbench L1/cache unica (cache_unica) #");
        $display("# Executa 4 benchmarks em 2 politicas: SRRIP e BRRIP     #");
        $display("##########################################################");
        $display("");

        // Inicializacao segura
        clock          = 1'b0;
        reset          = 1'b0;
        addr_in        = 14'd0;
        acesso_valido  = 1'b0;
        SRRIP_ou_BRRIP = 1'b0;
        ciclo_count    = 0;
        timeout_max    = 0;
        timeout_ocorreu= 1'b0;
        str_politica   = "";
        str_bench      = "";

        // Reset inicial
        aplicar_reset;

        // Loop pelas duas politicas:
        //   p = 0 -> SRRIP (SRRIP_ou_BRRIP = 0)
        //   p = 1 -> BRRIP (SRRIP_ou_BRRIP = 1)
        for (p = 0; p < 2; p = p + 1) begin
            if (p == 0) begin
                SRRIP_ou_BRRIP = 1'b0;
                str_politica   = "SRRIP (SRRIP_ou_BRRIP=0)";
            end else begin
                SRRIP_ou_BRRIP = 1'b1;
                str_politica   = "BRRIP (SRRIP_ou_BRRIP=1)";
            end

            $display("");
            $display("##########################################################");
            $display("# Politica: %0s", str_politica);
            $display("##########################################################");

            // Reaplica reset entre politicas para estado limpo
            aplicar_reset;

            // Executa os 4 benchmarks
            bench_working_set_reuso;
            bench_streaming_sem_reuso;
            bench_hot_cold;
            bench_conflito_mesmo_conjunto;
        end

        $display("");
        $display("##########################################################");
        $display("# Fim do testbench L1/cache unica.                       #");
        $display("##########################################################");
        $finish;
    end

    // ------------------------------------------------------------------
    // Protecao adicional de timeout global
    // ------------------------------------------------------------------
    initial begin
        #10000000;
        $display("ERRO: timeout global do testbench acionado.");
        $finish;
    end

endmodule
