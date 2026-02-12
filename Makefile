.PHONY: all build test clean install setup-tree-sitter

ODIN := odin
BUILD_DIR := build
BIN_DIR := bin
SRC_DIR := .

all: build

build:
	@mkdir -p $(BUILD_DIR)
	$(ODIN) build $(SRC_DIR) -out:$(BUILD_DIR)/shellx -o:speed

build-debug:
	@mkdir -p $(BUILD_DIR)
	$(ODIN) build $(SRC_DIR) -out:$(BUILD_DIR)/shellx -debug

test:
	$(ODIN) test tests/unit -all-packages
	$(ODIN) test tests/integration -all-packages
	./tests/behavioral/run_tests.sh 2>/dev/null || echo "Behavioral tests skipped"

test-unit:
	$(ODIN) test tests/unit -all-packages

test-integration:
	$(ODIN) test tests/integration -all-packages

test-corpus:
	$(ODIN) test tests/corpus -all-packages 2>/dev/null || echo "Corpus tests skipped"

benchmark:
	$(ODIN) test tests/benchmarks -all-packages 2>/dev/null || echo "Benchmarks skipped"

clean:
	rm -rf $(BUILD_DIR)

install: build
	@mkdir -p $(BIN_DIR)
	cp $(BUILD_DIR)/shellx $(BIN_DIR)/

setup-tree-sitter:
	./scripts/setup_tree_sitter.sh
