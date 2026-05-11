CC = gcc
CFLAGS = -std=c11 -O0 -Wall -Wextra -pedantic

all: simulador_drrip simulador_lru gerar_trace

simulador_drrip: cache_drrip.c main.c cache.h
	$(CC) $(CFLAGS) -o simulador_drrip cache_drrip.c main.c

simulador_lru: cache_lru.c main.c cache.h
	$(CC) $(CFLAGS) -o simulador_lru cache_lru.c main.c

gerar_trace: gerar_trace.c
	$(CC) $(CFLAGS) -o gerar_trace gerar_trace.c

clean:
	rm -f simulador_drrip simulador_lru gerar_trace *.o *.csv trace_*.txt
