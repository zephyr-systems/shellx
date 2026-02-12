package tree_sitter

foreign import ts {
	"system:tree-sitter",
	"libtree-sitter-bash.dylib",
	"libtree-sitter-zsh.dylib",
	"libtree-sitter-fish.dylib",
}

Parser :: struct {}
Tree :: struct {
    // TSTree is an opaque pointer in C, so we represent it as a rawptr or similar
    // For Odin, we can keep it as an empty struct if we only pass pointers to it,
    // but if we need to access its internal structure, it needs to be defined.
    // However, for the purpose of ts_tree_delete, an opaque pointer is sufficient.
}
Node :: struct {
    ctx:     [4]u32, // Renamed from context to ctx
    id:      rawptr,
    tree:    ^Tree,
}
Language :: struct {}
TSPoint :: struct {
    row: u32,
    column: u32,
}

@(default_calling_convention="c")
foreign ts {
    ts_parser_new :: proc() -> ^Parser ---
    ts_parser_delete :: proc(parser: ^Parser) ---
    ts_parser_set_language :: proc(parser: ^Parser, language: ^Language) -> bool ---
    ts_parser_parse_string :: proc(parser: ^Parser, old_tree: ^Tree, string: cstring, length: u32) -> ^Tree ---
    ts_tree_root_node :: proc(tree: ^Tree) -> Node ---
    ts_tree_delete :: proc(tree: ^Tree) ---
    ts_node_type :: proc(node: Node) -> cstring ---
    ts_node_child_count :: proc(node: Node) -> u32 ---
    ts_node_child :: proc(node: Node, index: u32) -> Node ---
    ts_node_named_child_count :: proc(node: Node) -> u32 ---
    ts_node_named_child :: proc(node: Node, index: u32) -> Node ---
    ts_node_parent :: proc(node: Node) -> Node ---
    ts_node_start_byte :: proc(node: Node) -> u32 ---
    ts_node_end_byte :: proc(node: Node) -> u32 ---
    ts_node_start_point :: proc(node: Node) -> TSPoint ---
    ts_node_end_point :: proc(node: Node) -> TSPoint ---
    ts_node_is_named :: proc(node: Node) -> bool ---
    ts_node_has_error :: proc(node: Node) -> bool ---
    ts_node_is_extra :: proc(node: Node) -> bool ---
    tree_sitter_bash :: proc() -> ^Language ---
    tree_sitter_zsh :: proc() -> ^Language ---
    tree_sitter_fish :: proc() -> ^Language ---
}
