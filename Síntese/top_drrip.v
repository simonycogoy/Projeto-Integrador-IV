// top_drrip.v
// Modulo principal usado apenas para sintetizar o DRRIP no Quartus.
//
// Ele possui somente as entradas e saidas importantes.
// As saidas de depuracao do cache_drrip ficam desconectadas.

module top_drrip (
    input  wire        clock,
    input  wire        reset,
    input  wire [31:0] addr_in,
    input  wire        acesso_valido,

    output wire        eh_hit,
    output wire        miss,
    output wire [1:0]  via_vitima,
    output wire        vitima_encontrada
);

    // Sinais internos que nao serao enviados para os pinos.
    wire [1:0]  rrpv_insercao;
    wire        politica_brrip;
    wire [5:0]  psel;
    wire [4:0]  set_index;
    wire [21:0] tag_extraida;

    cache_drrip cache (
        .clock(clock),
        .reset(reset),
        .addr_in(addr_in),
        .acesso_valido(acesso_valido),

        .eh_hit(eh_hit),
        .miss(miss),
        .via_vitima(via_vitima),
        .vitima_encontrada(vitima_encontrada),

        .rrpv_insercao_usado(rrpv_insercao),
        .politica_brrip_usada(politica_brrip),
        .psel_atual(psel),
        .set_index(set_index),
        .tag_extraida(tag_extraida)
    );

endmodule