// top_lru.v
// Modulo principal usado apenas para sintetizar o LRU no Quartus.
//
// A interface e igual a do top_drrip para deixar
// a comparacao entre os algoritmos mais justa.

module top_lru (
    input  wire        clock,
    input  wire        reset,
    input  wire [31:0] addr_in,
    input  wire        acesso_valido,

    output wire        eh_hit,
    output wire        miss,
    output wire [1:0]  via_vitima,
    output wire        vitima_encontrada
);

    wire [4:0]  set_index;
    wire [21:0] tag_extraida;

    cache_lru cache (
        .clock(clock),
        .reset(reset),
        .addr_in(addr_in),
        .acesso_valido(acesso_valido),

        .eh_hit(eh_hit),
        .miss(miss),
        .via_vitima(via_vitima),
        .vitima_encontrada(vitima_encontrada),

        .set_index(set_index),
        .tag_extraida(tag_extraida)
    );

endmodule