package shellx

import "backend"
import "core:fmt"
import "core:mem"
import "frontend"
import "ir" // Import mem for mem.arena_allocator

// No separate import for ir/validator, as it's part of the 'ir' package.
ShellDialect :: ir.ShellDialect

TranslationOptions :: struct {
	strict_mode:       bool,
	insert_shims:      bool,
	preserve_comments: bool,
}

TranslationResult :: struct {
	success:        bool,
	output:         string,
	warnings:       [dynamic]string,
	required_shims: [dynamic]string,
	error:          Error,
}

Error :: enum {
	None,
	ParseError,
	ConversionError,
	ValidationError,
	EmissionError,
}

translate :: proc(
	source_code: string,
	from: ShellDialect,
	to: ShellDialect,
	options := TranslationOptions{},
) -> TranslationResult {
	result := TranslationResult {
		success = true,
	}

	fmt.println("Translate: Creating arena...")
	arena := ir.create_arena(1024 * 1024)
	defer ir.destroy_arena(&arena) // Ensure arena is destroyed at function exit

	fmt.println("Translate: Creating frontend...")
	fe := frontend.create_frontend(from)
	defer frontend.destroy_frontend(&fe)

	fmt.println("Translate: Parsing source...")
	tree, parse_err := frontend.parse(&fe, source_code)
	if parse_err.error != .None {
		result.success = false
		result.error = .ParseError
		return result
	}
	defer frontend.destroy_tree(tree)

	program: ^ir.Program
	conv_err: frontend.FrontendError

	switch from {
	case .Bash:
		program, conv_err = frontend.bash_to_ir(&arena, tree, source_code)
	case .Zsh:
		result.success = false
		result.error = .ConversionError
		return result
	case .Fish:
		result.success = false
		result.error = .ConversionError
		return result
	case .POSIX:
		result.success = false
		result.error = .ConversionError
		return result
	}

	if conv_err.error != .None {
		result.success = false
		result.error = .ConversionError
		return result
	}

	fmt.println("Translate: Validating IR...")
	validation_err: ir.ValidatorError = ir.validate_program(program)
	if validation_err.error != .None {
		result.success = false
		result.error = .ValidationError
		return result
	}

	fmt.println("Translate: Creating backend...")
	be := backend.create_backend(to)
	defer backend.destroy_backend(&be)

	fmt.println("Translate: Emitting code...")
	output := backend.emit(&be, program, mem.arena_allocator(&arena.arena))
	fmt.printf("Translate: Emission finished. Output length: %d\n", len(output))
	fmt.printf("Translate: Output content: '%s'\n", output)

	fmt.println("Translate: Assigning output...")
	result.output = output
	fmt.printf("Translate: Result output length: %d\n", len(result.output))
	fmt.printf("Translate: Result output content: '%s'\n", result.output)
	return result
}

detect_shell :: proc(code: string) -> ShellDialect {
	return .Bash
}

detect_shell_from_path :: proc(filepath: string, code: string) -> ShellDialect {
	return .Bash
}

// Main entry point - ShellX is a library, not a CLI tool.
// Use the API: translate(), detect_shell()
main :: proc() {
	fmt.println("ShellX is a library package.")
	fmt.println("Import it with: import \"shellx\"")
	fmt.println("Use: shellx.translate() or shellx.detect_shell()")
}
