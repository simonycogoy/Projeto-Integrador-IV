#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

/* =========================================================
 * GERADOR DE TRACE BASEADO NO APÊNDICE A
 *
 * Este programa NÃO mede cache real.
 * Ele gera um arquivo trace.txt com endereços de memória.
 * Depois, o simulador main.c + cache.c lê esse trace.
 * ========================================================= */

#define L2_SIZE_BYTES (128 * 1024)
#define ARRAY_SIZE (L2_SIZE_BYTES * 2 / sizeof(int))

#define TRACE_ACESSO(ptr) fprintf(trace, "0x%08x\n", (uint32_t)(uintptr_t)(ptr))

typedef struct Node {
    int data;
    struct Node *next;
} Node;

static FILE *trace = NULL;

void run_streaming(int *array, volatile int *hot_data) {
    printf("Gerando trace: Streaming + HotSet\n");

    for (int it = 0; it < 10; it++) {
        for (int i = 0; i < (int)ARRAY_SIZE; i++) {
            TRACE_ACESSO(&array[i]);
            array[i] += i;

            if (i % 64 == 0) {
                TRACE_ACESSO(&array[i]);
                TRACE_ACESSO((void *)hot_data);
                *hot_data += array[i];
            }
        }
    }
}

void run_matrix_conv(int *img, int *out) {
    printf("Gerando trace: Matriz 2D - Convolucao\n");

    int width  = 128;
    int height = (int)ARRAY_SIZE / width;

    for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
            TRACE_ACESSO(&img[(y-1)*width+x]);
            TRACE_ACESSO(&img[y*width+x]);
            TRACE_ACESSO(&img[(y+1)*width+x]);
            TRACE_ACESSO(&out[y*width+x]);

            out[y*width+x] = img[(y-1)*width+x]
                           + img[y*width+x]
                           + img[(y+1)*width+x];
        }
    }
}

void run_linked_list(Node *nodes, int count) {
    printf("Gerando trace: Linked List\n");

    Node *curr = nodes;

    for (int i = 0; i < count * 50; i++) {
        TRACE_ACESSO(&curr->data);
        curr->data += i;

        TRACE_ACESSO(&curr->next);
        curr = curr->next;
    }
}

void run_pattern_search(uint8_t *blob, int size) {
    printf("Gerando trace: Pattern Search\n");

    for (int i = 1024; i < size; i++) {
        for (int j = 1; j < 64; j++) {
            TRACE_ACESSO(&blob[i]);
            TRACE_ACESSO(&blob[i-j]);

            if (blob[i] == blob[i-j]) {
                TRACE_ACESSO(&blob[i]);
                blob[i]++;
                break;
            }
        }
    }
}

void print_menu() {
    printf("========================================\n");
    printf(" GERADOR DE TRACE - CACHE IA \n");
    printf("========================================\n");
    printf("1. Streaming + HotSet\n");
    printf("2. Matrix Convolution\n");
    printf("3. Linked List Traversal\n");
    printf("4. Pattern Search\n");
    printf("5. Executar Todos em Sequencia\n");
    printf("0. Sair\n");
    printf("Escolha uma opcao: ");
}

int main() {
    int choice = -1;
    volatile int hot_val = 0;

    int     *big_array = (int *)calloc(ARRAY_SIZE, sizeof(int));
    int     *out_array = (int *)calloc(ARRAY_SIZE, sizeof(int));
    uint8_t *blob      = (uint8_t *)malloc(L2_SIZE_BYTES);
    Node    *nodes     = (Node *)malloc(2000 * sizeof(Node));

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
        nodes[i].next = &nodes[i+1];
    }
    nodes[1999].data = 1999;
    nodes[1999].next = &nodes[0];

    trace = fopen("trace.txt", "w");
    if (!trace) {
        fprintf(stderr, "ERRO: nao foi possivel criar trace.txt\n");
        free(big_array);
        free(out_array);
        free(blob);
        free(nodes);
        return 1;
    }

    while (choice != 0) {
        print_menu();
        if (scanf("%d", &choice) != 1) break;

        switch (choice) {
            case 1:
                run_streaming(big_array, &hot_val);
                choice = 0;
                break;
            case 2:
                run_matrix_conv(big_array, out_array);
                choice = 0;
                break;
            case 3:
                run_linked_list(nodes, 2000);
                choice = 0;
                break;
            case 4:
                run_pattern_search(blob, L2_SIZE_BYTES);
                choice = 0;
                break;
            case 5:
                run_streaming(big_array, &hot_val);
                run_matrix_conv(big_array, out_array);
                run_linked_list(nodes, 2000);
                run_pattern_search(blob, L2_SIZE_BYTES);
                choice = 0;
                break;
            case 0:
                printf("Encerrando...\n");
                break;
            default:
                printf("Opcao invalida!\n");
        }
    }

    fclose(trace);

    free(big_array);
    free(out_array);
    free(nodes);
    free(blob);

    printf("\nTrace gerado em: trace.txt\n");
    return 0;
}
