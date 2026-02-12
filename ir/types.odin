package ir

import "core:mem" // Import mem for mem.Allocator

ShellDialect :: enum {
	Bash,
	Zsh,
	Fish,
	POSIX,
}

SourceLocation :: struct {
	file:    string,
	line:    int,
	column:  int,
	length:  int,
}

Program :: struct {
	dialect:   ShellDialect,
	functions: [dynamic]Function,
	statements: [dynamic]Statement,
}

Function :: struct {
	name:       string,
	parameters: [dynamic]string,
	body:       [dynamic]Statement,
	location:   SourceLocation,
}

StatementType :: enum {
	Assign,
	Call,
	Return,
	Branch,
	Loop,
	Pipeline,
}

Assign :: struct {
	variable: string,
	value:    string,
	location: SourceLocation,
}

Call :: struct {
	command:   string,
	arguments: [dynamic]string,
	location:  SourceLocation,
}

Return :: struct {
	value:   string,
	location: SourceLocation,
}

Branch :: struct {
	condition: string,
	then_body: [dynamic]Statement,
	else_body: [dynamic]Statement,
	location:  SourceLocation,
}

LoopKind :: enum {
	ForIn,
	ForC,
	While,
	Until,
}

Loop :: struct {
	kind:      LoopKind,
	variable:  string,
	iterable:  string,
	condition: string,
	body:      [dynamic]Statement,
	location:  SourceLocation,
}

Pipeline :: struct {
	commands: [dynamic]Call,
	location: SourceLocation,
}

Statement :: struct {
	type:      StatementType,
	assign:    Assign,
	call:      Call,
	return_:   Return,
	branch:    Branch,
	loop:      Loop,
	pipeline:  Pipeline,
	location:  SourceLocation,
}

// ValidatorError represents an error during the IR validation process.
ValidatorError :: struct {
	error:   ValidatorErrorType,
	message: string,
}

// ValidatorErrorType defines the types of errors that can occur during validation.
ValidatorErrorType :: enum {
	None,
	UndefinedVariable,
	DuplicateFunction,
	InvalidControlFlow,
	// Add more specific validation error types as needed
}

// Arena_IR struct definition moved from ir/builder.odin
Arena_IR :: struct {
	arena: mem.Arena, // Contains the mem.Arena directly
	backing_buffer: []byte, // Manage the backing buffer directly
}

