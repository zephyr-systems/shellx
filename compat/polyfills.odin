package compat

import "../ir"
import "core:fmt"
import "core:strings"

// PolyfillType represents different types of polyfills
PolyfillType :: enum {
	TestBuiltin,        // Emulate [[ ]] test syntax for POSIX
	ArrayBuiltin,       // Emulate array operations for POSIX
	ReadBuiltin,        // Emulate read -a for POSIX
	GlobBuiltin,        // Emulate extended glob patterns
}

// Polyfill represents a polyfill implementation
Polyfill :: struct {
	name:        string,
	type:        PolyfillType,
	code:        string,
	description: string,
	requires:    []string, // Other polyfills this depends on
}

// PolyfillRegistry contains all available polyfills
PolyfillRegistry :: struct {
	polyfills: [dynamic]Polyfill,
}

// create_polyfill_registry creates a new polyfill registry
create_polyfill_registry :: proc() -> PolyfillRegistry {
	return PolyfillRegistry{polyfills = make([dynamic]Polyfill)}
}

// destroy_polyfill_registry cleans up the registry
destroy_polyfill_registry :: proc(registry: ^PolyfillRegistry) {
	for polyfill in registry.polyfills {
		delete(polyfill.requires)
	}
	delete(registry.polyfills)
}

// add_polyfill adds a polyfill to the registry
add_polyfill :: proc(registry: ^PolyfillRegistry, polyfill: Polyfill) {
	append(&registry.polyfills, polyfill)
}

// generate_test_polyfill generates a polyfill for [[ ]] test syntax
// For POSIX shells that don't have [[ ]]
generate_test_polyfill :: proc() -> string {
	return strings.trim_space(`
# Polyfill for [[ ]] test syntax
__shellx_test_double_bracket() {
  local __expr="$*"
  local __result=1
  
  # Simple emulation - in practice this would be much more complex
  case "$__expr" in
    *"=="*)
      # String equality
      local __left="${__expr%%==*}"
      local __right="${__expr#*==}"
      [ "$__left" = "$__right" ] && __result=0
      ;;
    *"-eq"*)
      # Numeric equality
      local __left="${__expr%%-eq*}"
      local __right="${__expr#*-eq}"
      [ "$__left" -eq "$__right" ] && __result=0
      ;;
    *"-z"*)
      # Zero length string
      local __var="${__expr#*-z }"
      [ -z "$__var" ] && __result=0
      ;;
    *"-n"*)
      # Non-zero length string
      local __var="${__expr#*-n }"
      [ -n "$__var" ] && __result=0
      ;;
    *)
      # Fall back to regular test
      test $__expr && __result=0
      ;;
  esac
  
  return $__result
}

# Alias [[ to our polyfill if it doesn't exist
if ! command -v '[[' >/dev/null 2>&1; then
  [[() { __shellx_test_double_bracket "$@"; }
fi
`)
}

// generate_array_polyfill generates polyfill for array operations in POSIX
generate_array_polyfill :: proc() -> string {
	return strings.trim_space(`
# Polyfill for array operations in POSIX shells
__shellx_array_create() {
  local __name="$1"
  shift
  # Store array as space-separated string with quoting
  local __value=""
  for __item in "$@"; do
    __value="$__value \"$__item\""
  done
  eval "$__name=\"$__value\""
}

__shellx_array_get() {
  local __name="$1"
  local __index="$2"
  eval "local __array=\$$__name"
  
  # Convert to positional parameters
  set -- $__array
  local __count=1
  for __item in "$@"; do
    if [ $__count -eq $__index ]; then
      echo "$__item"
      return 0
    fi
    __count=$((__count + 1))
  done
  return 1
}

__shellx_array_length() {
  local __name="$1"
  eval "local __array=\$$__name"
  set -- $__array
  echo $#
}
`)
}

// generate_read_array_polyfill generates polyfill for read -a in POSIX
generate_read_array_polyfill :: proc() -> string {
	return strings.trim_space(`
# Polyfill for read -a (read into array) in POSIX shells
__shellx_read_array() {
  local __array_name="$1"
  shift
  
  # Read line
  IFS=$' \t\n' read -r __line || return $?
  
  # Split into array
  __shellx_array_create "$__array_name" $__line
}
`)
}

// generate_glob_polyfill generates polyfill for extended glob patterns
generate_glob_polyfill :: proc() -> string {
	return strings.trim_space(`
# Polyfill for extended glob patterns in POSIX shells
__shellx_extended_glob() {
  local __pattern="$1"
  local __result=""
  
  # Simple emulation - would need more complex pattern matching
  case "$__pattern" in
    *"**"*)
      # Recursive glob - use find
      __result=$(find . -name "${__pattern//**/*}" 2>/dev/null)
      ;;
    *"@("*)")
      # Alternation - expand manually
      local __inner="${__pattern#*@(}"
      __inner="${__inner%)*}"
      IFS='|' read -r __a __b __c __rest <<EOF
$__inner
EOF
      for __opt in "$__a" "$__b" "$__c" "$__rest"; do
        [ -n "$__opt" ] && __result="$__result $(echo $__opt)"
      done
      ;;
    *)
      # Regular glob
      __result=$(echo $__pattern)
      ;;
  esac
  
  echo "$__result" | tr ' ' '\n' | grep -v '^$'
}
`)
}

// needs_polyfill checks if a feature needs a polyfill for the target dialect
needs_polyfill :: proc(feature: string, to: ir.ShellDialect) -> bool {
	switch feature {
	case "test_double_bracket":
		return to == .POSIX
	case "array_operations":
		return to == .POSIX
	case "read_array":
		return to == .POSIX
	case "extended_glob":
		return to == .POSIX
	case "associative_array":
		return to == .POSIX || to == .Fish
	}
	return false
}

// get_polyfill returns the appropriate polyfill code
get_polyfill :: proc(feature: string) -> string {
	switch feature {
	case "test_double_bracket":
		return generate_test_polyfill()
	case "array_operations":
		return generate_array_polyfill()
	case "read_array":
		return generate_read_array_polyfill()
	case "extended_glob":
		return generate_glob_polyfill()
	case:
		return ""
	}
}

// build_polyfill_prelude builds all required polyfills for a translation
build_polyfill_prelude :: proc(
	required_polyfills: []string,
	to: ir.ShellDialect,
	allocator := context.allocator,
) -> string {
	if len(required_polyfills) == 0 {
		return ""
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	seen := make(map[string]bool, context.temp_allocator)
	defer delete(seen)

	strings.write_string(&builder, "# shellx polyfills\n")
	strings.write_string(&builder, "# These emulate missing shell features\n\n")
	
	for feature in required_polyfills {
		if seen[feature] {
			continue
		}
		seen[feature] = true

		code := get_polyfill(feature)
		if code == "" {
			continue
		}
		strings.write_string(&builder, "# polyfill: ")
		strings.write_string(&builder, feature)
		strings.write_byte(&builder, '\n')
		strings.write_string(&builder, code)
		strings.write_string(&builder, "\n\n")
	}

	return strings.clone(strings.to_string(builder), allocator)
}

// detect_required_polyfills analyzes IR to detect features needing polyfills
detect_required_polyfills :: proc(
	program: ^ir.Program,
	to: ir.ShellDialect,
	allocator := context.allocator,
) -> []string {
	required := make([dynamic]string, allocator)
	
	// This would analyze the IR to detect which features are used
	// For now, return based on target dialect
	switch to {
	case .POSIX:
		// POSIX needs polyfills for many Bash features
		append(&required, "test_double_bracket")
		append(&required, "array_operations")
		append(&required, "read_array")
		append(&required, "extended_glob")
	case .Fish:
		// Fish might need polyfills for associative arrays
		append(&required, "array_operations") // For associative array emulation
	case .Bash, .Zsh:
		// No baseline polyfills required for Bash/Zsh targets.
	}
	
	return required[:]
}
