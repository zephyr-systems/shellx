#!/bin/bash
# scripts/setup_tree_sitter.sh

set -e

TREE_SITTER_VERSION="0.20.8"
GRAMMARS_DIR="vendor/tree-sitter-grammars"

echo "Setting up Tree-sitter..."

# Install Tree-sitter library
if ! command -v tree-sitter &> /dev/null; then
    echo "Installing Tree-sitter CLI..."
    npm install -g tree-sitter-cli
fi

# Create grammars directory
mkdir -p "$GRAMMARS_DIR"

# Clone and build grammars
clone_and_build() {
    local name=$1
    local repo=$2
    
    echo "Setting up $name grammar..."
    
    if [ ! -d "$GRAMMARS_DIR/$name" ]; then
        git clone "$repo" "$GRAMMARS_DIR/$name"
    fi
    
    cd "$GRAMMARS_DIR/$name"
    tree-sitter generate
    cd -
}

clone_and_build "bash" "https://github.com/tree-sitter/tree-sitter-bash"
clone_and_build "fish" "https://github.com/ram02z/tree-sitter-fish"
clone_and_build "zsh" "https://github.com/tree-sitter-grammars/tree-sitter-zsh"

echo "Tree-sitter setup complete!"