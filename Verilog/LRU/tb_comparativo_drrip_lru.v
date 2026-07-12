//================ ARQUIVO: tb_comparativo_rrip_lru.v ================
// Testbench PRINCIPAL comparativo: RRIP(SRRIP) vs RRIP(BRRIP) vs LRU.
// Um unico TB garante os mesmos acessos para todas as politicas.
`timescale 1ns/1ps
module tb_comparativo_drrip_lru;

  // ---- Sinais de estimulo (comuns as duas caches) ----
  reg         clock;
  reg         reset;
  reg  [13:0] addr_in;
  reg         acesso_valido;
  reg         SRRIP_ou_BRRIP;

  // ---- Saidas cache RRIP (cache_unica existente) ----
  wire        eh_hit_r, miss_r, invalido_r;
  wire [1:0]  via_vitima_r;
  wire        vitima_encontrada_r;
  wire [1:0]  insercao_rrpv_r;
  wire [4:0]  set_index_r;
  wire [3:0]  tag_extraida_r;
  wire        hit0_r, hit1_r, hit2_r, hit3_r;

  // ---- Saidas cache LRU ----
  wire        eh_hit_l, miss_l, invalido_l;
  wire [1:0]  via_vitima_l;
  wire        vitima_encontrada_l;
  wire [1:0]  insercao_rrpv_l;
  wire [4:0]  set_index_l;
  wire [3:0]  tag_extraida_l;
  wire        hit0_l, hit1_l, hit2_l, hit3_l;

  // ---- Instanciacao lado a lado ----
  cache_unica u_rrip(
    .clock(clock), .reset(reset),
    .addr_in(addr_in), .acesso_valido(acesso_valido),
    .SRRIP_ou_BRRIP(SRRIP_ou_BRRIP),
    .eh_hit(eh_hit_r), .miss(miss_r), .invalido(invalido_r),
    .via_vitima(via_vitima_r), .vitima_encontrada(vitima_encontrada_r),
    .insercao_rrpv(insercao_rrpv_r),
    .set_index(set_index_r), .tag_extraida(tag_extraida_r),
    .hit0(hit0_r), .hit1(hit1_r), .hit2(hit2_r), .hit3(hit3_r)
  );

  cache_unica u_lru(
    .clock(clock), .reset(reset),
    .addr_in(addr_in), .acesso_valido(acesso_valido),
    .SRRIP_ou_BRRIP(SRRIP_ou_BRRIP),
    .eh_hit(eh_hit_l), .miss(miss_l), .invalido(invalido_l),
    .via_vitima(via_vitima_l), .vitima_encontrada(vitima_encontrada_l),
    .insercao_rrpv(insercao_rrpv_l),
    .set_index(set_index_l), .tag_extraida(tag_extraida_l),
    .hit0(hit0_l), .hit1(hit1_l), .hit2(hit2_l), .hit3(hit3_l)
  );

  // ---- Contadores por benchmark ----
  integer total_acc  [0:3];
  integer hits_srrip [0:3];
  integer miss_srrip [0:3];
  integer hits_brrip [0:3];
  integer miss_brrip [0:3];
  integer hits_lru   [0:3];
  integer miss_lru   [0:3];

  integer cur_bench;
  integer phase;     // 0 = SRRIP, 1 = BRRIP, 2 = LRU
  integer k;

  // ---- Geracao de clock ----
  initial clock = 1'b0;
  always #5 clock = ~clock;

  // ---- Timeout global ----
  initial begin
    #2000000;
    $display("TIMEOUT GLOBAL - abortando simulacao.");
    $finish;
  end

  // ---- Task: reset entre cenarios ----
  task reset_caches;
  begin
    addr_in        = 14'b0;
    acesso_valido  = 1'b0;
    SRRIP_ou_BRRIP = 1'b0;
    reset          = 1'b1;
    @(posedge clock); #1;
    @(posedge clock); #1;
    reset          = 1'b0;
    @(posedge clock); #1;
  end
  endtask

  // ---- Task: acesso unico ----
  task do_access;
    input [13:0] a;
  begin
    @(negedge clock);
    addr_in       = a;
    acesso_valido = 1'b1;
    @(posedge clock);
    #1;
    // Conta total apenas uma vez (fase SRRIP), pois acessos sao identicos
    if (phase == 0)
      total_acc[cur_bench] = total_acc[cur_bench] + 1;
    // Conta hits/miss conforme a fase corrente
    if (phase == 0) begin
      if (eh_hit_r) hits_srrip[cur_bench] = hits_srrip[cur_bench] + 1;
      if (miss_r)   miss_srrip[cur_bench] = miss_srrip[cur_bench] + 1;
    end else if (phase == 1) begin
      if (eh_hit_r) hits_brrip[cur_bench] = hits_brrip[cur_bench] + 1;
      if (miss_r)   miss_brrip[cur_bench] = miss_brrip[cur_bench] + 1;
    end else begin
      if (eh_hit_l) hits_lru[cur_bench] = hits_lru[cur_bench] + 1;
      if (miss_l)   miss_lru[cur_bench] = miss_lru[cur_bench] + 1;
    end
    @(negedge clock);
    acesso_valido = 1'b0;
    addr_in       = 14'b0;
  end
  endtask

  // ---- Benchmark 1: working set com reuso ----
  task bench1;
    integer i, j;
  begin
    for (i = 0; i < 5; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        do_access(j * 32); // 8 blocos distintos, reusados 5x
      end
    end
  end
  endtask

  // ---- Benchmark 2: streaming sem reuso ----
  task bench2;
    integer j;
  begin
    for (j = 0; j < 64; j = j + 1) begin
      do_access(j * 32); // 64 blocos sequenciais, sem reuso
    end
  end
  endtask

  // ---- Benchmark 3: hot/cold ----
  task bench3;
    integer i;
  begin
    for (i = 0; i < 40; i = i + 1) begin
      do_access(14'd0);        // hot A
      do_access(14'd32);       // hot B
      if ((i % 4) == 0)
        do_access(64 + i * 32); // cold variavel
    end
  end
  endtask

  // ---- Benchmark 4: conflito no mesmo conjunto (set 0) ----
  task bench4;
    integer i;
  begin
    // 5 tags distintos mapeando ao set 0: 0,1024,2048,3072,4096
    for (i = 0; i < 6; i = i + 1) begin
      do_access(14'd0);
      do_access(14'd1024);
      do_access(14'd2048);
      do_access(14'd3072);
      do_access(14'd4096);
    end
  end
  endtask

  // ---- Relatorio comparativo ----
  task print_report;
    integer b;
    real hr_s, hr_b, hr_l;
  begin
    $display("============================================================");
    $display(" COMPARATIVO: RRIP(SRRIP) vs RRIP(BRRIP) vs LRU");
    $display("============================================================");
    for (b = 0; b < 4; b = b + 1) begin
      if (total_acc[b] > 0) begin
        hr_s = (100.0 * hits_srrip[b]) / total_acc[b];
        hr_b = (100.0 * hits_brrip[b]) / total_acc[b];
        hr_l = (100.0 * hits_lru[b])   / total_acc[b];
      end else begin
        hr_s = 0.0; hr_b = 0.0; hr_l = 0.0;
      end
      $display("---- Benchmark %0d ----", b);
      $display("  Total acessos : %0d", total_acc[b]);
      $display("  SRRIP : hits=%0d misses=%0d hitrate=%0.2f%%", hits_srrip[b], miss_srrip[b], hr_s);
      $display("  BRRIP : hits=%0d misses=%0d hitrate=%0.2f%%", hits_brrip[b], miss_brrip[b], hr_b);
      $display("  LRU   : hits=%0d misses=%0d hitrate=%0.2f%%", hits_lru[b],   miss_lru[b],   hr_l);
    end
    $display("============================================================");
  end
  endtask

  // ---- Fluxo principal ----
  initial begin
    // Inicializa contadores
    for (k = 0; k < 4; k = k + 1) begin
      total_acc[k]  = 0;
      hits_srrip[k] = 0; miss_srrip[k] = 0;
      hits_brrip[k] = 0; miss_brrip[k] = 0;
      hits_lru[k]   = 0; miss_lru[k]   = 0;
    end

    // ===== Etapa 1: RRIP com SRRIP =====
    phase = 0;
    SRRIP_ou_BRRIP = 1'b0;
    reset_caches;
    cur_bench = 0; bench1;
    cur_bench = 1; bench2;
    cur_bench = 2; bench3;
    cur_bench = 3; bench4;

    // ===== Etapa 2: RRIP com BRRIP =====
    phase = 1;
    SRRIP_ou_BRRIP = 1'b1;
    reset_caches;
    cur_bench = 0; bench1;
    cur_bench = 1; bench2;
    cur_bench = 2; bench3;
    cur_bench = 3; bench4;

    // ===== Etapa 3: LRU (SRRIP_ou_BRRIP irrelevante, mas dirigido igual) =====
    phase = 2;
    SRRIP_ou_BRRIP = 1'b0;
    reset_caches;
    cur_bench = 0; bench1;
    cur_bench = 1; bench2;
    cur_bench = 2; bench3;
    cur_bench = 3; bench4;

    // ===== Quadro comparativo final =====
    print_report;
    $finish;
  end

endmodule
