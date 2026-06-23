// ============================================================================
// lru.v
// Controlador exato de substituicao LRU (Least Recently Used) para cache
// 4-way set-associativo.
// - 64 conjuntos (SETS = 64)
// - 4 vias (WAYS = 4)
// - 2 bits de idade por via (AGE_BITS = 2)
//     00 = via mais recentemente usada (MRU)
//     11 = via menos recentemente usada (LRU), candidata natural a vitima
// Compativel com Verilog-2001, Quartus Prime e ModelSim.
// As saidas sao puramente combinacionais (assigns) e as memorias de idade
// sao atualizadas por um unico bloco sequencial, evitando multiplos drivers.
// ============================================================================
`timescale 1ns / 1ns

module lru #(
    parameter SETS         = 64,
    parameter WAYS         = 4,
    parameter AGE_BITS     = 2,
    parameter SET_IDX_BITS = 6,  // log2(SETS) = 6
    parameter WAY_IDX_BITS = 2   // log2(WAYS) = 2
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  access_valid,
    input  wire                  access_is_hit,
    input  wire [SET_IDX_BITS-1:0] set_idx,
    input  wire [WAYS-1:0]       valid_vec,
    input  wire [WAY_IDX_BITS-1:0] hit_way,
    input  wire                  refill_valid,
    output wire [WAY_IDX_BITS-1:0] victim_way,
    output wire                  victim_found,
    output wire [AGE_BITS-1:0]   insert_age
);

// --------------------------------------------------------------------------
// Bancos de memoria de idade: um array independente por via.
// Cada array possui 64 posicoes de 2 bits, totalizando 4 * 64 * 2 = 512 bits.
// A leitura e feita de forma puramente combinacional atraves de assign.
// --------------------------------------------------------------------------
reg [AGE_BITS-1:0] age_way0_mem [0:SETS-1];
reg [AGE_BITS-1:0] age_way1_mem [0:SETS-1];
reg [AGE_BITS-1:0] age_way2_mem [0:SETS-1];
reg [AGE_BITS-1:0] age_way3_mem [0:SETS-1];

wire [AGE_BITS-1:0] age0;
wire [AGE_BITS-1:0] age1;
wire [AGE_BITS-1:0] age2;
wire [AGE_BITS-1:0] age3;

assign age0 = age_way0_mem[set_idx];
assign age1 = age_way1_mem[set_idx];
assign age2 = age_way2_mem[set_idx];
assign age3 = age_way3_mem[set_idx];

// --------------------------------------------------------------------------
// Logica combinacional de selecao da vitima.
// --------------------------------------------------------------------------
// Maior idade entre as quatro vias. Quando todas as vias sao validas, a
// primeira via que apresentar essa idade maxima sera escolhida como vitima.
wire [AGE_BITS-1:0] max_age_pair_01;
wire [AGE_BITS-1:0] max_age_pair_23;
wire [AGE_BITS-1:0] max_age;

assign max_age_pair_01 = (age0 > age1) ? age0 : age1;
assign max_age_pair_23 = (age2 > age3) ? age2 : age3;
assign max_age         = (max_age_pair_01 > max_age_pair_23) ? max_age_pair_01 : max_age_pair_23;

// Indica se existe ao menos uma via invalida no conjunto enderecado.
// ~&(valid_vec[3:0]) e equivalente a NOT(AND(valid_vec[3:0])).
wire has_invalid;
assign has_invalid = ~&valid_vec;

// Seleciona a primeira via invalida, obedecendo a prioridade
// way0 -> way1 -> way2 -> way3. Quando todas sao validas, o valor gerado
// sera 3, mas sera ignorado gracas a sinal has_invalid.
wire [WAY_IDX_BITS-1:0] invalid_sel;
assign invalid_sel = valid_vec[0] ? (valid_vec[1] ? (valid_vec[2] ? 2'd3 : 2'd2) : 2'd1) : 2'd0;

// Vitima combinacional: se houver via invalida, escolhe a primeira invalida;
// caso contrario, escolhe a via valida com maior idade, preferindo a primeira
// em caso de empate (way0, depois way1, depois way2, depois way3).
wire [WAY_IDX_BITS-1:0] victim_way_c;
assign victim_way_c = has_invalid ? invalid_sel :
                      (age0 == max_age) ? 2'd0 :
                      (age1 == max_age) ? 2'd1 :
                      (age2 == max_age) ? 2'd2 : 2'd3;

// Saidas combinacionais finais.
// victim_found indica que um refill esta sendo solicitado.
// insert_age informa a idade que a nova linha deve receber ao ser inserida
// (no LRU exato, toda nova linha entra como MRU, ou seja, idade 0).
assign victim_way   = victim_way_c;
assign victim_found = refill_valid;
assign insert_age   = 2'b00;

// --------------------------------------------------------------------------
// Logica sequencial de atualizacao das idades.
// - Reset: inicializa todas as idades de todas as vias e todos os conjuntos
//          com 3 (menos recentemente usada).
// - Hit: a via acessada (hit_way) passa a idade 0; as vias cuja idade atual
//        seja menor que old_age (idade da via que sofreu hit) sao
//        envelhecidas em 1, saturando no maximo 3.
// - Refill (miss): a via vitima recebe idade 0; todas as demais vias sao
//                  envelhecidas em 1, saturando em 3.
// --------------------------------------------------------------------------
integer i;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        // Reset assincrono: todas as posicoes de todos os bancos recebem 3.
        // O laco e sintetizavel porque SETS e uma constante conhecida em
        // tempo de compilacao e relativamente pequena (64).
        for (i = 0; i < SETS; i = i + 1) begin
            age_way0_mem[i] <= 2'd3;
            age_way1_mem[i] <= 2'd3;
            age_way2_mem[i] <= 2'd3;
            age_way3_mem[i] <= 2'd3;
        end
    end
    else begin
        // A atualizacao das idades so ocorre quando access_valid esta ativo.
        if (access_valid) begin
            if (access_is_hit) begin
                // ----------------------------------------------------------
                // CASO HIT: preserva a ordenacao LRU exata.
                // old_age e a idade da via acessada *antes* da atualizacao.
                // Vias com idade inferior a old_age devem "descer" uma
                // posicao na fila de prioridade (aumentar idade em 1).
                // A via do hit vai diretamente para 0 (MRU).
                // ----------------------------------------------------------
                case (hit_way)
                    2'd0: begin
                        age_way0_mem[set_idx] <= 2'd0;
                        age_way1_mem[set_idx] <= (age1 < age0) ? ((age1 == 2'd3) ? 2'd3 : age1 + 1) : age1;
                        age_way2_mem[set_idx] <= (age2 < age0) ? ((age2 == 2'd3) ? 2'd3 : age2 + 1) : age2;
                        age_way3_mem[set_idx] <= (age3 < age0) ? ((age3 == 2'd3) ? 2'd3 : age3 + 1) : age3;
                    end
                    2'd1: begin
                        age_way1_mem[set_idx] <= 2'd0;
                        age_way0_mem[set_idx] <= (age0 < age1) ? ((age0 == 2'd3) ? 2'd3 : age0 + 1) : age0;
                        age_way2_mem[set_idx] <= (age2 < age1) ? ((age2 == 2'd3) ? 2'd3 : age2 + 1) : age2;
                        age_way3_mem[set_idx] <= (age3 < age1) ? ((age3 == 2'd3) ? 2'd3 : age3 + 1) : age3;
                    end
                    2'd2: begin
                        age_way2_mem[set_idx] <= 2'd0;
                        age_way0_mem[set_idx] <= (age0 < age2) ? ((age0 == 2'd3) ? 2'd3 : age0 + 1) : age0;
                        age_way1_mem[set_idx] <= (age1 < age2) ? ((age1 == 2'd3) ? 2'd3 : age1 + 1) : age1;
                        age_way3_mem[set_idx] <= (age3 < age2) ? ((age3 == 2'd3) ? 2'd3 : age3 + 1) : age3;
                    end
                    2'd3: begin
                        age_way3_mem[set_idx] <= 2'd0;
                        age_way0_mem[set_idx] <= (age0 < age3) ? ((age0 == 2'd3) ? 2'd3 : age0 + 1) : age0;
                        age_way1_mem[set_idx] <= (age1 < age3) ? ((age1 == 2'd3) ? 2'd3 : age1 + 1) : age1;
                        age_way2_mem[set_idx] <= (age2 < age3) ? ((age2 == 2'd3) ? 2'd3 : age2 + 1) : age2;
                    end
                    default: begin
                        // Padrao de seguranca: nao modifica memorias.
                    end
                endcase
            end
            else if (refill_valid) begin
                // ----------------------------------------------------------
                // CASO REFILL (miss): substitui a vitima e envelhece todas
                // as demais vias em 1, saturando a idade em 3.
                // ----------------------------------------------------------
                case (victim_way_c)
                    2'd0: begin
                        age_way0_mem[set_idx] <= 2'd0;
                        age_way1_mem[set_idx] <= (age1 == 2'd3) ? 2'd3 : age1 + 1;
                        age_way2_mem[set_idx] <= (age2 == 2'd3) ? 2'd3 : age2 + 1;
                        age_way3_mem[set_idx] <= (age3 == 2'd3) ? 2'd3 : age3 + 1;
                    end
                    2'd1: begin
                        age_way1_mem[set_idx] <= 2'd0;
                        age_way0_mem[set_idx] <= (age0 == 2'd3) ? 2'd3 : age0 + 1;
                        age_way2_mem[set_idx] <= (age2 == 2'd3) ? 2'd3 : age2 + 1;
                        age_way3_mem[set_idx] <= (age3 == 2'd3) ? 2'd3 : age3 + 1;
                    end
                    2'd2: begin
                        age_way2_mem[set_idx] <= 2'd0;
                        age_way0_mem[set_idx] <= (age0 == 2'd3) ? 2'd3 : age0 + 1;
                        age_way1_mem[set_idx] <= (age1 == 2'd3) ? 2'd3 : age1 + 1;
                        age_way3_mem[set_idx] <= (age3 == 2'd3) ? 2'd3 : age3 + 1;
                    end
                    2'd3: begin
                        age_way3_mem[set_idx] <= 2'd0;
                        age_way0_mem[set_idx] <= (age0 == 2'd3) ? 2'd3 : age0 + 1;
                        age_way1_mem[set_idx] <= (age1 == 2'd3) ? 2'd3 : age1 + 1;
                        age_way2_mem[set_idx] <= (age2 == 2'd3) ? 2'd3 : age2 + 1;
                    end
                    default: begin
                        // Padrao de seguranca: nao modifica memorias.
                    end
                endcase
            end
        end
    end
end

endmodule

