
//==============================================================================
// ARQUIVO 2: tb_microbench.v
//------------------------------------------------------------------------------
// Testbench de benchmark para a cache_unica.
//
// Filosofia:
//  - O testbench eh o gerador de acessos (nao ha processador nem memoria).
//  - Para cada politica (SRRIP e BRRIP) roda 4 microbenchmarks:
//      1) working set com reuso
//      2) streaming (sem reuso)
//      3) hot/cold
//      4) conflito no mesmo conjunto (forca substituicao)
//  - Ao final de cada benchmark imprime relatorio com total, hits, misses,
//    hit rate e miss rate.
//
// Estilo simples de Verilog, compativel com simuladores basicos e Quartus.
// Sem `timescale para evitar problemas com ferramentas que o reportam.
//==============================================================================
module tb_microbench;

    // -----------------------------------------------------------------------
    // Sinais do DUT (Device Under Test)
    // -----------------------------------------------------------------------
    reg         clock;
    reg         reset;
    reg  [7:0]  addr_in;
    reg         acesso_valido;
    reg         SRRIP_ou_BRRIP;   // 0 = SRRIP, 1 = BRRIP

    wire        eh_hit;
    wire        miss;
    wire        invalido;
    wire [1:0]  via_vitima;
    wire        vitima_encontrada;
    wire [1:0]  insercao_rrpv;
    wire [1:0]  set_index;
    wire [3:0]  tag_extraida;
    wire        hit0, hit1, hit2, hit3;

    // -----------------------------------------------------------------------
    // Instancia da L2 simplificada
    // -----------------------------------------------------------------------
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
        .hit0(hit0), .hit1(hit1), .hit2(hit2), .hit3(hit3)
    );

    // -----------------------------------------------------------------------
    // Geracao de clock: estilo simples do TB do usuario.
    // -----------------------------------------------------------------------
    initial clock = 1'b0;
    always #5 clock = ~clock;

    // -----------------------------------------------------------------------
    // Contadores de benchmark
    // -----------------------------------------------------------------------
    integer total_acessos;
    integer total_hits;
    integer total_misses;
    real    hit_rate;
    real    miss_rate;

    // Nome do benchmark corrente e politica corrente (para impressao)
    reg [255*8:0] nome_benchmark;
    reg [255*8:0] nome_politica;

    // -----------------------------------------------------------------------
    // Task: aplicar_reset
    // Mantem reset alto por alguns ciclos e depois libera.
    // -----------------------------------------------------------------------
    task aplicar_reset;
    begin
        reset = 1'b1;
        addr_in = 8'h00;
        acesso_valido = 1'b0;
        @(posedge clock); @(posedge clock); @(posedge clock);
        reset = 1'b0;
        @(posedge clock);
    end
    endtask

    // -----------------------------------------------------------------------
    // Task: iniciar_benchmark
    // Zera contadores e define o nome/politica para o relatorio.
    // -----------------------------------------------------------------------
    task iniciar_benchmark;
        input [255*8:0] nb;
        input [255*8:0] np;
    begin
        nome_benchmark = nb;
        nome_politica  = np;
        total_acessos  = 0;
        total_hits     = 0;
        total_misses   = 0;
        hit_rate       = 0.0;
        miss_rate      = 0.0;
    end
    endtask

    // -----------------------------------------------------------------------
    // Task: aplicar_acesso_endereco
    // Aplica UM acesso a um endereco de 8 bits, espera um ciclo de clock e
    // atualiza os contadores de hit/miss com base na saida do DUT.
    // -----------------------------------------------------------------------
    task aplicar_acesso_endereco;
        input [7:0] addr;
    begin
        addr_in = addr;
        acesso_valido = 1'b1;
        @(posedge clock);
        #1; // pequeno atraso para estabilizar saidas combinacionais

        total_acessos = total_acessos + 1;
        if (eh_hit) total_hits = total_hits + 1;
        if (miss)   total_misses = total_misses + 1;

        acesso_valido = 1'b0;
        @(posedge clock);
    end
    endtask

    // -----------------------------------------------------------------------
    // Task: imprimir_relatorio
    // Calcula hit_rate/miss_rate e imprime resumo do benchmark.
    // -----------------------------------------------------------------------
    task imprimir_relatorio;
    begin
        if (total_acessos > 0) begin
            hit_rate  = (total_hits * 100.0) / total_acessos;
            miss_rate = (total_misses * 100.0) / total_acessos;
        end else begin
            hit_rate  = 0.0;
            miss_rate = 0.0;
        end

        $display("------------------------------------------------------------");
        $display("BENCHMARK : %0s", nome_benchmark);
        $display("POLITICA  : %0s", nome_politica);
        $display("TOTAL     : %0d", total_acessos);
        $display("HITS      : %0d", total_hits);
        $display("MISSES    : %0d", total_misses);
        $display("HIT RATE  : %0.2f %%", hit_rate);
        $display("MISS RATE : %0.2f %%", miss_rate);
        $display("------------------------------------------------------------");
    end
    endtask

    // -----------------------------------------------------------------------
    // Microbenchmarks: procedimentos locais para manter o codigo legivel.
    // -----------------------------------------------------------------------

    // 1) Working set com reuso: enderecos que ocupam um conjunto e depois
    //    repetem varias vezes. Espera-se hit rate razoavel porque ha reuso.
    task bench_working_set;
    begin
        iniciar_benchmark("1) working_set_com_reuso", nome_politica);
        // Usa o conjunto 0 (idx=00). Tags 0..3 cabem nas 4 vias.
        aplicar_acesso_endereco(8'h00); // tag=0, idx=0, off=0
        aplicar_acesso_endereco(8'h10); // tag=1, idx=0
        aplicar_acesso_endereco(8'h20); // tag=2, idx=0
        aplicar_acesso_endereco(8'h30); // tag=3, idx=0
        // Repete a mesma sequencia: agora deve haver reuso (hits).
        aplicar_acesso_endereco(8'h00);
        aplicar_acesso_endereco(8'h10);
        aplicar_acesso_endereco(8'h20);
        aplicar_acesso_endereco(8'h30);
        aplicar_acesso_endereco(8'h00);
        aplicar_acesso_endereco(8'h10);
        aplicar_acesso_endereco(8'h20);
        aplicar_acesso_endereco(8'h30);
        imprimir_relatorio;
    end
    endtask

    // 2) Streaming: varios enderecos sem reuso. Espera-se muitos misses.
    task bench_streaming;
    integer t;
    begin
        iniciar_benchmark("2) streaming_sem_reuso", nome_politica);
 // Varia tags e indices para evitar reuso.
        for (t = 0; t < 16; t = t + 1) begin
            // addr = tag<<4 | idx<<2 ; aqui usamos t como tag e idx variando
            aplicar_acesso_endereco({t[3:0], t[1:0], 2'b00});
        end
        imprimir_relatorio;
    end
    endtask

    // 3) Hot/cold: um endereco quente acessado muitas vezes e outros frios
    //    acessados poucas vezes. O quente deve gerar muitos hits.
    task bench_hot_cold;
    integer i;
    begin
        iniciar_benchmark("3) hot_cold", nome_politica);
        // Endereco quente: tag=0, idx=0
        // Enderecos frios: tags 1..3 no mesmo conjunto, e alguns em outros
        aplicar_acesso_endereco(8'h00); // carrega quente
        for (i = 0; i < 8; i = i + 1) begin
            aplicar_acesso_endereco(8'h00); // acesso quente (espera hit)
            if (i == 2) aplicar_acesso_endereco(8'h10); // frio
            if (i == 4) aplicar_acesso_endereco(8'h20); // frio
            if (i == 6) aplicar_acesso_endereco(8'h40); // outro conjunto
        end
        imprimir_relatorio;
    end
    endtask

    // 4) Conflito no mesmo conjunto: varias tags no mesmo indice para forcar
    //    substituicao repetida. Espera-se miss rate alto.
    task bench_conflito;
    integer t;
    begin
        iniciar_benchmark("4) conflito_no_mesmo_conjunto", nome_politica);
        // Todas no conjunto 0 (idx=00), tags 0..7 (mais tags que vias).
        for (t = 0; t < 8; t = t + 1) begin
            aplicar_acesso_endereco({t[3:0], 2'b00, 2'b00});
        end
        // Segunda rodada: algumas tags podem ter sido substituidas.
        for (t = 0; t < 8; t = t + 1) begin
            aplicar_acesso_endereco({t[3:0], 2'b00, 2'b00});
        end
        imprimir_relatorio;
    end
    endtask

    // -----------------------------------------------------------------------
    // Bloco principal: roda todos os benchmarks em SRRIP e depois em BRRIP.
    // -----------------------------------------------------------------------
    integer k;
    initial begin
        $display("============================================================");
        $display("INICIO DO BENCHMARK DA L2 SIMPLIFICADA (4 conjuntos DRRIP)");
        $display("============================================================");

        // ---- Politica SRRIP (SRRIP_ou_BRRIP = 0) ----
        SRRIP_ou_BRRIP = 1'b0;
        nome_politica  = "SRRIP";

        aplicar_reset;
        bench_working_set;
        aplicar_reset;
        bench_streaming;
        aplicar_reset;
        bench_hot_cold;
        aplicar_reset;
        bench_conflito;

        // ---- Politica BRRIP (SRRIP_ou_BRRIP = 1) ----
        SRRIP_ou_BRRIP = 1'b1;
        nome_politica  = "BRRIP";

        aplicar_reset;
        bench_working_set;
        aplicar_reset;
        bench_streaming;
        aplicar_reset;
        bench_hot_cold;
        aplicar_reset;
        bench_conflito;

        $display("============================================================");
        $display("FIM DO BENCHMARK DA L2 SIMPLIFICADA");
        $display("============================================================");
        $finish;
    end

    // Protecao contra simulacao infinita (caso alguma ferramenta nao respeite
    // o $finish prontamente).
    initial begin
        #100000;
        $display("TIMEOUT: simulacao encerrada por tempo.");
        $finish;
    end

endmodule
