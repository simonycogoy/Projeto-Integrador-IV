//============================================================================
// DRRIP 4-way Replacement Controller (didático, sintetizável, Verilog-2001)
//============================================================================
// Módulo: drrip_4way_ctrl
//----------------------------------------------------------------------------
// Este arquivo implementa APENAS o controlador de substituição DRRIP 4-way.
// Não inclui cache completa, tag array, data array, nem pipeline.  O objetivo
// é didático: mostrar a estrutura lógica equivalente a um controlador de
// substituição DRRIP conforme modelado em artigos de referência (DRRIP =
// Dynamic Re-Reference Interval Prediction).
//----------------------------------------------------------------------------
// Modelo lógico adotado:
//   - 4 ways por set, índice de set parametrizado por SETS/IDX_W.
//   - Cada way possui um campo RRPV de 2 bits (RRPV_BITS=2).
//   - RRPV valores: 0=longe da substituição, 3=próximo da substituição.
//   - Em hit: a way acessada é promovida para RRPV=2'b00.
//   - Em miss/refill: escolhe-se a vítima segundo a regra DRRIP:
//       1) way inválida primeiro;
//       2) se todas válidas, way com RRPV=2'b11;
//       3) se nenhuma way tem RRPV=2'b11, incrementa-se saturadamente todos
//          os RRPVs do set até aparecer ao menos uma way elegível.
//   - Política de inserção escolhida dinamicamente por leader sets e PSEL:
//       - SRRIP: insere com RRPV=2'b10 (padrão).
//       - BRRIP simplificado: insere padrão com RRPV=2'b11 (mais agressivo);
//         inserção rara com RRPV=2'b10 controlada por contador determinístico
//         interno (sem gerador random real).
//   - PSEL: contador saturado que indica qual política vence entre os leaders.
//     psel_msb_policy = 1 -> BRRIP vence; = 0 -> SRRIP vence.  A convenção é
//     explicada junto ao PSEL.
//----------------------------------------------------------------------------
// Compatibilidade: Verilog-2001, Quartus II/Prime, ModelSim.  Sem SystemVerilog
// avançado.  Sem always_comb, always_ff, logic, etc.
//============================================================================

module drrip_4way_ctrl
#(
    parameter SETS      = 16,        // número de conjuntos (sets)
    parameter IDX_W     = 4,         // largura do índice de set (log2(SETS))
    parameter RRPV_BITS = 2,         // bits por RRPV (2 bits neste modelo)
    parameter PSEL_BITS = 4          // largura do contador PSEL
)
(
    input  wire                  clk,              // clock
    input  wire                  rst,              // reset síncrono ativo alto

    // Interface de acesso (hit/update)
    input  wire                  access_valid,     // acesso ao set é válido
    input  wire                  access_is_hit,    // acesso resultou em hit
    input  wire [IDX_W-1:0]      set_idx,          // índice do set acessado
    input  wire [3:0]            valid_vec,        // vetor de validade das 4 ways
    input  wire [1:0]            hit_way,          // way que deu hit

    // Interface de refill/miss
    input  wire                  refill_valid,     // refill em andamento

    // Saídas do controlador
    output reg  [1:0]            victim_way,       // way selecionada como vítima
    output reg                   victim_found,     // vítima encontrada naquele ciclo
    output reg  [RRPV_BITS-1:0]  insert_rrpv,      // RRPV a ser escrito na vítima
    output wire                  psel_msb_policy   // política dominante segundo MSB de PSEL
);

    //========================================================================
    // 1) RAM de Estado RRPV
    //========================================================================
    // Memória que armazena, para cada set e cada way, o valor RRPV atual.
    // Neste modelo são 4 ways por set, cada uma com RRPV_BITS bits.
    // Organização: way 0 = bits [RRPV_BITS-1:0], way 1 = bits [2*RRPV_BITS-1:RRPV_BITS], etc.
    //
    reg [4*RRPV_BITS-1:0] rrps_ram [0:SETS-1];  // estado RRPV por set

    // Sinal para leitura combinacional do estado do set atual
    wire [4*RRPV_BITS-1:0] rrps_set_rdata;
    assign rrps_set_rdata = rrps_ram[set_idx];

    // Extração dos RRPVs individuais para facilitar leitura (debug/clareza)
    wire [RRPV_BITS-1:0] rrpv0, rrpv1, rrpv2, rrpv3;
    assign rrpv0 = rrps_set_rdata[1*RRPV_BITS-1:0*RRPV_BITS];
    assign rrpv1 = rrps_set_rdata[2*RRPV_BITS-1:1*RRPV_BITS];
    assign rrpv2 = rrps_set_rdata[3*RRPV_BITS-1:2*RRPV_BITS];
    assign rrpv3 = rrps_set_rdata[4*RRPV_BITS-1:3*RRPV_BITS];

    //========================================================================
    // 2) Contador PSEL e Seletor de Política SRRIP/BRRIP
    //========================================================================
    // PSEL é um contador saturado que captura qual política de inserção
    // está performando melhor nos chamados "leader sets".  A regra de
    // atualização adotada neste modelo didático:
    //   - Leader SRRIP: set_idx pertence a um grupo pequeno e fixo.
    //     Sempre que há refill em um leader SRRIP E ocorre posteriormente um
    //     hit nesse mesmo set (não modelado em detalhe aqui), aumentaríamos
    //     PSEL em favor do SRRIP.  Para simplificar e manter o circuito
    //     sintetizável e estável, neste controlador atualizamos PSEL apenas
    //     no refill em leaders: se o refill usa política SRRIP e gerou hit
    //     futuro (não disponível), incrementa; se usa BRRIP, decrementa.
    //   - Neste modelo didático, simplificamos: a cada refill em leader SRRIP
    //     incrementamos PSEL (limitando a saturação); a cada refill em leader
    //     BRRIP decrementamos PSEL.  Isso é uma abstração comum em exemplos
    //     acadêmicos, pois o "hit futuro" não é observável sem cache real.
    //
    // Convenção de PSEL:
    //   - MSB (bit PSEL_BITS-1) indica a política dominante para sets
    //     não-leader.  psel_msb_policy = 1 -> BRRIP; = 0 -> SRRIP.
    //   - Valor intermediário = zona indecisa; usamos apenas o MSB para
    //     escolha, como em implementações clássicas de DRRIP.
    //
    reg [PSEL_BITS-1:0] psel_counter;
    assign psel_msb_policy = psel_counter[PSEL_BITS-1];

    //========================================================================
    // 3) Conjunto de Líderes (Leader Sets)
    //========================================================================
    // Regra determinística simples: sets cujo índice termina em '00' são
    // leader SRRIP; sets cujo índice termina em '11' são leader BRRIP.
    // Os demais sets seguem o MSB de PSEL.  Isso evita tabelas extras e
    // mantém o circuito pequeno e sintetizável.
    //
    wire is_leader_srrip;
    wire is_leader_brrip;
    wire is_leader;
    wire chosen_policy_brrip;  // 1=BRRIP, 0=SRRIP

    assign is_leader_srrip = (set_idx[1:0] == 2'b00);  // leaders SRRIP
    assign is_leader_brrip = (set_idx[1:0] == 2'b11);  // leaders BRRIP
    assign is_leader       = is_leader_srrip | is_leader_brrip;
    assign chosen_policy_brrip = is_leader ? is_leader_brrip : psel_msb_policy;

    //========================================================================
    // 4) BRRIP simplificado: contador determinístico para inserção rara
    //========================================================================
    // Em artigos, BRRIP usa aleatoriedade para inserir raramente um novo
    // bloco com RRPV baixo (2'b00) ou alto (2'b11).  Aqui, para manter a
    // implementação determinística e sintetizável, adotamos:
    //   - BRRIP padrão: insere com RRPV=2'b11 (vítima potencial rápida).
    //   - BRRIP rara:   a cada N refills (contador interno), insere com
    //     RRPV=2'b10 (comportamento próximo do SRRIP, mas ainda distinto).
    // N = 7 para este exemplo, gerado por um contador de 3 bits.
    //
    reg [2:0] brrip_rare_counter;
    wire      brrip_rare_event;
    assign brrip_rare_event = (brrip_rare_counter == 3'd0);

    //========================================================================
    // 5) Funções combinacionais auxiliares para vítima e aging
    //========================================================================
    // Verilog-2001 permite funções.  São puramente combinacionais e sintetizáveis.

    // Função: verifica se existe way inválida e retorna o índice mais baixo.
    // victim_invalid_found = 1 se encontrou; victim_invalid_way recebe o índice.
    task find_invalid_way;
        input  [3:0] valid_vec_in;
        output [1:0] victim_invalid_way;
        output       victim_invalid_found;
        begin
            if (valid_vec_in[0] == 1'b0) begin
                victim_invalid_way = 2'd0; victim_invalid_found = 1'b1;
            end else if (valid_vec_in[1] == 1'b0) begin
                victim_invalid_way = 2'd1; victim_invalid_found = 1'b1;
            end else if (valid_vec_in[2] == 1'b0) begin
                victim_invalid_way = 2'd2; victim_invalid_found = 1'b1;
            end else if (valid_vec_in[3] == 1'b0) begin
                victim_invalid_way = 2'd3; victim_invalid_found = 1'b1;
            end else begin
                victim_invalid_way = 2'd0; victim_invalid_found = 1'b0;
            end
        end
    endtask

    // Função: procura way com RRPV == 2'b11 no set.  Se encontrar,
    // victim_max_found=1 e victim_max_way recebe o índice mais baixo.
    task find_max_rrpv_way;
        input [RRPV_BITS-1:0] r0, r1, r2, r3;
        output [1:0] victim_max_way;
        output       victim_max_found;
        begin
            if (r0 == 2'b11) begin
                victim_max_way = 2'd0; victim_max_found = 1'b1;
            end else if (r1 == 2'b11) begin
                victim_max_way = 2'd1; victim_max_found = 1'b1;
            end else if (r2 == 2'b11) begin
                victim_max_way = 2'd2; victim_max_found = 1'b1;
            end else if (r3 == 2'b11) begin
                victim_max_way = 2'd3; victim_max_found = 1'b1;
            end else begin
                victim_max_way = 2'd0; victim_max_found = 1'b0;
            end
        end
    endtask

    // Função: verifica se existe ao menos uma way com RRPV máximo (2'b11).
    function has_max_rrpv;
        input [RRPV_BITS-1:0] r0, r1, r2, r3;
        begin
            has_max_rrpv = ((r0 == 2'b11) || (r1 == 2'b11) ||
                            (r2 == 2'b11) || (r3 == 2'b11));
        end
    endfunction

    // Função: incremento saturado de um RRPV de 2 bits.
    function [RRPV_BITS-1:0] saturate_inc;
        input [RRPV_BITS-1:0] x;
        begin
            if (x == 2'b11)
                saturate_inc = 2'b11;  // saturação
            else
                saturate_inc = x + 1'b1;
        end
    endfunction

    //========================================================================
    // 6) Lógica de Atualização RRPV e Seleção de Vítima (combinacional)
    //========================================================================
    // Sinais combinacionais intermediários para refill.
    reg [1:0] victim_way_comb;
    reg       victim_found_comb;
    reg [RRPV_BITS-1:0] insert_rrpv_comb;
    reg [4*RRPV_BITS-1:0] aged_rrps_set;     // resultado de aging se necessário
    reg [4*RRPV_BITS-1:0] updated_rrps_set;  // estado RRPV após hit ou refill
    reg       do_aging;                      // indica que aging foi necessário

    // Sinais intermediários para as funções de vítima
    reg [1:0] inv_way;
    reg       inv_found;
    reg [1:0] max_way;
    reg       max_found;

    // Lógica combinacional principal
    always @(*) begin
        // Defaults
        victim_way_comb    = 2'd0;
        victim_found_comb  = 1'b0;
        insert_rrpv_comb   = 2'b10;  // SRRIP default
        aged_rrps_set      = rrps_set_rdata;
        updated_rrps_set   = rrps_set_rdata;
        do_aging           = 1'b0;
        inv_way            = 2'd0;
        inv_found          = 1'b0;
        max_way            = 2'd0;
        max_found          = 1'b0;

        //---------------------------------------------------------------
        // Hit: promove a way acertada para RRPV=00
        //---------------------------------------------------------------
        if (access_valid && access_is_hit) begin
            case (hit_way)
                2'd0: updated_rrps_set[1*RRPV_BITS-1:0*RRPV_BITS] = 2'b00;
                2'd1: updated_rrps_set[2*RRPV_BITS-1:1*RRPV_BITS] = 2'b00;
                2'd2: updated_rrps_set[3*RRPV_BITS-1:2*RRPV_BITS] = 2'b00;
                2'd3: updated_rrps_set[4*RRPV_BITS-1:3*RRPV_BITS] = 2'b00;
                default: updated_rrps_set = rrps_set_rdata;
            endcase
        end

        //---------------------------------------------------------------
        // Refill/miss: seleção de vítima e política de inserção
        //---------------------------------------------------------------
        if (refill_valid) begin
            // Passo 1: verificar se existe way inválida
            find_invalid_way(valid_vec, inv_way, inv_found);

            if (inv_found) begin
                // Vítima é way inválida; RRPV será escrito pela política de inserção.
                victim_way_comb   = inv_way;
                victim_found_comb = 1'b1;
            end else begin
                // Passo 2: todas válidas; procurar RRPV máximo (2'b11).
                find_max_rrpv_way(rrpv0, rrpv1, rrpv2, rrpv3, max_way, max_found);

                if (max_found) begin
                    victim_way_comb   = max_way;
                    victim_found_comb = 1'b1;
                    aged_rrps_set     = rrps_set_rdata; // nenhum aging
                end else begin
                    // Passo 3: aging saturado até aparecer ao menos uma way 2'b11.
                    do_aging = 1'b1;
                    aged_rrps_set[1*RRPV_BITS-1:0*RRPV_BITS] = saturate_inc(rrpv0);
                    aged_rrps_set[2*RRPV_BITS-1:1*RRPV_BITS] = saturate_inc(rrpv1);
                    aged_rrps_set[3*RRPV_BITS-1:2*RRPV_BITS] = saturate_inc(rrpv2);
                    aged_rrps_set[4*RRPV_BITS-1:3*RRPV_BITS] = saturate_inc(rrpv3);

                    // Após um aging, sempre aparecerá ao menos uma 2'b11 (saturação).
                    find_max_rrpv_way(
                        aged_rrps_set[1*RRPV_BITS-1:0*RRPV_BITS],
                        aged_rrps_set[2*RRPV_BITS-1:1*RRPV_BITS],
                        aged_rrps_set[3*RRPV_BITS-1:2*RRPV_BITS],
                        aged_rrps_set[4*RRPV_BITS-1:3*RRPV_BITS],
                        max_way, max_found
                    );
                    victim_way_comb   = max_way;
                    victim_found_comb = 1'b1;
                end
            end

            //-----------------------------------------------------------
            // Política de inserção (SRRIP vs BRRIP)
            //-----------------------------------------------------------
            if (chosen_policy_brrip) begin
                // BRRIP simplificado: normalmente insere com RRPV=2'b11;
                // raramente (quando brrip_rare_counter==0) insere com 2'b10.
                if (brrip_rare_event)
                    insert_rrpv_comb = 2'b10;  // inserção rara BRRIP
                else
                    insert_rrpv_comb = 2'b11;  // inserção padrão BRRIP
            end else begin
                // SRRIP: insere com RRPV=2'b10.
                insert_rrpv_comb = 2'b10;
            end

            // Monta o estado RRPV final do set após refill.
            // Primeiro aplica aging se necessário, depois escreve o insert_rrpv na vítima.
            updated_rrps_set = aged_rrps_set;
            case (victim_way_comb)
                2'd0: updated_rrps_set[1*RRPV_BITS-1:0*RRPV_BITS] = insert_rrpv_comb;
                2'd1: updated_rrps_set[2*RRPV_BITS-1:1*RRPV_BITS] = insert_rrpv_comb;
                2'd2: updated_rrps_set[3*RRPV_BITS-1:2*RRPV_BITS] = insert_rrpv_comb;
                2'd3: updated_rrps_set[4*RRPV_BITS-1:3*RRPV_BITS] = insert_rrpv_comb;
                default: updated_rrps_set = aged_rrps_set;
            endcase
        end
    end

    //========================================================================
    // 7) Registradores de saída e atualização sequencial
    //========================================================================
    // As saídas são registradas para simplificar timing.  A memória RRPV e o
    // PSEL são atualizados no clock.  O contador raro do BRRIP também avança
    // a cada refill.
    //
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            victim_way  <= 2'd0;
            victim_found<= 1'b0;
            insert_rrpv <= 2'b10;
            psel_counter<= {PSEL_BITS{1'b0}};
            brrip_rare_counter <= 3'd0;
            for (i = 0; i < SETS; i = i + 1) begin
                // Inicialização: todas as ways com RRPV=2'b11 (fácil de observar)
                rrps_ram[i] <= {4{2'b11}};
            end
        end else begin
            // Saídas combinacionais registradas
            victim_way  <= victim_way_comb;
            victim_found<= victim_found_comb;
            insert_rrpv <= insert_rrpv_comb;

            if (access_valid || refill_valid) begin
                // Atualiza a RAM de estado RRPV para o set atual.
                rrps_ram[set_idx] <= updated_rrps_set;
            end

            if (refill_valid) begin
                // Atualiza PSEL de forma didática e saturada:
                // leader SRRIP -> incrementa PSEL (favorece SRRIP no MSB=0);
                // leader BRRIP -> decrementa PSEL (favorece BRRIP no MSB=1).
                // Observação: esta é uma abstração acadêmica.  Em uma cache
                // real, PSEL seria atualizado apenas quando se detecta que a
                // política de um leader set gerou um hit futuro.
                if (is_leader_srrip) begin
                    if (psel_counter != {PSEL_BITS{1'b1}})
                        psel_counter <= psel_counter + 1'b1;
                end else if (is_leader_brrip) begin
                    if (psel_counter != {PSEL_BITS{1'b0}})
                        psel_counter <= psel_counter - 1'b1;
                end

                // Avança contador determinístico do BRRIP (apenas em refills)
                brrip_rare_counter <= brrip_rare_counter + 1'b1;
            end
        end
    end

endmodule
