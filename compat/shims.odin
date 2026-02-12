package compat

import "../ir"
import "core:fmt"
import "core:strings"

// ShimType represents different types of compatibility shims
ShimType :: enum {
	ArrayToList, // Bash array -> Fish list
	ParameterExpansion, // Bash ${var:-default} -> Fish equivalent
	ProcessSubstitution, // Bash <(cmd) -> Fish temp file workaround
}

// Shim represents a compatibility shim
Shim :: struct {
	name:        string,
	type:        ShimType,
	code:        string,
	description: string,
}

// ShimRegistry contains all available shims
ShimRegistry :: struct {
	shims: [dynamic]Shim,
}

// create_shim_registry creates a new shim registry
create_shim_registry :: proc() -> ShimRegistry {
	return ShimRegistry{shims = make([dynamic]Shim)}
}

// destroy_shim_registry cleans up the registry
destroy_shim_registry :: proc(registry: ^ShimRegistry) {
	delete(registry.shims)
}

// add_shim adds a shim to the registry
add_shim :: proc(registry: ^ShimRegistry, shim: Shim) {
	append(&registry.shims, shim)
}

// generate_array_shim generates a shim for array -> list conversion
// Bash: arr=(one two three)
// Fish: set arr one two three
generate_array_shim :: proc(var_name: string, values: []string) -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	strings.write_string(&builder, "set ")
	strings.write_string(&builder, var_name)

	for value in values {
		strings.write_byte(&builder, ' ')
		strings.write_string(&builder, value)
	}

	return strings.to_string(builder)
}

// generate_parameter_expansion_shim generates Fish equivalent for Bash parameter expansion
// Handles: ${var:-default}, ${var:=default}, ${var:?error}, ${var:+alt}, ${#var}
generate_parameter_expansion_shim :: proc(expansion: ParameterExpansionData) -> string {
	switch expansion.modifier {
	case .DefaultValue:
		// ${var:-default} -> if not set $var; or echo $var; else; echo default; end
		return fmt.tprintf(
			"if not set %s; or echo $%s; else; echo %s; end",
			expansion.variable,
			expansion.variable,
			expansion.default_value,
		)

	case .Length:
		// ${#var} -> string length $var
		return fmt.tprintf("string length $%s", expansion.variable)

	case .Substring:
		// ${var:offset:length} -> string sub -s offset -l length $var
		return fmt.tprintf(
			"string sub -s %d -l %d $%s",
			expansion.offset,
			expansion.length,
			expansion.variable,
		)

	case:
		// Other modifiers not easily supported in Fish
		return fmt.tprintf("$%s", expansion.variable)
	}
}

// generate_process_substitution_shim generates Fish workaround for process substitution
// Bash: cmd <(other_cmd)
// Fish workaround using temp files
generate_process_substitution_shim :: proc(
	command: string,
	direction: ProcessSubstitutionDirection,
) -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	// Generate temp file creation
	temp_var := "__temp_file"

	strings.write_string(&builder, "set ")
	strings.write_string(&builder, temp_var)
	strings.write_string(&builder, " (mktemp)\n")

	switch direction {
	case .Input:
		// <(command) - write command output to temp file
		strings.write_string(&builder, command)
		strings.write_string(&builder, " > $")
		strings.write_string(&builder, temp_var)
		strings.write_string(&builder, "\n")

	case .Output:
		// >(command) - read from temp file into command
		strings.write_string(&builder, "# Output to ")
		strings.write_string(&builder, command)
		strings.write_string(&builder, " from $")
		strings.write_string(&builder, temp_var)
		strings.write_string(&builder, "\n")
	}

	// Cleanup
	strings.write_string(&builder, "rm -f $")
	strings.write_string(&builder, temp_var)

	return strings.to_string(builder)
}

// needs_shim checks if a feature needs a shim for the target dialect
needs_shim :: proc(feature: string, from: ir.ShellDialect, to: ir.ShellDialect) -> bool {
	// Only Bash/Zsh -> Fish needs shims currently
	if !(from == .Bash || from == .Zsh) || to != .Fish {
		return false
	}

	switch feature {
	case "arrays", "parameter_expansion":
		return true
	case "process_substitution":
		return true
	case:
		return false
	}
}

// get_shim_description returns a human-readable description of what the shim does
get_shim_description :: proc(shim_type: ShimType) -> string {
	switch shim_type {
	case .ArrayToList:
		return "Converts Bash arrays to Fish lists"
	case .ParameterExpansion:
		return "Converts Bash parameter expansion to Fish string builtin"
	case .ProcessSubstitution:
		return "Converts process substitution to temp file workaround"
	case:
		return "Unknown shim type"
	}
}
