// cache_lru.v
// Cache de referencia usando LRU.
//
// Mesma organizacao da cache DRRIP:
// - 4 KB;
// - 4 vias;
// - 32 conjuntos;
// - blocos de 32 bytes.

module cache_lru (
    input  wire        clock,
    input  wire        reset,
    input  wire [31:0] addr_in,
    input  wire        acesso_valido,

    output wire        eh_hit,
    output wire        miss,
    output wire [1:0]  via_vitima,
    output wire        vitima_encontrada,
    output wire [4:0]  set_index,
    output wire [21:0] tag_extraida
);

    wire [4:0]  index;
    wire [21:0] tag;

    wire [31:0] acesso_set;
    wire [31:0] hit_set;
    wire [31:0] miss_set;
    wire [31:0] invalida_set;
    wire [31:0] vitima_encontrada_set;

    wire [63:0] via_vitima_set;

    assign index = addr_in[9:5];
    assign tag   = addr_in[31:10];

    assign set_index    = index;
    assign tag_extraida = tag;

    genvar i;

    generate
        for (i = 0; i < 32; i = i + 1) begin
            assign acesso_set[i] =
                acesso_valido && (index == i);

            lru_set conjunto (
                .clock(clock),
                .reset(reset),
                .tag_in(tag),
                .acesso_valido(acesso_set[i]),

                .eh_hit(hit_set[i]),
                .miss(miss_set[i]),

                .possui_invalida(
                    invalida_set[i]
                ),

                .via_vitima(
                    via_vitima_set[(2*i) +: 2]
                ),

                .vitima_encontrada(
                    vitima_encontrada_set[i]
                )
            );
        end
    endgenerate

    assign eh_hit = hit_set[index];
    assign miss   = miss_set[index];

    assign via_vitima =
        via_vitima_set[(2*index) +: 2];

    assign vitima_encontrada =
        vitima_encontrada_set[index];

endmodule