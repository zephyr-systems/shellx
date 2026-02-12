# IR Specification

This document describes ShellX IR in `ir/types.odin`.

## Core Concepts

- Program-level container with top-level statements and functions
- Typed expression union
- Structured statement variants
- Source location attached to nodes

## Dialects

`ShellDialect`:

- `Bash`
- `Zsh`
- `Fish`
- `POSIX`

## Source Location

`SourceLocation` fields:

- `file: string`
- `line: int`
- `column: int`
- `length: int`

## Program Structure

- `Program`
  - `dialect`
  - `functions: [dynamic]Function`
  - `statements: [dynamic]Statement`

- `Function`
  - `name`
  - `parameters`
  - `body`
  - `location`

## Expressions

`Expression` union includes:

- `^Literal`
- `^Variable`
- `^BinaryOp`
- `^UnaryOp`
- `^CallExpr`
- `^ArrayLiteral`
- `^RawExpression`

### Literal

- `value: string`
- `type: LiteralType` (`String`, `Int`, `Bool`, `Raw`)

### Variable

- `name: string`

### BinaryOp

- `op: BinaryOperator` (`Add`, `Sub`, `Mul`, `Div`, `Eq`, `Neq`)
- `left`, `right: Expression`

### UnaryOp

- `op: UnaryOperator` (`Negate`, `Not`)
- `operand: Expression`

## Statements

`StatementType` variants:

- `Assign`
- `Call`
- `Return`
- `Branch`
- `Loop`
- `Pipeline`

Each statement carries a `location`.

## IR Construction Rules

- Use arena-backed constructors where possible.
- Intern repeated strings via `intern_string`.
- Prefer structured expressions over raw strings.
- Populate `SourceLocation` from parser nodes.

## Validation Rules

Validation entry point: `ir.validate_program(program)`.

Current validator tracks high-level categories:

- Undefined variable
- Duplicate function
- Invalid control flow

Validation should run before optimization/emission.

## Example

```odin
arena := ir.create_arena(1024 * 64)
defer ir.destroy_arena(&arena)

program := ir.create_program(&arena, .Bash)
stmt := ir.stmt_assign(&arena, "x", ir.expr_int(&arena, "5"))
ir.add_statement(program, stmt)
```
