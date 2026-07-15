// cache_drrip.v
// Modelo de cache de 4 KB, 4 vias e blocos de 32 bytes.
//
// Implementa DRRIP com:
// - SRRIP;
// - BRRIP;
// - conjuntos lideres;
// - conjuntos seguidores;
// - contador PSEL.
//
// Organizacao:
// 32 conjuntos x 4 vias x 32 bytes = 4096 bytes.
//
// Endereco de 32 bits:
// [4:0]   = offset
// [9:5]   = indice
// [31:10] = tag
//
// Conjuntos lideres:
// 0 e 1 = SRRIP
// 2 e 3 = BRRIP
// 4 ate 31 = seguidores

module cache_drrip (
    input  wire        clock,
    input  wire        reset,
    input  wire [31:0] addr_in,
    input  wire        acesso_valido,

    output wire        eh_hit,
    output wire        miss,
    output wire [1:0]  via_vitima,
    output wire        vitima_encontrada,
    output wire [1:0]  rrpv_insercao_usado,
    output wire        politica_brrip_usada,
    output wire [5:0]  psel_atual,
    output wire [4:0]  set_index,
    output wire [21:0] tag_extraida
);

    wire [4:0]  index;
    wire [21:0] tag;

    wire lider_srrip;
    wire lider_brrip;
    wire politica_brrip;

    // Contador que escolhe entre SRRIP e BRRIP.
    reg [5:0] psel;

    // Contador usado para a insercao bimodal do BRRIP.
    reg [4:0] contador_brrip;

    wire [31:0] acesso_set;
    wire [31:0] hit_set;
    wire [31:0] miss_set;
    wire [31:0] invalida_set;
    wire [31:0] vitima_encontrada_set;

    // Cada conjunto produz uma via de 2 bits.
    // 32 conjuntos x 2 bits = 64 bits.
    wire [63:0] via_vitima_set;

    wire [31:0] hit0_set;
    wire [31:0] hit1_set;
    wire [31:0] hit2_set;
    wire [31:0] hit3_set;

    // Separacao do endereco.
    assign index = addr_in[9:5];
    assign tag   = addr_in[31:10];

    assign set_index    = index;
    assign tag_extraida = tag;

    // --------------------------------------------------------------
    // Identificacao dos conjuntos lideres
    // --------------------------------------------------------------

    assign lider_srrip =
        (index == 5'd0) ||
        (index == 5'd1);

    assign lider_brrip =
        (index == 5'd2) ||
        (index == 5'd3);

    // Conjunto lider BRRIP sempre usa BRRIP.
    // Conjunto lider SRRIP sempre usa SRRIP.
    // Seguidores consultam o PSEL.
    assign politica_brrip =
        lider_brrip ? 1'b1 :
        lider_srrip ? 1'b0 :
                      psel[5];

    assign politica_brrip_usada = politica_brrip;
    assign psel_atual            = psel;

    // --------------------------------------------------------------
    // Valor de insercao
    //
    // SRRIP:
    // sempre insere com RRPV = 2.
    //
    // BRRIP:
    // normalmente insere com RRPV = 3;
    // uma vez a cada 32 insercoes usa RRPV = 2.
    // --------------------------------------------------------------

    assign rrpv_insercao_usado =
        !politica_brrip ? 2'd2 :
        (contador_brrip == 5'd0) ? 2'd2 :
                                   2'd3;

    // --------------------------------------------------------------
    // Cria os 32 conjuntos da cache
    // --------------------------------------------------------------

    genvar i;

    generate
        for (i = 0; i < 32; i = i + 1) begin
            assign acesso_set[i] =
                acesso_valido && (index == i);

            drrip_set conjunto (
                .clock(clock),
                .reset(reset),
                .tag_in(tag),
                .acesso_valido(acesso_set[i]),
                .rrpv_insercao(rrpv_insercao_usado),

                .eh_hit(hit_set[i]),
                .miss(miss_set[i]),
                .possui_invalida(invalida_set[i]),

                .via_vitima(
                    via_vitima_set[(2*i) +: 2]
                ),

                .vitima_encontrada(
                    vitima_encontrada_set[i]
                ),

                .hit0(hit0_set[i]),
                .hit1(hit1_set[i]),
                .hit2(hit2_set[i]),
                .hit3(hit3_set[i])
            );
        end
    endgenerate

    // Seleciona as saidas do conjunto acessado.
    assign eh_hit = hit_set[index];
    assign miss   = miss_set[index];

    assign via_vitima =
        via_vitima_set[(2*index) +: 2];

    assign vitima_encontrada =
        vitima_encontrada_set[index];

    // --------------------------------------------------------------
    // Atualizacao do PSEL e do contador BRRIP
    // --------------------------------------------------------------

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            // Comeca quase no centro, favorecendo SRRIP.
            psel <= 6'd31;

            // A primeira insercao BRRIP usara RRPV = 2.
            contador_brrip <= 5'd0;
        end
        else if (acesso_valido && miss) begin

            // Miss no lider SRRIP:
            // aumenta PSEL em direcao ao BRRIP.
            if (lider_srrip && (psel != 6'd63))
                psel <= psel + 1'b1;

            // Miss no lider BRRIP:
            // diminui PSEL em direcao ao SRRIP.
            if (lider_brrip && (psel != 6'd0))
                psel <= psel - 1'b1;

            // Avanca somente quando uma insercao BRRIP ocorre.
            if (politica_brrip)
                contador_brrip <=
                    contador_brrip + 1'b1;
        end
    end

endmodule