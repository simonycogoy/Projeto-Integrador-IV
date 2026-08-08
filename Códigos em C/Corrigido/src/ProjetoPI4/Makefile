# ============================================================
# Makefile - Simulador de Cache LRU x DRRIP
#
# Uso principal:
#   make
#
# O comando acima APAGA qualquer binario antigo, recompila
# na sua maquina e roda todos os traces.
# Isso evita erro: cannot execute binary file.
# ============================================================

CC      = gcc
CFLAGS  = -O0 -Wall -Wextra -std=c99 -g
SRC     = src/main.c src/cache.c src/cache_lru.c src/cache_drrip.c
HDR     = src/cache.h
BIN     = sim_cache

TRACES = \
	traces/trace_validacao.txt \
	traces/trace_streaming_hotset.txt \
	traces/trace_matrix.txt \
	traces/trace_linked_list.txt \
	traces/trace_pattern.txt \
	traces/trace_l2_pressure.txt

# Alvo padrao: limpa binario velho, compila e roda tudo.
all: fresh

fresh: clean build run

# Apenas compila.
build: $(BIN)

$(BIN): $(SRC) $(HDR)
	$(CC) $(CFLAGS) -o $(BIN) $(SRC)

# Roda todos os traces com LRU e DRRIP.
run: $(BIN)
	@echo ""
	@echo "============================================================"
	@echo " RODANDO TODOS OS TRACES - LRU x DRRIP"
	@echo "============================================================"
	@for trace in $(TRACES); do \
		echo ""; \
		echo "------------------------------------------------------------"; \
		echo "TRACE: $$trace"; \
		echo "------------------------------------------------------------"; \
		./$(BIN) $$trace ambos; \
	done
	@echo ""
	@echo "============================================================"
	@echo " FIM DOS TESTES"
	@echo "============================================================"

# Roda a validacao com debug linha a linha, bom para apresentar.
validacao: build
	./$(BIN) traces/trace_validacao.txt ambos --debug 60

# Atalhos para traces especificos.
streaming: build
	./$(BIN) traces/trace_streaming_hotset.txt ambos

matrix: build
	./$(BIN) traces/trace_matrix.txt ambos

linked: build
	./$(BIN) traces/trace_linked_list.txt ambos

pattern: build
	./$(BIN) traces/trace_pattern.txt ambos

l2: build
	./$(BIN) traces/trace_l2_pressure.txt ambos

# Roda tudo e salva em arquivo, util para colocar no relatorio.
report: clean build
	@mkdir -p resultados
	@echo "Gerando resultados/resultados_cache.txt"
	@{ \
		echo "Resultados - LRU x DRRIP"; \
		echo "Gerado por: make report"; \
		echo ""; \
		for trace in $(TRACES); do \
			echo "============================================================"; \
			echo "TRACE: $$trace"; \
			echo "============================================================"; \
			./$(BIN) $$trace ambos; \
			echo ""; \
		done; \
	} > resultados/resultados_cache.txt
	@cat resultados/resultados_cache.txt

clean:
	rm -f $(BIN)
	rm -rf resultados

.PHONY: all fresh build run validacao streaming matrix linked pattern l2 report clean
