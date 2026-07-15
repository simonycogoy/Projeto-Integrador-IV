// cache_drrip.v
// Modelo de cache de 4 KB, 4 vias e blocos de 32 bytes.
//
// Implementa DRRIP com: SRRIP, BRRIP e contador PSEL.
//
// Organizacao:
// 32 conjuntos x 4 vias x 32 bytes = 4096 bytes (4KB)
//
// Endereco de 32 bits:
// [4:0]   = offset 5 bits
// [9:5]   = indice 5 bits
// [31:10] = tag 32 bits

module cache_drrip (
    input  wire        clock,
    input  wire        reset,
    input  wire [31:0] addr_in, //recebe o endereço de memória
    input  wire        acesso_valido, 

    output wire        eh_hit,
    output wire        miss,
    output wire [1:0]  via_vitima,
    output wire        vitima_encontrada,
    output reg [1:0]   rrpv_insercao_usado;
    output wire        politica_brrip_usada,
    output wire [5:0]  psel_atual,
    output wire [4:0]  set_index, //mostra o conjunto acessado
    output wire [21:0] tag_extraida 
);

    //utilizamos wire para receber valores através do ass
    wire [4:0]  index; //guarda o conjunto selecionado
    wire [21:0] tag; //guarda o id do bloco

    wire lider_srrip;
    wire lider_brrip;

    // Contador que escolhe entre SRRIP e BRRIP
    //PSEL entre 0 e 31 -> SRRIP
    //PSEL entre 32 e 63 -> BRRIP
    reg [5:0] psel;

    // Contador usado para a insercao do BRRIP.
    // vai de 0 a 31, quando tá 0 insere com RRPV = 2
    reg [4:0] contador_brrip;

    //saídas dos 32 conjuntos
    wire [31:0] acesso_set;
    wire [31:0] hit_set;
    wire [31:0] miss_set;
    wire [31:0] invalida_set;
    wire [31:0] vitima_encontrada_set;

    // Cada conjunto produz uma via de 2 bits.
    // 32 conjuntos x 2 bits = 64 bits.
    wire [63:0] via_vitima_set;

    //hits de cada via
    wire [31:0] hit0_set;
    wire [31:0] hit1_set;
    wire [31:0] hit2_set;
    wire [31:0] hit3_set;

    // Separacao do endereco.
    assign index = addr_in[9:5];
    assign tag   = addr_in[31:10];

    //saídas depuração
    assign set_index    = index;
    assign tag_extraida = tag;

    //quando o conjunto for 0 ou 1 é SRRIP
    assign lider_srrip =
        (index == 5'd0) ||
        (index == 5'd1);

    //quando o conjunto for 2 ou 3 é BRRIP
    assign lider_brrip =
        (index == 5'd2) ||
        (index == 5'd3);

    // Conjunto lider BRRIP sempre usa BRRIP.
    // Conjunto lider SRRIP sempre usa SRRIP.
    // Seguidores consultam o PSEL.
    
reg politica_brrip;

    //bloco combinacional
always @(*) begin
    if (lider_brrip) begin //se o conjunto for brrip
        politica_brrip = 1'b1; //usa o brrip
    end
    else if (lider_srrip) begin //se o conjunto for srrip
        politica_brrip = 1'b0; //usa srrip
    end
    else begin //se não for nenhum dos dois conjuntos
        politica_brrip = psel[5]; //eles seguem o que estiver vencendo
    end
end

    //envia a política escolhida e o psel para as saídas dos módulos, mais pra observação mesmo
    assign politica_brrip_usada = politica_brrip;
    assign psel_atual           = psel;

//bloco combinacional de inserção
//recalcula o valor de inserção sempre que a política escolhida mudar e o contador DRRIP mudar
always @(*) begin
    if (!politica_brrip) begin //quando é SRRIP
        rrpv_insercao_usado = 2'd2; //insere com 2
    end
    else if (contador_brrip == 5'd0) begin //quando é BRRIP e o contador = 0
        rrpv_insercao_usado = 2'd2; //insere com 2
    end
    else begin //se o contador for qualquer outro valor
        rrpv_insercao_usado = 2'd3; //insere com 3
    end
end


    genvar i; //cria cópias de um módulo

    generate
        for (i = 0; i < 32; i = i + 1) //cria fisicamente os 32 conjuntos
        begin : CONJUNTOS_DRRIP
            assign acesso_set[i] = acesso_valido && (index == i); //se o conjunto for igual ao índice, recebe acesso válido. Impede que todos os conjuntos processem ao mesmo tempo

            drrip_set conjunto ( //cria 32 conjuntos
                .clock(clock), //envia o clock para o conjunto
                .reset(reset), //envia o reset para o conjunto
                .tag_in(tag), //envia a tag para o endereço
                .acesso_valido(acesso_set[i]), //somente o conjunto selecionado recebe o acesso válido
                .rrpv_insercao(rrpv_insercao_usado), //envia para o conjunto o RRPV escolhido (SRRIP ou BRRIP)

                .eh_hit(hit_set[i]), //recebe do conjunto se teve hit
                .miss(miss_set[i]), //se teve miss
                .possui_invalida(invalida_set[i]), //se existe via livre

                .via_vitima(
                    via_vitima_set[(2*i) +: 2] //seleciona 2 bits a partir de uma posição
                ),

                //guarda a vítima do conjunto
                .vitima_encontrada(
                    vitima_encontrada_set[i]
                ),

                //informa em qual via ocorreu o hit
                .hit0(hit0_set[i]),
                .hit1(hit1_set[i]),
                .hit2(hit2_set[i]),
                .hit3(hit3_set[i])
            );
        end
    endgenerate

    // Seleciona as saidas do conjunto acessado
    assign eh_hit = hit_set[index];
    assign miss   = miss_set[index];

    assign via_vitima = via_vitima_set[(2*index) +: 2]; //seleciona os dois bits da vítima do conjunto acessado

    assign vitima_encontrada = vitima_encontrada_set[index]; //envia para a saída a vítima do conjunto

    //atualização sequencial do PSEL (ocorre na borda de subida do reset)
    always @(posedge clock or posedge reset) begin
        if (reset) begin //quando tem reset
            // o psel comeca no valor do meio.
            psel <= 6'd31;

            // A primeira insercao BRRIP usa RRPV = 2
            contador_brrip <= 5'd0;
        end
        else if (acesso_valido && miss) begin //o psel e o contador drrip só são atualizados quando ocorre um miss pq um hit não informa se srrip ou brrip foi melhor

            // Miss no lider SRRIP:
            // aumenta PSEL em direcao ao BRRIP.
            if (lider_srrip && (psel != 6'd63)) // !=63 impede o contador de ultrapassar o valor máximo
                psel <= psel + 1'b1;

            // Miss no lider BRRIP:
            // diminui PSEL em direcao ao SRRIP.
            if (lider_brrip && (psel != 6'd0)) // !=0 impede o contador de ficar menor do que 0
                psel <= psel - 1'b1;
        end
    end

endmodule