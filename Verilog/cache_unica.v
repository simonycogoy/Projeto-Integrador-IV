// cache_unica.v
// Versao final correta da cache L1 unificada com politica DRRIP.
//
// Organizacao da cache L1:
//   - Capacidade total : 4 KB (4096 bytes)
//   - Bytes por bloco  : 32 B  -> offset de 5 bits
//   - Numero de vias   : 4
//   - Numero de conjuntos : 32 -> indice de 5 bits
//   - Tag              : 14 - 5 - 5 = 4 bits
//
// Decomposicao do endereco addr_in[13:0]:
//   [4:0]   -> offset  (5 bits) - existe apenas na decomposicao; ignorado pelo modelo abstrato
//   [9:5]   -> indice do conjunto (5 bits)
//   [13:10] -> tag (4 bits)
//
// Compatibilidade Quartus 13 / ModelSim antigos:
//   - Nao usa arrays unpacked (wire [1:0] x [0:N]).
//   - Sinais de 1 bit por conjunto  -> vetor empacotado de 32 bits.
//   - Sinais de 2 bits por conjunto -> vetor empacotado de 64 bits.
//   - Selecao por conjunto via indexed part-select: [(2*index)+:2].
//   - 32 instancias de drrip_logisim criadas via generate.

module cache_unica (
    input  wire        clock,
    input  wire        reset,
    input  wire [13:0] addr_in,
    input  wire        acesso_valido,
    input  wire        SRRIP_ou_BRRIP,
    output wire        eh_hit,
    output wire        miss,
    output wire        invalido,
    output wire [1:0]  via_vitima,
    output wire        vitima_encontrada,
    output wire [1:0]  insercao_rrpv,
    output wire [4:0]  set_index,
    output wire [3:0]  tag_extraida,
    output wire        hit0,
    output wire        hit1,
    output wire        hit2,
    output wire        hit3
);

    // ----------------------------------------------------------------------
    // Decomposicao do endereco
    // ----------------------------------------------------------------------
    wire [4:0] offset_interno; // existe apenas para documentar; ignorado pelo modelo abstrato
    wire [4:0] index;          // indice do conjunto (5 bits -> 32 conjuntos)
    wire [3:0] tag;            // tag (4 bits)

    assign offset_interno = addr_in[4:0];    // 5 bits de offset (32 B por bloco)
    assign index          = addr_in[9:5];    // 5 bits de indice (32 conjuntos)
    assign tag            = addr_in[13:10];  // 4 bits de tag

    assign set_index    = index;
    assign tag_extraida = tag;

    // ----------------------------------------------------------------------
    // Vetores empacotados para saidas de cada conjunto (32 conjuntos)
    // Sinais de 1 bit por conjunto  -> 32 bits
    // Sinais de 2 bits por conjunto -> 64 bits (32 * 2)
    // ----------------------------------------------------------------------
    wire [31:0] eh_hit_set;
    wire [31:0] miss_set;
    wire [31:0] invalido_set;
    wire [31:0] vitima_encontrada_set;
    wire [31:0] hit0_set;
    wire [31:0] hit1_set;
    wire [31:0] hit2_set;
    wire [31:0] hit3_set;

    wire [63:0] via_vitima_set;     // 32 conjuntos x 2 bits
    wire [63:0] insercao_rrpv_set;  // 32 conjuntos x 2 bits

    // Sinal de acesso valido por conjunto (apenas o conjunto selecionado e ativado)
    wire [31:0] acesso_valido_set;

    // ----------------------------------------------------------------------
    // Instanciacao de 32 modulos drrip_logisim (um por conjunto)
    // ----------------------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : gen_set
            // Ativa apenas o modulo correspondente ao conjunto do acesso atual
            assign acesso_valido_set[i] = acesso_valido && (index == i[4:0]);

            drrip_logisim u_drrip (
                .clock(clock),
                .reset(reset),
                .tag_in(tag),
                .acesso_valido(acesso_valido_set[i]),
                .SRRIP_ou_BRRIP(SRRIP_ou_BRRIP),
                .eh_hit(eh_hit_set[i]),
                .miss(miss_set[i]),
                .invalido(invalido_set[i]),
                .via_vitima(via_vitima_set[(2*i) +: 2]),
                .vitima_encontrada(vitima_encontrada_set[i]),
                .insercao_rrpv(insercao_rrpv_set[(2*i) +: 2]),
                .hit0(hit0_set[i]),
                .hit1(hit1_set[i]),
                .hit2(hit2_set[i]),
                .hit3(hit3_set[i])
            );
        end
    endgenerate

    // ----------------------------------------------------------------------
    // Selecao das saidas globais: somente o conjunto do acesso atual
    // Usa indexed part-select para os sinais de 2 bits: [(2*index)+:2]
    // ----------------------------------------------------------------------
    assign eh_hit            = eh_hit_set[index];
    assign miss              = miss_set[index];
    assign invalido          = invalido_set[index];
    assign vitima_encontrada = vitima_encontrada_set[index];
    assign via_vitima        = via_vitima_set[(2*index) +: 2];
    assign insercao_rrpv     = insercao_rrpv_set[(2*index) +: 2];
    assign hit0              = hit0_set[index];
    assign hit1              = hit1_set[index];
    assign hit2              = hit2_set[index];
    assign hit3              = hit3_set[index];

endmodule
