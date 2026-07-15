// drrip_set.v
// Um conjunto de cache com 4 vias usando RRPV de 2 bits.
// Este modulo nao escolhe sozinho entre SRRIP e BRRIP.
// A cache principal envia o valor de RRPV que deve ser usado na insercao.
//
// Regras usadas:
// Hit: o bloco recebe RRPV = 0.
// Miss com via invalida: usa a primeira via invalida.
// Miss com todas as vias validas: substitui a primeira via com maior RRPV.
// Antes da substituicao, os RRPVs sao envelhecidos ate o maior chegar a 3.
//
// A escolha direta da maior idade equivale a repetir o envelhecimento
// ate aparecer uma via com RRPV = 3, mas evita uma maquina de estados.

module drrip_set (
    input  wire        clock,
    input  wire        reset,
    input  wire [21:0] tag_in,
    input  wire        acesso_valido,
    input  wire [1:0]  rrpv_insercao,

    output wire        eh_hit,
    output wire        miss,
    output wire        possui_invalida,
    output reg [1:0]   via_vitima,
    output wire        vitima_encontrada,

    output wire        hit0,
    output wire        hit1,
    output wire        hit2,
    output wire        hit3
);

    // Tags armazenadas em cada via.
    reg [21:0] tag0;
    reg [21:0] tag1;
    reg [21:0] tag2;
    reg [21:0] tag3;

    // Bits de validade.
    reg valid0;
    reg valid1;
    reg valid2;
    reg valid3;

    // RRPV de cada via: 0 = reuso proximo, 3 = reuso distante.
    reg [1:0] rrpv0;
    reg [1:0] rrpv1;
    reg [1:0] rrpv2;
    reg [1:0] rrpv3;

    wire todas_validas;
    wire [1:0] incremento_idade;

    wire vitima0;
    wire vitima1;
    wire vitima2;
    wire vitima3;

    // Funcao para somar sem ultrapassar o valor maximo 3.
    function [1:0] soma_saturada;
        input [1:0] valor;
        input [1:0] incremento;
        reg   [2:0] soma;
        begin
            soma = {1'b0, valor} + {1'b0, incremento};

            if (soma > 3)
                soma_saturada = 2'd3;
            else
                soma_saturada = soma[1:0];
        end
    endfunction

    // Verificacao de hit
    assign hit0 = acesso_valido && valid0 && (tag0 == tag_in);
    assign hit1 = acesso_valido && valid1 && (tag1 == tag_in);
    assign hit2 = acesso_valido && valid2 && (tag2 == tag_in);
    assign hit3 = acesso_valido && valid3 && (tag3 == tag_in);

    assign eh_hit = hit0 || hit1 || hit2 || hit3;
    assign miss   = acesso_valido && !eh_hit;

    // Estado das vias
    assign possui_invalida = !valid0 || !valid1 || !valid2 || !valid3;

    assign todas_validas = valid0 && valid1 && valid2 && valid3;

    // Descobre o maior RRPV existente no conjunto.
    reg [1:0] maior01; //maior RRPV entre as vias 0 e 1
    reg [1:0] maior23; //maior RRPV entre as vias 2 e 3
    reg [1:0] maior_rrpv; //maior RRPV entre todas as vias

    always @(*) begin
    // Calcula o maior entre rrpv0 e rrpv1
    if (rrpv0 >= rrpv1) begin
        maior01 = rrpv0;
    end
    else begin
        maior01 = rrpv1;
    end

    // Calcula o maior entre rrpv2 e rrpv3
    if (rrpv2 >= rrpv3) begin
        maior23 = rrpv2;
    end
    else begin
        maior23 = rrpv3;
    end

    // Calcula o maior entre os dois resultados anteriores
    if (maior01 >= maior23) begin
        maior_rrpv = maior01;
    end
    else begin
        maior_rrpv = maior23;
    end
end

    // Quantidade necessaria para fazer o maior RRPV chegar a 3.
    assign incremento_idade = 2'd3 - maior_rrpv;

    // Escolha da vitima
    // Prioridade:
    // 1. Primeira via invalida.
    // 2. Primeira via com o maior RRPV.
    assign vitima0 = miss && ((!valid0) || (todas_validas && (rrpv0 == maior_rrpv)));

    assign vitima1 = miss && !vitima0 && ((!valid1) || (todas_validas && (rrpv1 == maior_rrpv)));

    assign vitima2 = miss && !vitima0 && !vitima1 && ((!valid2) || (todas_validas && (rrpv2 == maior_rrpv)));

    assign vitima3 = miss && !vitima0 && !vitima1 && !vitima2;

    assign vitima_encontrada = vitima0 || vitima1 || vitima2 || vitima3;

    always @(*) begin
    if (vitima0) begin
        via_vitima = 2'd0;
    end
    
    else if (vitima1) begin
        via_vitima = 2'd1;
    end
    
    else if (vitima2) begin
        via_vitima = 2'd2;
    end
    
    else if (vitima3) begin
        via_vitima = 2'd3;
    end
    
    else begin
        via_vitima = 2'd0;
    end
    end

    // Atualizacao na borda de subida do clock
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            tag0 <= 22'd0;
            tag1 <= 22'd0;
            tag2 <= 22'd0;
            tag3 <= 22'd0;

            valid0 <= 1'b0;
            valid1 <= 1'b0;
            valid2 <= 1'b0;
            valid3 <= 1'b0;

            rrpv0 <= 2'd0;
            rrpv1 <= 2'd0;
            rrpv2 <= 2'd0;
            rrpv3 <= 2'd0;
        end
        else if (acesso_valido) begin

            // Em um hit, a via encontrada recebe RRPV = 0.
            if (eh_hit) begin
                if (hit0)
                    rrpv0 <= 2'd0;

                if (hit1)
                    rrpv1 <= 2'd0;

                if (hit2)
                    rrpv2 <= 2'd0;

                if (hit3)
                    rrpv3 <= 2'd0;
            end
            else begin

                // Em miss com conjunto cheio, envelhece as vias.
                if (todas_validas) begin
                    rrpv0 <= soma_saturada(
                        rrpv0,
                        incremento_idade
                    );

                    rrpv1 <= soma_saturada(
                        rrpv1,
                        incremento_idade
                    );

                    rrpv2 <= soma_saturada(
                        rrpv2,
                        incremento_idade
                    );

                    rrpv3 <= soma_saturada(
                        rrpv3,
                        incremento_idade
                    );
                end

                // Insere a nova tag na via escolhida.
                if (vitima0) begin
                    tag0   <= tag_in;
                    valid0 <= 1'b1;
                    rrpv0  <= rrpv_insercao;
                end
                else if (vitima1) begin
                    tag1   <= tag_in;
                    valid1 <= 1'b1;
                    rrpv1  <= rrpv_insercao;
                end
                else if (vitima2) begin
                    tag2   <= tag_in;
                    valid2 <= 1'b1;
                    rrpv2  <= rrpv_insercao;
                end
                else if (vitima3) begin
                    tag3   <= tag_in;
                    valid3 <= 1'b1;
                    rrpv3  <= rrpv_insercao;
                end
            end
        end
    end

endmodule