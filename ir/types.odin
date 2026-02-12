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

LiteralType :: enum {
	String,
	Int,
	Bool,
	Raw,
}

BinaryOperator :: enum {
	Add,
	Sub,
	Mul,
	Div,
	Eq,
	Neq,
}

UnaryOperator :: enum {
	Negate,
	Not,
}

Expression :: union {
	^Literal,
	^Variable,
	^BinaryOp,
	^UnaryOp,
	^CallExpr,
	^ArrayLiteral,
	^RawExpression,
}

Literal :: struct {
	value: string,
	type:  LiteralType,
}

Variable :: struct {
	name: string,
}

BinaryOp :: struct {
	op:    BinaryOperator,
	left:  Expression,
	right: Expression,
}

UnaryOp :: struct {
	op:      UnaryOperator,
	operand: Expression,
}

CallExpr :: struct {
	function:  ^Variable,
	arguments: [dynamic]Expression,
}

ArrayLiteral :: struct {
	elements: [dynamic]Expression,
}

RawExpression :: struct {
	text: string,
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
	target:   ^Variable,
	value:    Expression,
	location: SourceLocation,
}

Call :: struct {
	function:  ^Variable,
	arguments: [dynamic]Expression,
	location:  SourceLocation,
}

Return :: struct {
	value:    Expression,
	location: SourceLocation,
}

Branch :: struct {
	condition: Expression,
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
	iterator:  ^Variable,
	items:     Expression,
	condition: Expression,
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
	string_intern: map[string]string,
}
