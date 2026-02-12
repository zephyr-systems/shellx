package ir

import "core:mem"
import "core:fmt"

// Arena_IR struct definition has been moved to ir/types.odin

create_arena :: proc(capacity: int) -> Arena_IR {
	backing_buffer := make([]byte, capacity) // Allocate backing buffer
	arena_instance: mem.Arena
	mem.arena_init(&arena_instance, backing_buffer) // Initialize arena with the buffer

	return Arena_IR{
		arena = arena_instance,
		backing_buffer = backing_buffer,
	}
}

destroy_arena :: proc(arena: ^Arena_IR) {
	delete(arena.backing_buffer) // Delete the backing buffer
}

create_program :: proc(arena: ^Arena_IR, dialect: ShellDialect) -> ^Program {
	program := new(Program, mem.arena_allocator(&arena.arena)) // Use mem.arena_allocator
	program.dialect = dialect
	program.functions = make([dynamic]Function, 0, 4, mem.arena_allocator(&arena.arena)) // Use mem.arena_allocator
	program.statements = make([dynamic]Statement, 0, 4, mem.arena_allocator(&arena.arena)) // Use mem.arena_allocator
	return program
}

create_function :: proc(arena: ^Arena_IR, name: string, location: SourceLocation) -> Function {
	return Function{
		name = name,
		parameters = make([dynamic]string, 0, 4, mem.arena_allocator(&arena.arena)), // Use mem.arena_allocator
		body = make([dynamic]Statement, 0, 4, mem.arena_allocator(&arena.arena)),     // Use mem.arena_allocator
		location = location,
	}
}

add_function :: proc(program: ^Program, func: Function) {
	append(&program.functions, func)
}

add_statement :: proc(program: ^Program, stmt: Statement) {
	append(&program.statements, stmt)
}