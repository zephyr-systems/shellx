package main

import ts "../../bindings/tree_sitter"
import "../../frontend"
import "core:fmt"
import "core:os"

walk :: proc(node: ts.Node, counts: ^map[string]int) {
	if frontend.is_named(node) {
		counts[frontend.node_type(node)] += 1
	}
	for i in 0..<frontend.child_count(node) {
		walk(frontend.child(node, i), counts)
	}
}

scan_file :: proc(path: string) {
	data, ok := os.read_entire_file(path)
	if !ok { return }
	defer delete(data)
	src := string(data)

	fe := frontend.create_frontend(.Zsh)
	defer frontend.destroy_frontend(&fe)
	tree, err := frontend.parse(&fe, src)
	if err.error != .None || tree == nil { return }
	defer frontend.destroy_tree(tree)

	counts := make(map[string]int)
	defer delete(counts)
	walk(frontend.root_node(tree), &counts)

	fmt.printf("\n== %s ==\n", path)
	for k, v in counts { fmt.printf("%s: %d\n", k, v) }
}

main :: proc() {
	scan_file("tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme")
	scan_file("tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh")
}
