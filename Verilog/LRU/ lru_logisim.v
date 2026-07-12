// Testbench comparativo UNICO foi escolhido por ser metodologicamente
// superior a dois TBs separados: garante que RRIP(SRRIP), RRIP(BRRIP) e LRU
// recebam EXATAMENTE os mesmos acessos, na mesma ordem, permitindo comparacao
// justa de hit rates. Os tres arquivos abaixo estao separados por marcadores.

//================ ARQUIVO: lru_logisim.v ================
// Modulo de UM conjunto 4-way com politica LRU verdadeira.
// Interface compativel com drrip_logisim para facilitar o wrapper.
// Ranking LRU por via: 0 = mais recente (MRU), 3 = menos recente (LRU).
module lru_logisim(
  input clock,
  input reset,
  input [3:0] tag_in,
  input acesso_valido,
  input SRRIP_ou_BRRIP,      // mantido por compatibilidade, ignorado internamente
  output reg eh_hit,
  output reg miss,
  output reg invalido,
  output reg [1:0] via_vitima,
  output reg vitima_encontrada,
  output reg [1:0] insercao_rrpv, // compatibilidade; em LRU fica 2'b00
  output reg hit0,
  output reg hit1,
  output reg hit2,
  output reg hit3
);

  // Estado por via
  reg [3:0] tag_mem [0:3];
  reg       val_mem [0:3];
  reg [1:0] rnk_mem [0:3]; // 0=MRU, 3=LRU

  // Temporarios (uso combinacional dentro do bloco)
  reg [1:0] oldr [0:3];
  reg [1:0] newr [0:3];
  reg [1:0] acc_old_eff;
  reg [1:0] sel_way;
  reg       hit_found;
  reg [1:0] hit_way;
  reg       any_invalid;
  reg [1:0] first_inv;
  reg       lru_found;
  reg [1:0] lru_way;

  integer m;

  // Calcula novo ranking para a via j dado:
  //   way     = via acessada/inserida
  //   acc_old = ranking antigo da via acessada (ou 3 para insercao)
  //   oj      = ranking antigo da via j
  // Regra: way -> 0; quem era mais recente (oj < acc_old) envelhece +1.
  function [1:0] calc_new;
    input integer j;
    input integer way;
    input [1:0] acc_old;
    input [1:0] oj;
  begin
    if (j == way)
      calc_new = 2'b00;
    else if (oj < acc_old)
      calc_new = oj + 2'b01;
    else
      calc_new = oj;
  end
  endfunction

  always @(posedge clock) begin
    if (reset) begin
      for (m = 0; m < 4; m = m + 1) begin
        tag_mem[m] <= 4'b0;
        val_mem[m] <= 1'b0;
        rnk_mem[m] <= 2'b0;
      end
      eh_hit            <= 1'b0;
      miss              <= 1'b0;
      invalido          <= 1'b1;
      via_vitima        <= 2'b0;
      vitima_encontrada <= 1'b0;
      insercao_rrpv     <= 2'b00;
      hit0              <= 1'b0;
      hit1              <= 1'b0;
      hit2              <= 1'b0;
      hit3              <= 1'b0;
    end else begin
      // Defaults por ciclo
      hit0              <= 1'b0;
      hit1              <= 1'b0;
      hit2              <= 1'b0;
      hit3              <= 1'b0;
      eh_hit            <= 1'b0;
      miss              <= 1'b0;
      invalido          <= 1'b0;
      insercao_rrpv     <= 2'b00;
      via_vitima        <= 2'b0;
      vitima_encontrada <= 1'b0;

      if (acesso_valido) begin
        // Snapshot dos rankings atuais
        for (m = 0; m < 4; m = m + 1)
          oldr[m] = rnk_mem[m];

        // ---- Lookup ----
        hit_found = 1'b0;
        hit_way   = 2'b0;
        for (m = 0; m < 4; m = m + 1) begin
          if (val_mem[m] && (tag_mem[m] == tag_in) && !hit_found) begin
            hit_found = 1'b1;
            hit_way   = m[1:0];
          end
        end

        if (hit_found) begin
          // ---- HIT ----
          eh_hit   <= 1'b1;
          miss     <= 1'b0;
          invalido <= 1'b0;
          case (hit_way)
            2'd0: hit0 <= 1'b1;
            2'd1: hit1 <= 1'b1;
            2'd2: hit2 <= 1'b1;
            2'd3: hit3 <= 1'b1;
          endcase

          acc_old_eff = oldr[hit_way];
          sel_way     = hit_way;

          for (m = 0; m < 4; m = m + 1)
            newr[m] = calc_new(m, hit_way, acc_old_eff, oldr[m]);
          for (m = 0; m < 4; m = m + 1)
            rnk_mem[m] <= newr[m];
        end else begin
          // ---- MISS ----
          miss <= 1'b1;

          // Procura primeira via invalida
          any_invalid = 1'b0;
          first_inv   = 2'b0;
          for (m = 0; m < 4; m = m + 1) begin
            if (!val_mem[m] && !any_invalid) begin
              any_invalid = 1'b1;
              first_inv   = m[1:0];
            end
          end

          if (any_invalid) begin
            invalido          <= 1'b1;
            via_vitima        <= first_inv;
            vitima_encontrada <= 1'b1;
            sel_way           = first_inv;
            // Insercao em via invalida: tratar como LRU (3) para envelhecer validas
            acc_old_eff       = 2'b11;
          end else begin
            invalido          <= 1'b0;
            // Procura via LRU (rank 3)
            lru_found = 1'b0;
            lru_way   = 2'b0;
            for (m = 0; m < 4; m = m + 1) begin
              if (val_mem[m] && (rnk_mem[m] == 2'b11) && !lru_found) begin
                lru_found = 1'b1;
                lru_way   = m[1:0];
              end
            end
            if (!lru_found)
              lru_way = 2'b0; // fallback de seguranca
            via_vitima        <= lru_way;
            vitima_encontrada <= 1'b1;
            sel_way           = lru_way;
            acc_old_eff       = 2'b11;
          end

          // Insere o bloco na via selecionada
          tag_mem[sel_way] <= tag_in;
          val_mem[sel_way] <= 1'b1;
          for (m = 0; m < 4; m = m + 1)
            newr[m] = calc_new(m, sel_way, acc_old_eff, oldr[m]);
          for (m = 0; m < 4; m = m + 1)
            rnk_mem[m] <= newr[m];
        end
      end
    end
  end
endmodule
