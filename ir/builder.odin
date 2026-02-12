package ir

import "core:mem"

// Arena_IR struct definition has been moved to ir/types.odin

create_arena :: proc(capacity: int) -> Arena_IR {
	backing_buffer := make([]byte, capacity) // Allocate backing buffer
	arena_instance: mem.Arena
	mem.arena_init(&arena_instance, backing_buffer) // Initialize arena with the buffer
	arena := Arena_IR{
		arena = arena_instance,
		backing_buffer = backing_buffer,
	}
	return arena
}

destroy_arena :: proc(arena: ^Arena_IR) {
	delete(arena.string_intern)
	delete(arena.backing_buffer) // Delete the backing buffer
}

create_program :: proc(arena: ^Arena_IR, dialect: ShellDialect) -> ^Program {
	program := new(Program, mem.arena_allocator(&arena.arena))
	program.dialect = dialect
	program.functions = make([dynamic]Function, 0, 4, mem.arena_allocator(&arena.arena))
	program.statements = make([dynamic]Statement, 0, 4, mem.arena_allocator(&arena.arena))
	return program
}

create_function :: proc(arena: ^Arena_IR, name: string, location: SourceLocation) -> Function {
	return Function{
		name = intern_string(arena, name),
		parameters = make([dynamic]string, 0, 4, mem.arena_allocator(&arena.arena)),
		body = make([dynamic]Statement, 0, 4, mem.arena_allocator(&arena.arena)),
		location = location,
	}
}

intern_string :: proc(arena: ^Arena_IR, value: string) -> string {
	if value == "" {
		return ""
	}

	if arena.string_intern == nil {
		arena.string_intern = make(map[string]string)
	}

	if interned, ok := arena.string_intern[value]; ok {
		return interned
	}

	buffer := make([]byte, len(value), mem.arena_allocator(&arena.arena))
	copy(buffer, value)
	interned := string(buffer)
	arena.string_intern[interned] = interned
	return interned
}

add_function :: proc(program: ^Program, func: Function) {
	append(&program.functions, func)
}

add_statement :: proc(program: ^Program, stmt: Statement) {
	append(&program.statements, stmt)
}
