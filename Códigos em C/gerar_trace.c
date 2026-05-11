#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

/* =========================================================
 * GERADOR DE TRACE BASEADO NO APENDICE A
 *
 * Ajuste feito: o trace usa enderecos sinteticos de 32 bits,
 * e nao ponteiros reais do processo. Isso deixa os resultados
 * mais reprodutiveis e mais proximos de um ambiente RISC-V 32 bits.
 * ========================================================= */

#define L2_SIZE_BYTES (128 * 1024)
#define ARRAY_SIZE (L2_SIZE_BYTES * 2 / sizeof(int))

#define BASE_ARRAY 0x10000000u
#define BASE_OUT   0x20000000u
#define BASE_BLOB  0x30000000u
#define BASE_NODES 0x40000000u
#define ADDR_HOT   0x50000000u

#define NODE_SIZE_BYTES 8u
#define NODE_DATA_OFF   0u
#define NODE_NEXT_OFF   4u

#define ADDR_ARRAY(i)      (BASE_ARRAY + (uint32_t)(i) * 4u)
#define ADDR_OUT(i)        (BASE_OUT   + (uint32_t)(i) * 4u)
#define ADDR_BLOB(i)       (BASE_BLOB  + (uint32_t)(i))
#define ADDR_NODE_DATA(i)  (BASE_NODES + (uint32_t)(i) * NODE_SIZE_BYTES + NODE_DATA_OFF)
#define ADDR_NODE_NEXT(i)  (BASE_NODES + (uint32_t)(i) * NODE_SIZE_BYTES + NODE_NEXT_OFF)
#define TRACE_ACESSO(end)  fprintf(trace, "0x%08x\n", (uint32_t)(end))

typedef struct Node {
    int data;
    struct Node *next;
} Node;

static FILE *trace = NULL;

static void run_streaming(int *array, volatile int *hot_data) {
    printf("Gerando trace: Streaming + HotSet\n");

    for (int it = 0; it < 10; it++) {
        for (int i = 0; i < (int)ARRAY_SIZE; i++) {
            TRACE_ACESSO(ADDR_ARRAY(i));
            array[i] += i;

            if (i % 64 == 0) {
                TRACE_ACESSO(ADDR_ARRAY(i));
                TRACE_ACESSO(ADDR_HOT);
                *hot_data += array[i];
            }
        }
    }
}

static void run_matrix_conv(int *img, int *out) {
    printf("Gerando trace: Matriz 2D - Convolucao\n");

    int width  = 128;
    int height = (int)ARRAY_SIZE / width;

    for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
            int i0 = (y - 1) * width + x;
            int i1 = y * width + x;
            int i2 = (y + 1) * width + x;
            int io = y * width + x;

            TRACE_ACESSO(ADDR_ARRAY(i0));
            TRACE_ACESSO(ADDR_ARRAY(i1));
            TRACE_ACESSO(ADDR_ARRAY(i2));
            TRACE_ACESSO(ADDR_OUT(io));

            out[io] = img[i0] + img[i1] + img[i2];
        }
    }
}

static void run_linked_list(Node *nodes, int count) {
    printf("Gerando trace: Linked List\n");

    int atual = 0;

    for (int i = 0; i < count * 50; i++) {
        TRACE_ACESSO(ADDR_NODE_DATA(atual));
        nodes[atual].data += i;

        TRACE_ACESSO(ADDR_NODE_NEXT(atual));
        atual++;
        if (atual == count) atual = 0;
    }
}

static void run_pattern_search(uint8_t *blob, int size) {
    printf("Gerando trace: Pattern Search\n");

    for (int i = 1024; i < size; i++) {
        for (int j = 1; j < 64; j++) {
            TRACE_ACESSO(ADDR_BLOB(i));
            TRACE_ACESSO(ADDR_BLOB(i - j));

            if (blob[i] == blob[i - j]) {
                TRACE_ACESSO(ADDR_BLOB(i));
                blob[i]++;
                break;
            }
        }
    }
}

static void print_menu(void) {
    printf("========================================\n");
    printf(" GERADOR DE TRACE - CACHE IA\n");
    printf("========================================\n");
    printf("1. Streaming + HotSet\n");
    printf("2. Matrix Convolution\n");
    printf("3. Linked List Traversal\n");
    printf("4. Pattern Search\n");
    printf("5. Executar todos em sequencia\n");
    printf("6. Validacao pequena\n");
    printf("0. Sair\n");
    printf("Escolha uma opcao: ");
}

static const char *nome_trace(int choice) {
    switch (choice) {
        case 1: return "trace_streaming.txt";
        case 2: return "trace_matrix.txt";
        case 3: return "trace_linked_list.txt";
        case 4: return "trace_pattern.txt";
        case 5: return "trace_todos.txt";
        case 6: return "trace_validacao.txt";
        default: return NULL;
    }
}

static void run_validacao_pequena(void) {
    printf("Gerando trace: Validacao pequena\n");

    /* Mesmo bloco varias vezes: deve mostrar hits depois do primeiro miss. */
    for (int i = 0; i < 8; i++) {
        TRACE_ACESSO(0x00001000u);
    }

    /* Blocos diferentes, mas simples de conferir no papel. */
    TRACE_ACESSO(0x00001020u);
    TRACE_ACESSO(0x00001040u);
    TRACE_ACESSO(0x00001000u);
    TRACE_ACESSO(0x00001020u);
    TRACE_ACESSO(0x00001040u);
}

int main(int argc, char **argv) {
    int choice = -1;
    volatile int hot_val = 0;

    if (argc >= 2) {
        choice = atoi(argv[1]);
    } else {
        print_menu();
        if (scanf("%d", &choice) != 1) return 1;
    }

    if (choice == 0) {
        printf("Encerrando...\n");
        return 0;
    }

    const char *arquivo_saida = nome_trace(choice);
    if (!arquivo_saida) {
        fprintf(stderr, "Opcao invalida.\n");
        return 1;
    }

    int *big_array = (int *)calloc(ARRAY_SIZE, sizeof(int));
    int *out_array = (int *)calloc(ARRAY_SIZE, sizeof(int));
    uint8_t *blob  = (uint8_t *)malloc(L2_SIZE_BYTES);
    Node *nodes    = (Node *)malloc(2000 * sizeof(Node));

    if (!big_array || !out_array || !blob || !nodes) {
        fprintf(stderr, "ERRO: falha na alocacao de memoria.\n");
        free(big_array);
        free(out_array);
        free(blob);
        free(nodes);
        return 1;
    }

    for (int i = 0; i < L2_SIZE_BYTES; i++) {
        blob[i] = (uint8_t)(i % 251);
    }

    for (int i = 0; i < 1999; i++) {
        nodes[i].data = i;
        nodes[i].next = &nodes[i + 1];
    }
    nodes[1999].data = 1999;
    nodes[1999].next = &nodes[0];

    trace = fopen(arquivo_saida, "w");
    if (!trace) {
        fprintf(stderr, "ERRO: nao foi possivel criar %s\n", arquivo_saida);
        free(big_array);
        free(out_array);
        free(blob);
        free(nodes);
        return 1;
    }

    switch (choice) {
        case 1:
            run_streaming(big_array, &hot_val);
            break;
        case 2:
            run_matrix_conv(big_array, out_array);
            break;
        case 3:
            run_linked_list(nodes, 2000);
            break;
        case 4:
            run_pattern_search(blob, L2_SIZE_BYTES);
            break;
        case 5:
            run_streaming(big_array, &hot_val);
            run_matrix_conv(big_array, out_array);
            run_linked_list(nodes, 2000);
            run_pattern_search(blob, L2_SIZE_BYTES);
            break;
        case 6:
            run_validacao_pequena();
            break;
    }

    fclose(trace);

    free(big_array);
    free(out_array);
    free(blob);
    free(nodes);

    printf("\nTrace gerado em: %s\n", arquivo_saida);
    return 0;
}
