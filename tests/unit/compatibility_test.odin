package unit_tests

import "../../compat"
import "../../ir"
import "core:testing"

// 22.1: Test capability detection for each dialect

@(test)
test_bash_capabilities :: proc(t: ^testing.T) {
	if !should_run_test("test_bash_capabilities") { return }
	caps := compat.get_capabilities(.Bash)

	// Bash should support all features
	testing.expect(t, caps.arrays.supported, "Bash should support arrays")
	testing.expect(t, caps.associative_arrays.supported, "Bash should support associative arrays")
	testing.expect(
		t,
		caps.process_substitution.supported,
		"Bash should support process substitution",
	)
	testing.expect(
		t,
		caps.command_substitution.supported,
		"Bash should support command substitution",
	)
	testing.expect(t, caps.brace_expansion.supported, "Bash should support brace expansion")
	testing.expect(
		t,
		caps.parameter_expansion.supported,
		"Bash should support parameter expansion",
	)
	testing.expect(t, caps.globbing.supported, "Bash should support globbing")
	testing.expect(t, caps.here_documents.supported, "Bash should support here documents")
	testing.expect(t, caps.local_variables.supported, "Bash should support local variables")
	testing.expect(t, caps.functions.supported, "Bash should support functions")
	testing.expect(t, caps.pipelines.supported, "Bash should support pipelines")
}

@(test)
test_zsh_capabilities :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_capabilities") { return }
	caps := compat.get_capabilities(.Zsh)

	// Zsh should support all features (Bash-compatible)
	testing.expect(t, caps.arrays.supported, "Zsh should support arrays")
	testing.expect(t, caps.associative_arrays.supported, "Zsh should support associative arrays")
	testing.expect(
		t,
		caps.process_substitution.supported,
		"Zsh should support process substitution",
	)
	testing.expect(
		t,
		caps.command_substitution.supported,
		"Zsh should support command substitution",
	)
	testing.expect(t, caps.brace_expansion.supported, "Zsh should support brace expansion")
	testing.expect(t, caps.parameter_expansion.supported, "Zsh should support parameter expansion")
	testing.expect(t, caps.globbing.supported, "Zsh should support globbing")
	testing.expect(t, caps.here_documents.supported, "Zsh should support here documents")
	testing.expect(t, caps.local_variables.supported, "Zsh should support local variables")
	testing.expect(t, caps.functions.supported, "Zsh should support functions")
	testing.expect(t, caps.pipelines.supported, "Zsh should support pipelines")
}

@(test)
test_fish_capabilities :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_capabilities") { return }
	caps := compat.get_capabilities(.Fish)

	// Fish does NOT support many features
	testing.expect(t, !caps.arrays.supported, "Fish should NOT support arrays")
	testing.expect(
		t,
		!caps.associative_arrays.supported,
		"Fish should NOT support associative arrays",
	)
	testing.expect(
		t,
		!caps.process_substitution.supported,
		"Fish should NOT support process substitution",
	)
	testing.expect(
		t,
		caps.command_substitution.supported,
		"Fish should support command substitution (parentheses)",
	)
	testing.expect(t, caps.brace_expansion.supported, "Fish should support brace expansion")
	testing.expect(
		t,
		!caps.parameter_expansion.supported,
		"Fish should NOT support parameter expansion",
	)
	testing.expect(t, caps.globbing.supported, "Fish should support globbing")
	testing.expect(t, !caps.here_documents.supported, "Fish should NOT support here documents")
	testing.expect(t, caps.local_variables.supported, "Fish should support local variables")
	testing.expect(t, caps.functions.supported, "Fish should support functions")
	testing.expect(t, caps.pipelines.supported, "Fish should support pipelines")
}

@(test)
test_posix_capabilities :: proc(t: ^testing.T) {
	if !should_run_test("test_posix_capabilities") { return }
	caps := compat.get_capabilities(.POSIX)

	// POSIX is a subset - many features missing
	testing.expect(t, !caps.arrays.supported, "POSIX should NOT support arrays")
	testing.expect(
		t,
		!caps.associative_arrays.supported,
		"POSIX should NOT support associative arrays",
	)
	testing.expect(
		t,
		!caps.process_substitution.supported,
		"POSIX should NOT support process substitution",
	)
	testing.expect(
		t,
		caps.command_substitution.supported,
		"POSIX should support command substitution (backticks)",
	)
	testing.expect(t, !caps.brace_expansion.supported, "POSIX should NOT support brace expansion")
	testing.expect(
		t,
		caps.parameter_expansion.supported,
		"POSIX should support basic parameter expansion",
	)
	testing.expect(t, caps.globbing.supported, "POSIX should support globbing")
	testing.expect(t, caps.here_documents.supported, "POSIX should support here documents")
	testing.expect(t, !caps.local_variables.supported, "POSIX should NOT support local variables")
	testing.expect(t, caps.functions.supported, "POSIX should support functions")
	testing.expect(t, caps.pipelines.supported, "POSIX should support pipelines")
}

// 22.2: Test compatibility comparison

@(test)
test_bash_to_fish_incompatibility :: proc(t: ^testing.T) {
	if !should_run_test("test_bash_to_fish_incompatibility") { return }
	differences := compat.compare_capabilities(.Bash, .Fish, context.temp_allocator)
	defer delete(differences)

	// Bash → Fish should have several incompatibilities
	testing.expect(
		t,
		len(differences) >= 3,
		"Should have at least 3 incompatibilities (arrays, assoc arrays, process substitution)",
	)

	// Check for specific features
	has_arrays := false
	has_assoc_arrays := false
	has_process_sub := false

	for diff in differences {
		switch diff.feature {
		case "arrays":
			has_arrays = true
		case "associative_arrays":
			has_assoc_arrays = true
		case "process_substitution":
			has_process_sub = true
		}
	}

	testing.expect(t, has_arrays, "Should detect arrays incompatibility")
	testing.expect(t, has_assoc_arrays, "Should detect associative arrays incompatibility")
	testing.expect(t, has_process_sub, "Should detect process substitution incompatibility")
}

@(test)
test_bash_to_zsh_compatibility :: proc(t: ^testing.T) {
	if !should_run_test("test_bash_to_zsh_compatibility") { return }
	differences := compat.compare_capabilities(.Bash, .Zsh, context.temp_allocator)
	defer delete(differences)

	// Bash → Zsh should have no incompatibilities (Zsh is Bash-compatible)
	testing.expect(t, len(differences) == 0, "Bash to Zsh should have no incompatibilities")
}

@(test)
test_has_unsupported_features :: proc(t: ^testing.T) {
	if !should_run_test("test_has_unsupported_features") { return }
	// Bash → Fish has unsupported features
	testing.expect(
		t,
		compat.has_unsupported_features(.Bash, .Fish),
		"Bash to Fish should have unsupported features",
	)

	// Bash → Zsh has no unsupported features
	testing.expect(
		t,
		!compat.has_unsupported_features(.Bash, .Zsh),
		"Bash to Zsh should have no unsupported features",
	)

	// Bash → POSIX has unsupported features
	testing.expect(
		t,
		compat.has_unsupported_features(.Bash, .POSIX),
		"Bash to POSIX should have unsupported features",
	)
}

// 22.3: Test feature support checking

@(test)
test_check_feature_support :: proc(t: ^testing.T) {
	if !should_run_test("test_check_feature_support") { return }
	// Arrays
	testing.expect(t, compat.check_feature_support(.Bash, "arrays"), "Bash supports arrays")
	testing.expect(
		t,
		!compat.check_feature_support(.Fish, "arrays"),
		"Fish does not support arrays",
	)
	testing.expect(
		t,
		!compat.check_feature_support(.POSIX, "arrays"),
		"POSIX does not support arrays",
	)

	// Process substitution
	testing.expect(
		t,
		compat.check_feature_support(.Bash, "process_substitution"),
		"Bash supports process substitution",
	)
	testing.expect(
		t,
		!compat.check_feature_support(.Fish, "process_substitution"),
		"Fish does not support process substitution",
	)

	// Pipelines (all support)
	testing.expect(t, compat.check_feature_support(.Bash, "pipelines"), "Bash supports pipelines")
	testing.expect(t, compat.check_feature_support(.Zsh, "pipelines"), "Zsh supports pipelines")
	testing.expect(t, compat.check_feature_support(.Fish, "pipelines"), "Fish supports pipelines")
	testing.expect(
		t,
		compat.check_feature_support(.POSIX, "pipelines"),
		"POSIX supports pipelines",
	)

	// Unknown feature
	testing.expect(
		t,
		!compat.check_feature_support(.Bash, "unknown_feature"),
		"Unknown feature returns false",
	)
}

// 22.4: Test shim detection

@(test)
test_needs_shim_detection :: proc(t: ^testing.T) {
	if !should_run_test("test_needs_shim_detection") { return }
	// Bash → Fish needs shims for arrays
	testing.expect(t, compat.needs_shim("arrays", .Bash, .Fish), "Bash arrays need shim for Fish")
	testing.expect(
		t,
		compat.needs_shim("parameter_expansion", .Bash, .Fish),
		"Bash param expansion needs shim for Fish",
	)
	testing.expect(
		t,
		compat.needs_shim("process_substitution", .Bash, .Fish),
		"Bash process substitution needs shim for Fish",
	)

	// Bash → Zsh doesn't need shims
	testing.expect(
		t,
		!compat.needs_shim("arrays", .Bash, .Zsh),
		"Bash to Zsh doesn't need shim for arrays",
	)
	testing.expect(
		t,
		!compat.needs_shim("arrays", .Zsh, .Bash),
		"Zsh to Bash doesn't need shim for arrays",
	)

	// Same dialect doesn't need shims
	testing.expect(
		t,
		!compat.needs_shim("arrays", .Bash, .Bash),
		"Same dialect doesn't need shims",
	)
}

// 22.5: Test shim descriptions

@(test)
test_shim_descriptions :: proc(t: ^testing.T) {
	if !should_run_test("test_shim_descriptions") { return }
	array_desc := compat.get_shim_description(.ArrayToList)
	testing.expect(t, len(array_desc) > 0, "Array shim should have description")
	testing.expect(
		t,
		array_desc != "Unknown shim type",
		"Array shim description should not be unknown",
	)

	param_desc := compat.get_shim_description(.ParameterExpansion)
	testing.expect(t, len(param_desc) > 0, "Parameter expansion shim should have description")

	process_desc := compat.get_shim_description(.ProcessSubstitution)
	testing.expect(t, len(process_desc) > 0, "Process substitution shim should have description")
}

// 22.6: Test shim generation

@(test)
test_generate_array_shim :: proc(t: ^testing.T) {
	if !should_run_test("test_generate_array_shim") { return }
	values := []string{"one", "two", "three"}
	shim := compat.generate_array_shim("myarr", values)
	defer delete(shim)

	testing.expect(
		t,
		shim == "set myarr one two three",
		"Array shim should generate Fish set command",
	)
}

@(test)
test_generate_empty_array_shim :: proc(t: ^testing.T) {
	if !should_run_test("test_generate_empty_array_shim") { return }
	values := []string{}
	shim := compat.generate_array_shim("emptyarr", values)
	defer delete(shim)

	testing.expect(t, shim == "set emptyarr", "Empty array shim should generate bare set command")
}
