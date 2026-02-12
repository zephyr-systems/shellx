package ir

// ShellFeatureKind represents different shell-specific features
ShellFeatureKind :: enum {
	ParameterExpansion, // ${var:-default}, ${#var}, etc.
	ProcessSubstitution, // <(command), >(command)
	CommandSubstitution, // $(command), `command`
	Globbing, // *, ?, [abc], {a,b,c}
	HereDocument, // <<, <<-, <<<
}

// ParameterModifier represents different parameter expansion modifiers
ParameterModifier :: enum {
	None,
	DefaultValue, // ${var:-default}
	AssignDefault, // ${var:=default}
	ErrorIfUnset, // ${var:?message}
	AlternativeValue, // ${var:+alternative}
	Length, // ${#var}
	Substring, // ${var:offset:length}
	Replace, // ${var/pattern/replacement}
	ReplaceAll, // ${var//pattern/replacement}
	RemovePrefix, // ${var#pattern}
	RemovePrefixAll, // ${var##pattern}
	RemoveSuffix, // ${var%pattern}
	RemoveSuffixAll, // ${var%%pattern}
}

// ParameterExpansionData represents parameter expansion operations
// Example: ${var:-default}, ${#var}, ${var:1:3}
ParameterExpansionData :: struct {
	variable:      string,
	modifier:      ParameterModifier,
	default_value: string, // For :- and :=
	error_message: string, // For :?
	alternative:   string, // For :+
	offset:        int, // For substring
	length:        int, // For substring
	pattern:       string, // For replace/remove
	replacement:   string, // For replace
}

// ProcessSubstitutionDirection represents the direction of process substitution
ProcessSubstitutionDirection :: enum {
	Input, // <(command) - read from command
	Output, // >(command) - write to command
}

// ProcessSubstitutionData represents process substitution
// Example: <(command), >(command)
ProcessSubstitutionData :: struct {
	command:   string,
	direction: ProcessSubstitutionDirection,
}

// CommandSubstitutionKind represents the syntax used
CommandSubstitutionKind :: enum {
	DollarParen, // $(command)
	Backtick, // `command`
}

// CommandSubstitutionData represents command substitution
// Example: $(command), `command`
CommandSubstitutionData :: struct {
	command: string,
	kind:    CommandSubstitutionKind,
}

// GlobbingKind represents different types of glob patterns
GlobbingKind :: enum {
	Any, // * - match any string
	Single, // ? - match single character
	CharClass, // [abc] - match any character in class
	NegatedClass, // [^abc] - match any character not in class
	Brace, // {a,b,c} - match any alternative
}

// GlobbingData represents globbing patterns
// Example: *.txt, file?.log, [abc].sh, {*.txt,*.md}
GlobbingData :: struct {
	pattern: string,
	kind:    GlobbingKind,
}

// HereDocKind represents different types of here documents
HereDocKind :: enum {
	Standard, // << DELIMITER
	StripTabs, // <<- DELIMITER (strip leading tabs)
	HereString, // <<< "string"
}

// HereDocData represents here documents and here strings
HereDocData :: struct {
	delimiter: string, // Empty for here strings
	content:   string,
	kind:      HereDocKind,
}

// ShellSpecificData is a union of all shell-specific feature data types
ShellSpecificData :: union {
	ParameterExpansionData,
	ProcessSubstitutionData,
	CommandSubstitutionData,
	GlobbingData,
	HereDocData,
}

// ShellSpecific represents a shell-specific feature in the IR
// This is used to track features that may not be portable across dialects
ShellSpecific :: struct {
	kind: ShellFeatureKind,
	data: ShellSpecificData,
}

// ShellSpecificList is a collection of shell-specific features
ShellSpecificList :: struct {
	features: [dynamic]ShellSpecific,
}

// create_shell_specific_list creates a new list for tracking shell features
create_shell_specific_list :: proc() -> ShellSpecificList {
	return ShellSpecificList{features = make([dynamic]ShellSpecific)}
}

// add_parameter_expansion adds a parameter expansion feature
add_parameter_expansion :: proc(list: ^ShellSpecificList, data: ParameterExpansionData) {
	append(&list.features, ShellSpecific{kind = .ParameterExpansion, data = data})
}

// add_process_substitution adds a process substitution feature
add_process_substitution :: proc(list: ^ShellSpecificList, data: ProcessSubstitutionData) {
	append(&list.features, ShellSpecific{kind = .ProcessSubstitution, data = data})
}

// add_command_substitution adds a command substitution feature
add_command_substitution :: proc(list: ^ShellSpecificList, data: CommandSubstitutionData) {
	append(&list.features, ShellSpecific{kind = .CommandSubstitution, data = data})
}

// add_globbing adds a globbing feature
add_globbing :: proc(list: ^ShellSpecificList, data: GlobbingData) {
	append(&list.features, ShellSpecific{kind = .Globbing, data = data})
}

// add_here_document adds a here document feature
add_here_document :: proc(list: ^ShellSpecificList, data: HereDocData) {
	append(&list.features, ShellSpecific{kind = .HereDocument, data = data})
}

// has_feature checks if a specific feature kind exists in the list
has_feature :: proc(list: ^ShellSpecificList, kind: ShellFeatureKind) -> bool {
	for feature in list.features {
		if feature.kind == kind {
			return true
		}
	}
	return false
}

// count_feature returns the count of a specific feature kind
count_feature :: proc(list: ^ShellSpecificList, kind: ShellFeatureKind) -> int {
	count := 0
	for feature in list.features {
		if feature.kind == kind {
			count += 1
		}
	}
	return count
}
