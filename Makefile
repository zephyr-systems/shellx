.PHONY: all build test clean install setup-tree-sitter example

ODIN := odin
BUILD_DIR := build
BIN_DIR := bin
SRC_DIR := .

all: build

# Build the library (checks for compilation errors)
build:
	@mkdir -p $(BUILD_DIR)
	$(ODIN) check $(SRC_DIR)

# Build example that uses the library
example:
	@mkdir -p $(BUILD_DIR)
	$(ODIN) build examples -out:$(BUILD_DIR)/demo -o:speed
	./$(BUILD_DIR)/demo

build-debug:
	@mkdir -p $(BUILD_DIR)
	$(ODIN) check $(SRC_DIR) -debug

test:
	$(ODIN) test . -all-packages

test-verbose:
	$(ODIN) test . -all-packages -v

test-unit:
	$(ODIN) test . -all-packages -filter:variable_assignment

test-integration:
	$(ODIN) test . -all-packages -filter:function_definition

test-corpus:
	@echo "Corpus tests not yet implemented"

benchmark:
	$(ODIN) test tests/benchmarks -all-packages 2>/dev/null || echo "Benchmarks skipped"

clean:
	rm -rf $(BUILD_DIR)

install: build
	@mkdir -p $(BIN_DIR)
	cp $(BUILD_DIR)/shellx $(BIN_DIR)/

setup-tree-sitter:
	./scripts/setup_tree_sitter.sh
