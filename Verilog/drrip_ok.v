// drrip.v
// Módulo top-level DRRIP (Dynamic Re-Reference Interval Prediction)
// Verilog-2001 puro, compatível com Quartus e ModelSim.
// 64 conjuntos, 4 ways, RRPV de 2 bits por way.

module drrip (
    input  wire       clk,
    input  wire       rst,
    input  wire       access_valid,
    input  wire       access_is_hit,
    input  wire [5:0] set_idx,
    input  wire [3:0] valid_vec,
    input  wire [1:0] hit_way,
    input  wire       refill_valid,
    output wire [1:0] victim_way,
    output wire       victim_found,
    output wire [1:0] insert_rrpv,
    output wire       psel_msb_policy
);

    // -----------------------------------------------------------------
    // Memórias RRPV separadas por way (uma dimensão, 64 posições).
    // -----------------------------------------------------------------
    reg [1:0] rrpv_way0_mem [0:63];
    reg [1:0] rrpv_way1_mem [0:63];
    reg [1:0] rrpv_way2_mem [0:63];
    reg [1:0] rrpv_way3_mem [0:63];

    // -----------------------------------------------------------------
    // Estado do PSEL (saturado de 4 bits) e contador BRRIP de 3 bits.
    // -----------------------------------------------------------------
    reg [3:0] psel;
    reg [2:0] brrip_counter;

    // -----------------------------------------------------------------
    // Sinais combinacionais internos para evitar múltiplos drivers.
    // -----------------------------------------------------------------
    wire [1:0] rrpv0, rrpv1, rrpv2, rrpv3;
    wire [1:0] victim_way_c;
    wire       victim_found_c;
    wire [1:0] insert_rrpv_c;
    wire [1:0] write_rrpv0, write_rrpv1, write_rrpv2, write_rrpv3;
    wire [1:0] max_rrpv;
    wire [1:0] delta;
    wire [1:0] aged0, aged1, aged2, aged3;
    wire [1:0] rr0, rr1, rr2, rr3; // rrpv após aging
    wire       policy_brrip; // 1 = BRRIP, 0 = SRRIP
    wire [1:0] invalid_sel;
    wire       has_invalid;
    wire [1:0] rr11_sel;
    wire       has_rr11;

    // -----------------------------------------------------------------
    // Leitura combinacional das memórias RRPV no set atual.
    // -----------------------------------------------------------------
    assign rrpv0 = rrpv_way0_mem[set_idx];
    assign rrpv1 = rrpv_way1_mem[set_idx];
    assign rrpv2 = rrpv_way2_mem[set_idx];
    assign rrpv3 = rrpv_way3_mem[set_idx];

    // -----------------------------------------------------------------
    // Política: líderes fixos em set_idx[1:0] == 00 ou 11; followers por psel[3].
    // -----------------------------------------------------------------
    assign policy_brrip = (set_idx[1:0] == 2'b00) ? 1'b0 :
                          (set_idx[1:0] == 2'b11) ? 1'b1 :
                                                     psel[3];

    assign psel_msb_policy = psel[3];

    // -----------------------------------------------------------------
    // Seleção da primeira way inválida.
    // -----------------------------------------------------------------
    assign invalid_sel = valid_vec[0] ? 2'd1 :
                         valid_vec[1] ? 2'd2 :
                         valid_vec[2] ? 2'd3 :
                         valid_vec[3] ? 2'd0 : 2'd0;
    assign has_invalid = ~(valid_vec[0] & valid_vec[1] & valid_vec[2] & valid_vec[3]);

    // -----------------------------------------------------------------
    // Seleção da primeira way com RRPV = 2'b11 (antes do aging).
    // -----------------------------------------------------------------
    assign rr11_sel = (rrpv0 == 2'b11) ? 2'd0 :
                      (rrpv1 == 2'b11) ? 2'd1 :
                      (rrpv2 == 2'b11) ? 2'd2 :
                      (rrpv3 == 2'b11) ? 2'd3 : 2'd0;
    assign has_rr11 = (rrpv0 == 2'b11) || (rrpv1 == 2'b11) ||
                      (rrpv2 == 2'b11) || (rrpv3 == 2'b11);

    // -----------------------------------------------------------------
    // Cálculo do max_rrpv entre as 4 ways e do delta para aging.
    // -----------------------------------------------------------------
    assign max_rrpv = (rrpv0 >= rrpv1 && rrpv0 >= rrpv2 && rrpv0 >= rrpv3) ? rrpv0 :
                      (rrpv1 >= rrpv2 && rrpv1 >= rrpv3) ? rrpv1 :
                      (rrpv2 >= rrpv3) ? rrpv2 : rrpv3;

    assign delta = 2'b11 - max_rrpv;

    // Aging saturado: min(rrpv + delta, 2'b11).
    assign aged0 = (rrpv0 + delta >= 2'b11) ? 2'b11 : (rrpv0 + delta);
    assign aged1 = (rrpv1 + delta >= 2'b11) ? 2'b11 : (rrpv1 + delta);
    assign aged2 = (rrpv2 + delta >= 2'b11) ? 2'b11 : (rrpv2 + delta);
    assign aged3 = (rrpv3 + delta >= 2'b11) ? 2'b11 : (rrpv3 + delta);

    // rrpv resultante após aging (usado para escolher vítima após aging).
    assign rr0 = aged0;
    assign rr1 = aged1;
    assign rr2 = aged2;
    assign rr3 = aged3;

    // -----------------------------------------------------------------
    // Vítima combinacional única.
    // -----------------------------------------------------------------
    assign victim_way_c = has_invalid ? invalid_sel :
                         has_rr11   ? rr11_sel    :
                                      ((rr0 == 2'b11) ? 2'd0 :
                                       (rr1 == 2'b11) ? 2'd1 :
                                       (rr2 == 2'b11) ? 2'd2 :
                                       (rr3 == 2'b11) ? 2'd3 : 2'd0);

    assign victim_found_c = refill_valid;

    // -----------------------------------------------------------------
    // insert_rrpv combinacional: SRRIP = 2'b10; BRRIP simplificado = 2'b11,
    // raramente 2'b10 quando brrip_counter == 3'b000.
    // -----------------------------------------------------------------
    assign insert_rrpv_c = policy_brrip ? ((brrip_counter == 3'b000) ? 2'b10 : 2'b11) : 2'b10;

    // -----------------------------------------------------------------
    // Valores de escrita nas memórias RRPV para o caso de refill.
    // -----------------------------------------------------------------
    assign write_rrpv0 = (victim_way_c == 2'd0) ? insert_rrpv_c :
                         (has_invalid || has_rr11) ? rrpv0 : rr0;
    assign write_rrpv1 = (victim_way_c == 2'd1) ? insert_rrpv_c :
                         (has_invalid || has_rr11) ? rrpv1 : rr1;
    assign write_rrpv2 = (victim_way_c == 2'd2) ? insert_rrpv_c :
                         (has_invalid || has_rr11) ? rrpv2 : rr2;
    assign write_rrpv3 = (victim_way_c == 2'd3) ? insert_rrpv_c :
                         (has_invalid || has_rr11) ? rrpv3 : rr3;

    // -----------------------------------------------------------------
    // Saídas atribuídas por assign (único driver combinacional).
    // -----------------------------------------------------------------
    assign victim_way   = victim_way_c;
    assign victim_found = victim_found_c;
    assign insert_rrpv  = insert_rrpv_c;

    // -----------------------------------------------------------------
    // Bloco sequencial: atualiza memórias, psel e brrip_counter.
    // -----------------------------------------------------------------
    integer idx;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Inicializa todas as RRPVs em 2'b11.
            for (idx = 0; idx < 64; idx = idx + 1) begin
                rrpv_way0_mem[idx] <= 2'b11;
                rrpv_way1_mem[idx] <= 2'b11;
                rrpv_way2_mem[idx] <= 2'b11;
                rrpv_way3_mem[idx] <= 2'b11;
            end
            psel          <= 4'b0000;
            brrip_counter <= 3'b000;
        end else begin
            if (access_valid) begin
                if (access_is_hit) begin
                    // Hit: zera o RRPV da hit_way.
                    case (hit_way)
                        2'd0: rrpv_way0_mem[set_idx] <= 2'b00;
                        2'd1: rrpv_way1_mem[set_idx] <= 2'b00;
                        2'd2: rrpv_way2_mem[set_idx] <= 2'b00;
                        2'd3: rrpv_way3_mem[set_idx] <= 2'b00;
                        default: ; // nada
                    endcase
                end else if (refill_valid) begin
                    // Refill: grava os valores combinacionais nas memórias.
                    rrpv_way0_mem[set_idx] <= write_rrpv0;
                    rrpv_way1_mem[set_idx] <= write_rrpv1;
                    rrpv_way2_mem[set_idx] <= write_rrpv2;
                    rrpv_way3_mem[set_idx] <= write_rrpv3;

                    // Atualiza o brrip_counter.
                    brrip_counter <= brrip_counter + 3'b001;

                    // Atualiza PSEL saturado com base no tipo de refill.
                    // Decrementa em SRRIP, incrementa em BRRIP; saturação em 0 e 15.
                    if (policy_brrip) begin
                        if (psel < 4'b1111)
                            psel <= psel + 4'b0001;
                    end else begin
                        if (psel > 4'b0000)
                            psel <= psel - 4'b0001;
                    end
                end
            end
        end
    end

endmodule
