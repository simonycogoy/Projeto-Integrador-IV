// lru_set.v
// Um conjunto de cache com 4 vias usando LRU verdadeiro.
//
// A idade varia de 0 a 3:
// 0 = via mais recentemente usada
// 3 = via menos recentemente usada

module lru_set (
    input  wire        clock,
    input  wire        reset,
    input  wire [21:0] tag_in,
    input  wire        acesso_valido,

    output wire        eh_hit,
    output wire        miss,
    output wire        possui_invalida,
    output wire [1:0]  via_vitima,
    output wire        vitima_encontrada
);

    reg [21:0] tag0;
    reg [21:0] tag1;
    reg [21:0] tag2;
    reg [21:0] tag3;

    reg valid0;
    reg valid1;
    reg valid2;
    reg valid3;

    reg [1:0] idade0;
    reg [1:0] idade1;
    reg [1:0] idade2;
    reg [1:0] idade3;

    wire hit0;
    wire hit1;
    wire hit2;
    wire hit3;

    wire todas_validas;
    wire [1:0] maior01;
    wire [1:0] maior23;
    wire [1:0] maior_idade;

    wire vitima0;
    wire vitima1;
    wire vitima2;
    wire vitima3;

    function [1:0] incrementa_saturado;
        input [1:0] valor;

        begin
            if (valor == 2'd3)
                incrementa_saturado = 2'd3;
            else
                incrementa_saturado = valor + 1'b1;
        end
    endfunction

    // --------------------------------------------------------------
    // Verificacao de hit
    // --------------------------------------------------------------

    assign hit0 =
        acesso_valido && valid0 && (tag0 == tag_in);

    assign hit1 =
        acesso_valido && valid1 && (tag1 == tag_in);

    assign hit2 =
        acesso_valido && valid2 && (tag2 == tag_in);

    assign hit3 =
        acesso_valido && valid3 && (tag3 == tag_in);

    assign eh_hit = hit0 || hit1 || hit2 || hit3;
    assign miss   = acesso_valido && !eh_hit;

    assign possui_invalida =
        !valid0 || !valid1 || !valid2 || !valid3;

    assign todas_validas =
        valid0 && valid1 && valid2 && valid3;

    // Descobre a maior idade.
    assign maior01 =
        (idade0 >= idade1) ? idade0 : idade1;

    assign maior23 =
        (idade2 >= idade3) ? idade2 : idade3;

    assign maior_idade =
        (maior01 >= maior23) ? maior01 : maior23;

    // --------------------------------------------------------------
    // Escolha da vitima
    // --------------------------------------------------------------

    assign vitima0 =
        miss &&
        ((!valid0) ||
        (todas_validas && (idade0 == maior_idade)));

    assign vitima1 =
        miss && !vitima0 &&
        ((!valid1) ||
        (todas_validas && (idade1 == maior_idade)));

    assign vitima2 =
        miss && !vitima0 && !vitima1 &&
        ((!valid2) ||
        (todas_validas && (idade2 == maior_idade)));

    assign vitima3 =
        miss && !vitima0 && !vitima1 && !vitima2;

    assign vitima_encontrada =
        vitima0 || vitima1 || vitima2 || vitima3;

    assign via_vitima =
        vitima0 ? 2'd0 :
        vitima1 ? 2'd1 :
        vitima2 ? 2'd2 :
        vitima3 ? 2'd3 :
                  2'd0;

    // --------------------------------------------------------------
    // Atualizacao do LRU
    // --------------------------------------------------------------

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

            idade0 <= 2'd0;
            idade1 <= 2'd0;
            idade2 <= 2'd0;
            idade3 <= 2'd0;
        end
        else if (acesso_valido) begin

            // Em hit, a via acessada vira a mais recente.
            if (eh_hit) begin

                if (hit0) begin
                    if (valid1 && (idade1 < idade0))
                        idade1 <= idade1 + 1'b1;

                    if (valid2 && (idade2 < idade0))
                        idade2 <= idade2 + 1'b1;

                    if (valid3 && (idade3 < idade0))
                        idade3 <= idade3 + 1'b1;

                    idade0 <= 2'd0;
                end
                else if (hit1) begin
                    if (valid0 && (idade0 < idade1))
                        idade0 <= idade0 + 1'b1;

                    if (valid2 && (idade2 < idade1))
                        idade2 <= idade2 + 1'b1;

                    if (valid3 && (idade3 < idade1))
                        idade3 <= idade3 + 1'b1;

                    idade1 <= 2'd0;
                end
                else if (hit2) begin
                    if (valid0 && (idade0 < idade2))
                        idade0 <= idade0 + 1'b1;

                    if (valid1 && (idade1 < idade2))
                        idade1 <= idade1 + 1'b1;

                    if (valid3 && (idade3 < idade2))
                        idade3 <= idade3 + 1'b1;

                    idade2 <= 2'd0;
                end
                else if (hit3) begin
                    if (valid0 && (idade0 < idade3))
                        idade0 <= idade0 + 1'b1;

                    if (valid1 && (idade1 < idade3))
                        idade1 <= idade1 + 1'b1;

                    if (valid2 && (idade2 < idade3))
                        idade2 <= idade2 + 1'b1;

                    idade3 <= 2'd0;
                end
            end
            else begin
                // Em uma insercao, as outras vias envelhecem.
                if (valid0 && !vitima0)
                    idade0 <= incrementa_saturado(idade0);

                if (valid1 && !vitima1)
                    idade1 <= incrementa_saturado(idade1);

                if (valid2 && !vitima2)
                    idade2 <= incrementa_saturado(idade2);

                if (valid3 && !vitima3)
                    idade3 <= incrementa_saturado(idade3);

                // A nova via se torna a mais recente.
                if (vitima0) begin
                    tag0   <= tag_in;
                    valid0 <= 1'b1;
                    idade0 <= 2'd0;
                end
                else if (vitima1) begin
                    tag1   <= tag_in;
                    valid1 <= 1'b1;
                    idade1 <= 2'd0;
                end
                else if (vitima2) begin
                    tag2   <= tag_in;
                    valid2 <= 1'b1;
                    idade2 <= 2'd0;
                end
                else if (vitima3) begin
                    tag3   <= tag_in;
                    valid3 <= 1'b1;
                    idade3 <= 2'd0;
                end
            end
        end
    end

endmodule