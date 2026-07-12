// ============================================================================
// tb_lru.v
// Testbench funcional para o controlador LRU.
// Este arquivo e destinado exclusivamente a simulacao (ModelSim) e nao deve
// ser sintetizado no Quartus. Os diretivos translate_off/translate_on
// garantem que o Quartus ignorara este modulo durante a sintese.
// ============================================================================
`timescale 1ns / 1ns
// synthesis translate_off

module tb_lru;

// --------------------------------------------------------------------------
// Sinais de estimulo e de monitoramento.
// --------------------------------------------------------------------------
reg clk;
reg rst;
reg access_valid;
reg access_is_hit;
reg [5:0] set_idx;
reg [3:0] valid_vec;
reg [1:0] hit_way;
reg refill_valid;

wire [1:0] victim_way;
wire       victim_found;
wire [1:0] insert_age;

// --------------------------------------------------------------------------
// Instanciacao do DUT (Device Under Test).
// --------------------------------------------------------------------------
lru uut (
    .clk           (clk),
    .rst           (rst),
    .access_valid  (access_valid),
    .access_is_hit (access_is_hit),
    .set_idx       (set_idx),
    .valid_vec     (valid_vec),
    .hit_way       (hit_way),
    .refill_valid  (refill_valid),
    .victim_way    (victim_way),
    .victim_found  (victim_found),
    .insert_age    (insert_age)
);

// --------------------------------------------------------------------------
// Gerador de clock: periodo de 10 ns (frequencia de 100 MHz).
// --------------------------------------------------------------------------
initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

// --------------------------------------------------------------------------
// Sequencia de estimulos.
// --------------------------------------------------------------------------
initial begin
    // Inicializa todos os estimulos para evitar valores indefinidos (X).
    rst          = 1'b1;
    access_valid = 1'b0;
    access_is_hit= 1'b0;
    set_idx      = 6'd0;
    valid_vec    = 4'b0000;
    hit_way      = 2'd0;
    refill_valid = 1'b0;

    // Gera arquivo de forma de onda para analise pos-simulacao.
    $dumpfile("tb_lru.vcd");
    $dumpvars(0, tb_lru);

    // Aplica reset por 20 ns.
    #20;
    rst = 1'b0;
    #10;

    // ------------------------------------------------------------------
    // Caso a) Refill com via invalida.
    // Todas as vias estao invalidas. A vitima deve ser a way0, pois e a
    // primeira via invalida encontrada na prioridade 0->1->2->3.
    // Apos o clock, a nova linha e inserida na way0 com idade 0.
    // ------------------------------------------------------------------
    $display("=== Caso a: Refill com via invalida ===");
    access_valid  = 1'b1;
    refill_valid  = 1'b1;
    access_is_hit = 1'b0;
    valid_vec     = 4'b0000;
    set_idx       = 6'd0;
    @(posedge clk);
    #1;
    $display("victim_way=%0d victim_found=%b insert_age=%0d", victim_way, victim_found, insert_age);

    // ------------------------------------------------------------------
    // Caso b) Hit em uma via.
    // Apos o caso a, espera-se: way0=0, way1=3, way2=3, way3=3.
    // O hit ocorre na way2. Apos o hit, a ordem esperada sera:
    // way0=1, way1=3, way2=0, way3=3.
    // ------------------------------------------------------------------
    $display("=== Caso b: Hit na way2 ===");
    access_valid  = 1'b1;
    access_is_hit = 1'b1;
    refill_valid  = 1'b0;
    valid_vec     = 4'b0001;      // apenas way0 valida no ponto de vista do valid_vec
    hit_way       = 2'd2;
    @(posedge clk);
    #1;
    $display("victim_way=%0d victim_found=%b insert_age=%0d", victim_way, victim_found, insert_age);

    // ------------------------------------------------------------------
    // Caso c) Refill com todas as vias validas.
    // Estado esperado antes do refill: way0=1, way1=3, way2=0, way3=3.
    // A vitima deve ser a way1 (primeira via com idade maxima 3).
    // Apos o refill: way0=2, way1=0, way2=1, way3=3.
    // ------------------------------------------------------------------
    $display("=== Caso c: Refill com todas validas (forca vitima por maior idade) ===");
    access_valid  = 1'b1;
    access_is_hit = 1'b0;
    refill_valid  = 1'b1;
    valid_vec     = 4'b1111;
    @(posedge clk);
    #1;
    $display("victim_way=%0d victim_found=%b insert_age=%0d", victim_way, victim_found, insert_age);

    // ------------------------------------------------------------------
    // Caso d) Multiplos hits para demonstrar ordenacao LRU.
    // Estado inicial: way0=2, way1=0, way2=1, way3=3.
    // - Hit way0: way0=0, way1=1, way2=2, way3=3.
    // - Hit way1: way0=1, way1=0, way2=2, way3=3.
    // - Hit way3: way0=2, way1=1, way2=3, way3=0.
    // Em seguida, refill: a vitima deve ser a way2 (idade maxima 3).
    // ------------------------------------------------------------------
    $display("=== Caso d: Multiplos hits e refill final ===");
    access_valid  = 1'b1;
    access_is_hit = 1'b1;
    refill_valid  = 1'b0;
    valid_vec     = 4'b1111;

    hit_way = 2'd0;
    @(posedge clk);
    #1;

    hit_way = 2'd1;
    @(posedge clk);
    #1;

    hit_way = 2'd3;
    @(posedge clk);
    #1;

    $display("Refill apos serie de hits:");
    access_is_hit = 1'b0;
    refill_valid  = 1'b1;
    @(posedge clk);
    #1;
    $display("victim_way=%0d victim_found=%b insert_age=%0d", victim_way, victim_found, insert_age);

    // Finaliza a simulacao.
    #50;
    $finish;
end

endmodule
// synthesis translate_on
