////////////////////////////////////////////////////////////////////////////////
//Dynamic Re-reference Interval Prediction para cache 4-vias
////////////////////////////////////////////////////////////////////////////////

module drrip_logisim (
    input  wire       clock,
    input  wire       reset,
    input  wire [3:0] tag_in,
    input  wire       acesso_valido,
    input  wire       SRRIP_ou_BRRIP, //0 para SRRIP, 1 para BRRIP
    
    // Saidas
    output wire       hit0, hit1, hit2, hit3,
    output wire       eh_hit,
    output wire       rrpv0_igual_3, rrpv1_igual_3, rrpv2_igual_3, rrpv3_igual_3,
    output wire       rrpv_igual_3,
    output wire       rrpv0_menor_3, rrpv1_menor_3, rrpv2_menor_3, rrpv3_menor_3,
    output wire [1:0] idade_rrpv0, idade_rrpv1, idade_rrpv2, idade_rrpv3,
    output wire [1:0] rrpv0_mais_1, rrpv1_mais_1, rrpv2_mais_1, rrpv3_mais_1,
    output wire [1:0] rrpv0_hit, rrpv1_hit, rrpv2_hit, rrpv3_hit,
    output wire       invalid0, invalid1, invalid2, invalid3,
    output wire       invalido,
    output wire       miss,
    output wire       envelhecer_rrpvs,
    output wire [1:0] via_vitima,
    output wire       vitima0, vitima1, vitima2, vitima3,
    output wire       vitima_encontrada,
    output wire [1:0] insercao_rrpv,
    output wire       enable_tag,
    output wire       grava_tag0, grava_tag1, grava_tag2, grava_tag3,
    output wire [1:0] prox_rrpv0, prox_rrpv1, prox_rrpv2, prox_rrpv3,
    output wire [1:0] rrpv0_next, rrpv1_next, rrpv2_next, rrpv3_next
);

    // ESTADO DA CACHE (registradores sincronizados com o clock)
        // para cada um das 4 vias
        // guardamos o tag, valid e rrpv
    
    reg [3:0] tag0, tag1, tag2, tag3;
    reg       valid0, valid1, valid2, valid3;
    reg [1:0] rrpv0, rrpv1, rrpv2, rrpv3;

    //DETECCAO DE HIT
    // Cada saida hitX indica exclusivamente o acerto na via X. A saida eh_hit
    // e o OR de todos os hits, indicando que o dado foi encontrado em alguma das 4 vias.
    
    assign hit0 = (tag0 == tag_in) & valid0 & acesso_valido;
    assign hit1 = (tag1 == tag_in) & valid1 & acesso_valido;
    assign hit2 = (tag2 == tag_in) & valid2 & acesso_valido;
    assign hit3 = (tag3 == tag_in) & valid3 & acesso_valido;
    assign eh_hit = hit0 | hit1 | hit2 | hit3;

    //2 RRPV == 3 RRPV < 3
        // Ja rrpvX_menor_3 informa se o RRPV da via X ainda pode ser incrementado.
        // Esse sinal e usado no mecanismo de envelhecimento: apenas vias abaixo de
        // 3 sao incrementadas no caso de miss.

    assign rrpv0_igual_3 = (rrpv0 == 2'b11);
    assign rrpv1_igual_3 = (rrpv1 == 2'b11);
    assign rrpv2_igual_3 = (rrpv2 == 2'b11);
    assign rrpv3_igual_3 = (rrpv3 == 2'b11);

    assign rrpv_igual_3 = rrpv0_igual_3 | rrpv1_igual_3 | rrpv2_igual_3 | rrpv3_igual_3;

    assign rrpv0_menor_3 = (rrpv0 < 2'b11);
    assign rrpv1_menor_3 = (rrpv1 < 2'b11);
    assign rrpv2_menor_3 = (rrpv2 < 2'b11);
    assign rrpv3_menor_3 = (rrpv3 < 2'b11);

    //3 IDADE (valor atual DO RRPV)
    // A "idade" da linha e simplesmente o valor corrente do RRPV. Expor esses
        // valores para fora do modulo permite observar o estado do preditor.
        // RRPV varia de 0 a 3, onde 0 = reuso previsto proximo, 3 = reuso distante.

    assign idade_rrpv0 = rrpv0;
    assign idade_rrpv1 = rrpv1;
    assign idade_rrpv2 = rrpv2;
    assign idade_rrpv3 = rrpv3;

   //4 RRPV + 1 com limite em 3
    // Quando ocorre um miss e nenhuma via possui RRPV = 3, todas as vias com
    // RRPV < 3 sao envelhecidas, ou seja, incrementadas de 1.
    
    // Como o RRPV e representado por 2 bits, o valor maximo e 3. Se tentarmos
    // incrementar 3, ocorreria overflow. O operador condicional "?:" evita
    // isso: quando rrpvX ja vale 3, mantem 3; caso contrario, soma 1.

    assign rrpv0_mais_1 = (rrpv0 == 2'b11) ? 2'b11 : (rrpv0 + 1'b1);
    assign rrpv1_mais_1 = (rrpv1 == 2'b11) ? 2'b11 : (rrpv1 + 1'b1);
    assign rrpv2_mais_1 = (rrpv2 == 2'b11) ? 2'b11 : (rrpv2 + 1'b1);
    assign rrpv3_mais_1 = (rrpv3 == 2'b11) ? 2'b11 : (rrpv3 + 1'b1);

//5 RRPV se der hit
   // DRRIP alterna entre duas politicas, controladas por SRRIP_ou_BRRIP:
    //   SRRIP (SRRIP_ou_BRRIP = 0): no hit, o RRPV e zerado (2'd0), indicando
    //   que o bloco foi recentemente reusado e provavelmente sera reusado em
    //   breve novamente.
    //   BRRIP (SRRIP_ou_BRRIP = 1): no hit, o RRPV e ajustado para 2 (2'd2),
    //   deixando o bloco um pouco "mais distante" e protegendo blocos que
    //   sofrem acessos esporadicos (thrashing).
    //
    // Cada assign verifica se houve hit na via correspondente. Se nao houver
    // hit, o valor 0 e produzido (nao sera usado, ja que o mux posterior
    // seleciona esse sinal apenas quando hitX = 1).

    assign rrpv0_hit = hit0 ? (SRRIP_ou_BRRIP ? 2'd2 : 2'd0) : 2'd0;
    assign rrpv1_hit = hit1 ? (SRRIP_ou_BRRIP ? 2'd2 : 2'd0) : 2'd0;
    assign rrpv2_hit = hit2 ? (SRRIP_ou_BRRIP ? 2'd2 : 2'd0) : 2'd0;
    assign rrpv3_hit = hit3 ? (SRRIP_ou_BRRIP ? 2'd2 : 2'd0) : 2'd0;

    //6 Vias invalidas
    // Invalido significa que a via nao contem uma tag valida. A prioridade de
    // substituicao e dada primeiro a linhas invalidas (vazias), porque nao
    // perdemos dados uteis. invalido e o OR dos quatro invalidX, informando
    // se existe ao menos uma via livre no conjunto.

    assign invalid0 = ~valid0;
    assign invalid1 = ~valid1;
    assign invalid2 = ~valid2;
    assign invalid3 = ~valid3;
    assign invalido = invalid0 | invalid1 | invalid2 | invalid3;

   //7 MISS e ENVELHECIMENTO

    // Se ainda nao ha nenhuma via com RRPV = 3, nao existe vitima imediata.
        // Entao ativamos envelhecer_rrpvs, que faz com que todos os RRPVs abaixo de
        // 3 sejam incrementados. Esse processo se repete a cada ciclo de miss ate
        // que alguma via atinja RRPV = 3, garantindo que uma vitima seja escolhida.

    assign miss = acesso_valido & ~eh_hit;
    assign envelhecer_rrpvs = miss & ~rrpv_igual_3;

    //8 SELECAO DA VIA VITIMA
    // A regra de escolha e: prefira uma via invalida (livre), respeitando a
    // prioridade 0 > 1 > 2 > 3. Se todas forem validas, escolha a primeira via
    // com RRPV = 3, na mesma ordem de prioridade.
    //
    // Por isso as expressoes para vitimaX tem duas partes:
    //   a) miss & (via invalida, considerando as anteriores ja validas)
    //   b) miss & todas validas & via X possui RRPV = 3 e vias anteriores nao
    //
    // A saida via_vitima converte o sinal one-hot da vitima em um numero de
    // 2 bits (0 a 3), usado por circuitos externos e pela logica de gravacao.
    // vitima_encontrada garante que alguma via foi selecionada.

    assign vitima0 = (miss & invalid0) |
                     (miss & ~invalid0 & ~invalid1 & ~invalid2 & ~invalid3 & rrpv0_igual_3);
    assign vitima1 = (miss & ~invalid0 & invalid1) |
                     (miss & ~invalid0 & ~invalid1 & ~invalid2 & ~invalid3 & ~rrpv0_igual_3 & rrpv1_igual_3);
    assign vitima2 = (miss & ~invalid0 & ~invalid1 & invalid2) |
                     (miss & ~invalid0 & ~invalid1 & ~invalid2 & ~invalid3 & ~rrpv0_igual_3 & ~rrpv1_igual_3 & rrpv2_igual_3);
    assign vitima3 = (miss & ~invalid0 & ~invalid1 & ~invalid2 & invalid3) |
                     (miss & ~invalid0 & ~invalid1 & ~invalid2 & ~invalid3 & ~rrpv0_igual_3 & ~rrpv1_igual_3 & ~rrpv2_igual_3 & rrpv3_igual_3);

    assign vitima_encontrada = vitima0 | vitima1 | vitima2 | vitima3;

    assign via_vitima = vitima0 ? 2'd0 :
                        vitima1 ? 2'd1 :
                        vitima2 ? 2'd2 :
                        vitima3 ? 2'd3 : 2'd0;

    //9 RRPV DE INSERCAO
    //   SRRIP (SRRIP_ou_BRRIP = 0): insere com RRPV = 0, assumindo reuso
    //   iminente.
    //   BRRIP (SRRIP_ou_BRRIP = 1): insere com RRPV = 2, assumindo reuso
    //   distante, o que melhora a tolerancia a thrashing.
    //
    // DRRIP alterna essas politicas dinamicamente para adaptar a cache ao
    // padrao de acesso da aplicacao.

    assign insercao_rrpv = SRRIP_ou_BRRIP ? 2'd2 : 2'd0;

   //10 GRAVACAO DE TAGS
    // enable_tag indica que o controlador geral habilitou a gravacao de tag
    // durante um miss. grava_tagX e o AND entre o acesso_valido e o sinal de
    // vitima correspondente; so sera 1 na via escolhida para substituicao.

    // Esses sinais sao usados no bloco always sequencial para atualizar o
    // registrador tagX da via selecionada na proxima borda de subida.

    assign enable_tag = acesso_valido & miss;
    assign grava_tag0 = acesso_valido & vitima0;
    assign grava_tag1 = acesso_valido & vitima1;
    assign grava_tag2 = acesso_valido & vitima2;
    assign grava_tag3 = acesso_valido & vitima3;

       //11 MUX do RRPV

     // Para cada via, o proximo RRPV e escolhido por prioridade entre tres
    // situacoes mutuamente exclusivas:
    //   1) HIT na via: o RRPV recebe o valor de hit (0 ou 2, conforme politica).
    //   2) MISS e a via e a vitima: o RRPV recebe o valor de insercao
    //      (0 para SRRIP, 2 para BRRIP).
    //   3) MISS, nao e a vitima e a via ainda nao chegou a 3: o RRPV e
    //      incrementado em 1 (envelhecimento). Se ja vale 3, nao e alterado.
    //
    // Se nenhuma das situacoes ocorrer, o RRPV mantem seu valor atual. Isso
    // garante que, em caso de hit em uma via e miss globalmente impossivel
    // (hit e miss sao complementares), apenas a via que acertou seja atualizada.
    //
    // rrpvX_next apenas replica prox_rrpvX para a interface de saida.

    assign prox_rrpv0 = hit0 ? rrpv0_hit :
                        (miss & vitima0) ? insercao_rrpv :
                        (miss & envelhecer_rrpvs & rrpv0_menor_3) ? rrpv0_mais_1 : rrpv0;
    assign prox_rrpv1 = hit1 ? rrpv1_hit :
                        (miss & vitima1) ? insercao_rrpv :
                        (miss & envelhecer_rrpvs & rrpv1_menor_3) ? rrpv1_mais_1 : rrpv1;
    assign prox_rrpv2 = hit2 ? rrpv2_hit :
                        (miss & vitima2) ? insercao_rrpv :
                        (miss & envelhecer_rrpvs & rrpv2_menor_3) ? rrpv2_mais_1 : rrpv2;
    assign prox_rrpv3 = hit3 ? rrpv3_hit :
                        (miss & vitima3) ? insercao_rrpv :
                        (miss & envelhecer_rrpvs & rrpv3_menor_3) ? rrpv3_mais_1 : rrpv3;

    assign rrpv0_next = prox_rrpv0;
    assign rrpv1_next = prox_rrpv1;
    assign rrpv2_next = prox_rrpv2;
    assign rrpv3_next = prox_rrpv3;

   //12 Logica Sequencial

    // Este always bloco e sensivel a borda de subida do clock e a borda de
    // subida do reset assincrono. Ele representa os flip-flops que guardam o
    // estado da cache.

    // No reset:
    //   - As tags sao zeradas;
    //   - Os bits de validade sao zerados (todas as vias invalidas);
    //   - Os RRPVs sao zerados (valor nao critico, pois as vias estao invalidas).
    //
    // Na ausencia de reset:
    //   - Se grava_tagX for alto, a tag da via X recebe tag_in;
    //   - Se a via X for a vitima de um miss, seu valid torna-se 1;
    //   - Todos os RRPVs recebem os valores calculados pela logica combinacional
    //     do multiplexador, atualizando o estado do preditor DRRIP.
 
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            tag0 <= 4'b0000; tag1 <= 4'b0000;
            tag2 <= 4'b0000; tag3 <= 4'b0000;
            valid0 <= 1'b0;  valid1 <= 1'b0;
            valid2 <= 1'b0;  valid3 <= 1'b0;
            rrpv0 <= 2'b00;  rrpv1 <= 2'b00;
            rrpv2 <= 2'b00;  rrpv3 <= 2'b00;
        end else begin
            // Atualiza a tag apenas na via escolhida como vitima
            if (grava_tag0) tag0 <= tag_in;
            if (grava_tag1) tag1 <= tag_in;
            if (grava_tag2) tag2 <= tag_in;
            if (grava_tag3) tag3 <= tag_in;

            // Quando ocorre um miss, marca a via vitima como valida
            if (miss & vitima0) valid0 <= 1'b1;
            if (miss & vitima1) valid1 <= 1'b1;
            if (miss & vitima2) valid2 <= 1'b1;
            if (miss & vitima3) valid3 <= 1'b1;

            // Atualiza o RRPV de todas as vias simultaneamente
            rrpv0 <= prox_rrpv0;
            rrpv1 <= prox_rrpv1;
            rrpv2 <= prox_rrpv2;
            rrpv3 <= prox_rrpv3;
        end
    end

endmodule
