package compat

import "../ir"

// FeatureSupport represents a shell feature and its availability
FeatureSupport :: struct {
	name:        string,
	supported:   bool,
	description: string,
}

// ShellCapabilities represents all capabilities for a shell dialect
ShellCapabilities :: struct {
	dialect:              ir.ShellDialect,
	arrays:               FeatureSupport,
	associative_arrays:   FeatureSupport,
	process_substitution: FeatureSupport,
	command_substitution: FeatureSupport,
	brace_expansion:      FeatureSupport,
	parameter_expansion:  FeatureSupport,
	globbing:             FeatureSupport,
	here_documents:       FeatureSupport,
	local_variables:      FeatureSupport,
	functions:            FeatureSupport,
	pipelines:            FeatureSupport,
}

// get_bash_capabilities returns Bash's feature support
get_bash_capabilities :: proc() -> ShellCapabilities {
	return ShellCapabilities {
		dialect = .Bash,
		arrays = FeatureSupport {
			name = "arrays",
			supported = true,
			description = "Indexed arrays: arr=(one two three)",
		},
		associative_arrays = FeatureSupport {
			name = "associative_arrays",
			supported = true,
			description = "Associative arrays: declare -A hash=([key]=value)",
		},
		process_substitution = FeatureSupport {
			name = "process_substitution",
			supported = true,
			description = "Process substitution: <(command), >(command)",
		},
		command_substitution = FeatureSupport {
			name = "command_substitution",
			supported = true,
			description = "Command substitution: $(command) or `command`",
		},
		brace_expansion = FeatureSupport {
			name = "brace_expansion",
			supported = true,
			description = "Brace expansion: {a,b,c}",
		},
		parameter_expansion = FeatureSupport {
			name = "parameter_expansion",
			supported = true,
			description = "Parameter expansion: ${var:-default}, ${#var}, etc.",
		},
		globbing = FeatureSupport {
			name = "globbing",
			supported = true,
			description = "Glob patterns: *, ?, [abc]",
		},
		here_documents = FeatureSupport {
			name = "here_documents",
			supported = true,
			description = "Here documents: << EOF ... EOF",
		},
		local_variables = FeatureSupport {
			name = "local_variables",
			supported = true,
			description = "Local variables in functions: local var=value",
		},
		functions = FeatureSupport {
			name = "functions",
			supported = true,
			description = "Function definitions: function name() { ... }",
		},
		pipelines = FeatureSupport {
			name = "pipelines",
			supported = true,
			description = "Command pipelines: cmd1 | cmd2 | cmd3",
		},
	}
}

// get_zsh_capabilities returns Zsh's feature support
// Zsh is mostly compatible with Bash but has some differences
get_zsh_capabilities :: proc() -> ShellCapabilities {
	return ShellCapabilities {
		dialect = .Zsh,
		arrays = FeatureSupport {
			name = "arrays",
			supported = true,
			description = "Indexed arrays: arr=(one two three)",
		},
		associative_arrays = FeatureSupport {
			name = "associative_arrays",
			supported = true,
			description = "Associative arrays: typeset -A hash=([key]=value)",
		},
		process_substitution = FeatureSupport {
			name = "process_substitution",
			supported = true,
			description = "Process substitution: <(command), >(command)",
		},
		command_substitution = FeatureSupport {
			name = "command_substitution",
			supported = true,
			description = "Command substitution: $(command) or `command`",
		},
		brace_expansion = FeatureSupport {
			name = "brace_expansion",
			supported = true,
			description = "Brace expansion: {a,b,c}",
		},
		parameter_expansion = FeatureSupport {
			name = "parameter_expansion",
			supported = true,
			description = "Extended parameter expansion with Zsh-specific modifiers",
		},
		globbing = FeatureSupport {
			name = "globbing",
			supported = true,
			description = "Extended glob patterns: **/, <->, etc.",
		},
		here_documents = FeatureSupport {
			name = "here_documents",
			supported = true,
			description = "Here documents with additional Zsh features",
		},
		local_variables = FeatureSupport {
			name = "local_variables",
			supported = true,
			description = "Local variables: local var=value or typeset var=value",
		},
		functions = FeatureSupport {
			name = "functions",
			supported = true,
			description = "Functions: function name { ... } or name() { ... }",
		},
		pipelines = FeatureSupport {
			name = "pipelines",
			supported = true,
			description = "Command pipelines: cmd1 | cmd2 | cmd3",
		},
	}
}

// get_fish_capabilities returns Fish's feature support
// Fish intentionally does not support many Bash/Zsh features
get_fish_capabilities :: proc() -> ShellCapabilities {
	return ShellCapabilities {
		dialect = .Fish,
		arrays = FeatureSupport {
			name = "arrays",
			supported = false,
			description = "Arrays not supported. Use lists instead: set arr one two",
		},
		associative_arrays = FeatureSupport {
			name = "associative_arrays",
			supported = false,
			description = "Associative arrays not supported in Fish",
		},
		process_substitution = FeatureSupport {
			name = "process_substitution",
			supported = false,
			description = "Process substitution not supported. Use temp files workaround",
		},
		command_substitution = FeatureSupport {
			name = "command_substitution",
			supported = true,
			description = "Command substitution only with parentheses: (command)",
		},
		brace_expansion = FeatureSupport {
			name = "brace_expansion",
			supported = true,
			description = "Brace expansion supported: {a,b,c}",
		},
		parameter_expansion = FeatureSupport {
			name = "parameter_expansion",
			supported = false,
			description = "Bash-style parameter expansion not supported. Use string builtin",
		},
		globbing = FeatureSupport {
			name = "globbing",
			supported = true,
			description = "Glob patterns supported: *, ?, **",
		},
		here_documents = FeatureSupport {
			name = "here_documents",
			supported = false,
			description = "Here documents not supported",
		},
		local_variables = FeatureSupport {
			name = "local_variables",
			supported = true,
			description = "Local variables: set -l var value",
		},
		functions = FeatureSupport {
			name = "functions",
			supported = true,
			description = "Functions: function name ... end",
		},
		pipelines = FeatureSupport {
			name = "pipelines",
			supported = true,
			description = "Command pipelines: cmd1 | cmd2 | cmd3",
		},
	}
}

// get_posix_capabilities returns POSIX shell capabilities
// POSIX is a subset of Bash - many Bash features are not in POSIX
get_posix_capabilities :: proc() -> ShellCapabilities {
	return ShellCapabilities {
		dialect = .POSIX,
		arrays = FeatureSupport {
			name = "arrays",
			supported = false,
			description = "Arrays not in POSIX. Use positional params or string manipulation",
		},
		associative_arrays = FeatureSupport {
			name = "associative_arrays",
			supported = false,
			description = "Associative arrays not in POSIX",
		},
		process_substitution = FeatureSupport {
			name = "process_substitution",
			supported = false,
			description = "Process substitution not in POSIX",
		},
		command_substitution = FeatureSupport {
			name = "command_substitution",
			supported = true,
			description = "Command substitution: `command` (backticks only, not $())",
		},
		brace_expansion = FeatureSupport {
			name = "brace_expansion",
			supported = false,
			description = "Brace expansion not in POSIX",
		},
		parameter_expansion = FeatureSupport {
			name = "parameter_expansion",
			supported = true,
			description = "Basic parameter expansion: ${var}, ${var:-default}",
		},
		globbing = FeatureSupport {
			name = "globbing",
			supported = true,
			description = "Basic glob patterns: *, ?",
		},
		here_documents = FeatureSupport {
			name = "here_documents",
			supported = true,
			description = "Here documents: << EOF",
		},
		local_variables = FeatureSupport {
			name = "local_variables",
			supported = false,
			description = "Local keyword not in POSIX. Use subshells instead",
		},
		functions = FeatureSupport {
			name = "functions",
			supported = true,
			description = "Functions: name() { ... }",
		},
		pipelines = FeatureSupport {
			name = "pipelines",
			supported = true,
			description = "Command pipelines: cmd1 | cmd2",
		},
	}
}

// get_capabilities returns capabilities for the specified dialect
get_capabilities :: proc(dialect: ir.ShellDialect) -> ShellCapabilities {
	switch dialect {
	case .Bash:
		return get_bash_capabilities()
	case .Zsh:
		return get_zsh_capabilities()
	case .Fish:
		return get_fish_capabilities()
	case .POSIX:
		return get_posix_capabilities()
	case:
		return get_bash_capabilities() // Default to Bash
	}
}

// CapabilityDifference represents a feature difference between dialects
CapabilityDifference :: struct {
	feature:      string,
	from_support: bool,
	to_support:   bool,
	description:  string,
}

// compare_capabilities compares capabilities between two dialects
// Returns a list of features that differ (unsupported in target)
compare_capabilities :: proc(
	from: ir.ShellDialect,
	to: ir.ShellDialect,
	allocator := context.allocator,
) -> []CapabilityDifference {
	from_caps := get_capabilities(from)
	to_caps := get_capabilities(to)

	differences := make([dynamic]CapabilityDifference, allocator)

	// Compare each feature
	compare_feature :: proc(
		diffs: ^[dynamic]CapabilityDifference,
		from_feat: FeatureSupport,
		to_feat: FeatureSupport,
	) {
		if from_feat.supported && !to_feat.supported {
			append(
				diffs,
				CapabilityDifference {
					feature = from_feat.name,
					from_support = from_feat.supported,
					to_support = to_feat.supported,
					description = from_feat.description,
				},
			)
		}
	}

	compare_feature(&differences, from_caps.arrays, to_caps.arrays)
	compare_feature(&differences, from_caps.associative_arrays, to_caps.associative_arrays)
	compare_feature(&differences, from_caps.process_substitution, to_caps.process_substitution)
	compare_feature(&differences, from_caps.command_substitution, to_caps.command_substitution)
	compare_feature(&differences, from_caps.brace_expansion, to_caps.brace_expansion)
	compare_feature(&differences, from_caps.parameter_expansion, to_caps.parameter_expansion)
	compare_feature(&differences, from_caps.globbing, to_caps.globbing)
	compare_feature(&differences, from_caps.here_documents, to_caps.here_documents)
	compare_feature(&differences, from_caps.local_variables, to_caps.local_variables)
	compare_feature(&differences, from_caps.functions, to_caps.functions)
	compare_feature(&differences, from_caps.pipelines, to_caps.pipelines)

	return differences[:]
}

// has_unsupported_features checks if translation would lose features
has_unsupported_features :: proc(from: ir.ShellDialect, to: ir.ShellDialect) -> bool {
	differences := compare_capabilities(from, to, context.temp_allocator)
	return len(differences) > 0
}

// get_feature_support checks if a specific feature is supported
check_feature_support :: proc(dialect: ir.ShellDialect, feature_name: string) -> bool {
	caps := get_capabilities(dialect)

	switch feature_name {
	case "arrays":
		return caps.arrays.supported
	case "associative_arrays":
		return caps.associative_arrays.supported
	case "process_substitution":
		return caps.process_substitution.supported
	case "command_substitution":
		return caps.command_substitution.supported
	case "brace_expansion":
		return caps.brace_expansion.supported
	case "parameter_expansion":
		return caps.parameter_expansion.supported
	case "globbing":
		return caps.globbing.supported
	case "here_documents":
		return caps.here_documents.supported
	case "local_variables":
		return caps.local_variables.supported
	case "functions":
		return caps.functions.supported
	case "pipelines":
		return caps.pipelines.supported
	case:
		return false
	}
}
