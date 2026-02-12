package utils

import "core:strings"
import "core:unicode/utf8"

// EdgeCaseType categorizes different types of edge cases
EdgeCaseType :: enum {
	None,
	EmptyScript,
	WhitespaceOnly,
	CommentsOnly,
	MalformedSyntax,
	MismatchedQuotes,
	UnicodeContent,
	DeeplyNested,
	LargeScript,
	ComplexPipeline,
}

// EdgeCaseInfo provides information about detected edge cases
EdgeCaseInfo :: struct {
	type:        EdgeCaseType,
	detected:    bool,
	description: string,
	suggestion:  string,
}

// ScriptCharacteristics captures various metrics about a script
ScriptCharacteristics :: struct {
	line_count:           int,
	char_count:           int,
	non_whitespace_chars: int,
	comment_lines:        int,
	code_lines:           int,
	max_nesting_depth:    int,
	has_unicode:          bool,
	has_special_chars:    bool,
	quote_balance:        bool,
	pipeline_commands:    int,
}

// is_empty_script checks if the source is completely empty
is_empty_script :: proc(source: string) -> bool {
	return len(source) == 0
}

// is_whitespace_only checks if the source contains only whitespace
is_whitespace_only :: proc(source: string) -> bool {
	if len(source) == 0 {
		return true
	}
	for c in source {
		if c != ' ' && c != '\t' && c != '\n' && c != '\r' {
			return false
		}
	}
	return true
}

// is_comments_only checks if the source contains only comments and whitespace
is_comments_only :: proc(source: string) -> bool {
	if len(source) == 0 {
		return true
	}

	lines := strings.split_lines(source)
	defer delete(lines)

	has_comment := false
	for line in lines {
		trimmed := strings.trim_space(line)
		if trimmed == "" {
			continue
		}
		// Skip shebang lines
		if strings.has_prefix(trimmed, "#!") {
			continue
		}
		// Check for comment lines (starting with #)
		if strings.has_prefix(trimmed, "#") {
			has_comment = true
			continue
		}
		// Non-comment, non-whitespace content found
		return false
	}

	return has_comment
}

// has_mismatched_quotes checks for unbalanced quotes in the source
has_mismatched_quotes :: proc(source: string) -> (bool, string) {
	in_single_quote := false
	in_double_quote := false
	in_escape := false

	for i := 0; i < len(source); i += 1 {
		c := source[i]

		if in_escape {
			in_escape = false
			continue
		}

		if c == '\\' && !in_single_quote {
			in_escape = true
			continue
		}

		if c == '\'' && !in_double_quote {
			in_single_quote = !in_single_quote
		}

		if c == '"' && !in_single_quote {
			in_double_quote = !in_double_quote
		}
	}

	if in_single_quote {
		return true, "Unclosed single quote"
	}
	if in_double_quote {
		return true, "Unclosed double quote"
	}

	return false, ""
}

// has_unicode_content checks if the source contains Unicode characters
has_unicode_content :: proc(source: string) -> bool {
	for _, index in source {
		r, size := utf8.decode_rune_in_string(source[index:])
		if r == utf8.RUNE_ERROR && size == 1 {
			// Invalid UTF-8 sequence
			continue
		}
		if r > 127 {
			return true
		}
	}
	return false
}

// calculate_nesting_depth calculates the maximum nesting depth of control structures
calculate_nesting_depth :: proc(source: string) -> int {
	lines := strings.split_lines(source)
	defer delete(lines)

	max_depth := 0
	current_depth := 0

	for line in lines {
		trimmed := strings.trim_space(line)
		if trimmed == "" {
			continue
		}

		// Check for control structure starts (simplified heuristic)
		keywords_in := []string{"if", "for", "while", "until", "case", "select"}
		keywords_out := []string{"fi", "done", "esac", "end"}

		// Check for opening keywords
		for keyword in keywords_in {
			if strings.has_prefix(trimmed, keyword) {
				// Make sure it's not part of a larger word
				after_keyword := strings.trim_prefix(trimmed, keyword)
				if len(after_keyword) == 0 || after_keyword[0] == ' ' || after_keyword[0] == '(' {
					current_depth += 1
					if current_depth > max_depth {
						max_depth = current_depth
					}
					break
				}
			}
		}

		// Check for closing keywords
		for keyword in keywords_out {
			if strings.has_prefix(trimmed, keyword) {
				after_keyword := strings.trim_prefix(trimmed, keyword)
				if len(after_keyword) == 0 || after_keyword[0] == ' ' || after_keyword[0] == ';' {
					current_depth -= 1
					if current_depth < 0 {
						current_depth = 0
					}
					break
				}
			}
		}
	}

	return max_depth
}

// count_pipeline_commands counts the maximum number of commands in a pipeline
count_pipeline_commands :: proc(source: string) -> int {
	lines := strings.split_lines(source)
	defer delete(lines)

	max_commands := 0

	for line in lines {
		trimmed := strings.trim_space(line)
		if trimmed == "" {
			continue
		}

		// Count pipes in the line
		pipe_count := 0
		in_string := false
		string_char: byte = 0

		for i := 0; i < len(trimmed); i += 1 {
			c := trimmed[i]

			if !in_string && (c == '\'' || c == '"') {
				in_string = true
				string_char = c
				continue
			}

			if in_string && c == string_char {
				in_string = false
				continue
			}

			if !in_string && c == '|' {
				// Check it's not || (OR operator)
				if i + 1 < len(trimmed) && trimmed[i + 1] == '|' {
					i += 1 // Skip the second |
					continue
				}
				pipe_count += 1
			}
		}

		// Number of commands is pipes + 1
		commands := pipe_count + 1
		if commands > max_commands {
			max_commands = commands
		}
	}

	return max_commands
}

// analyze_script performs comprehensive analysis of script characteristics
analyze_script :: proc(source: string) -> ScriptCharacteristics {
	chars := ScriptCharacteristics{}

	// Basic counts
	chars.char_count = len(source)

	lines := strings.split_lines(source)
	defer delete(lines)
	chars.line_count = len(lines)

	// Analyze each line
	for line in lines {
		trimmed := strings.trim_space(line)

		// Count non-whitespace characters
		for c in line {
			if c != ' ' && c != '\t' && c != '\n' && c != '\r' {
				chars.non_whitespace_chars += 1
			}
		}

		// Count comment lines
		if strings.has_prefix(trimmed, "#") && !strings.has_prefix(trimmed, "#!") {
			chars.comment_lines += 1
		} else if trimmed != "" {
			chars.code_lines += 1
		}
	}

	// Check for Unicode
	chars.has_unicode = has_unicode_content(source)

	// Check for special characters
	chars.has_special_chars = has_special_shell_chars(source)

	// Quote balance
	mismatched, _ := has_mismatched_quotes(source)
	chars.quote_balance = !mismatched

	// Nesting depth
	chars.max_nesting_depth = calculate_nesting_depth(source)

	// Pipeline commands
	chars.pipeline_commands = count_pipeline_commands(source)

	return chars
}

// has_special_shell_chars checks if the source contains special shell characters
has_special_shell_chars :: proc(source: string) -> bool {
	special_chars := []byte {
		'$',
		'`',
		'\\',
		'|',
		'&',
		';',
		'<',
		'>',
		'(',
		')',
		'{',
		'}',
		'[',
		']',
		'*',
		'?',
		'~',
	}

	for c in source {
		for special in special_chars {
			if u8(c) == special {
				return true
			}
		}
	}
	return false
}

// detect_edge_cases analyzes source code and returns detected edge cases
detect_edge_cases :: proc(source: string) -> [dynamic]EdgeCaseInfo {
	edge_cases := make([dynamic]EdgeCaseInfo)

	// Check for empty script
	if is_empty_script(source) {
		append(
			&edge_cases,
			EdgeCaseInfo {
				type = .EmptyScript,
				detected = true,
				description = "Source code is empty",
				suggestion = "Provide non-empty shell script content",
			},
		)
		return edge_cases
	}

	// Check for whitespace-only
	if is_whitespace_only(source) {
		append(
			&edge_cases,
			EdgeCaseInfo {
				type = .WhitespaceOnly,
				detected = true,
				description = "Source contains only whitespace characters",
				suggestion = "Provide shell script content with actual code",
			},
		)
		return edge_cases
	}

	// Check for comments-only
	if is_comments_only(source) {
		append(
			&edge_cases,
			EdgeCaseInfo {
				type = .CommentsOnly,
				detected = true,
				description = "Source contains only comments and whitespace",
				suggestion = "Script has no executable content, only comments",
			},
		)
	}

	// Check for mismatched quotes
	mismatched, quote_msg := has_mismatched_quotes(source)
	if mismatched {
		append(
			&edge_cases,
			EdgeCaseInfo {
				type = .MismatchedQuotes,
				detected = true,
				description = quote_msg,
				suggestion = "Ensure all quotes are properly closed",
			},
		)
	}

	// Analyze script characteristics
	chars := analyze_script(source)

	// Check for Unicode content
	if chars.has_unicode {
		append(
			&edge_cases,
			EdgeCaseInfo {
				type = .UnicodeContent,
				detected = true,
				description = "Source contains Unicode characters",
				suggestion = "Unicode should be handled correctly in translation",
			},
		)
	}

	// Check for deeply nested structures
	if chars.max_nesting_depth > 10 {
		append(
			&edge_cases,
			EdgeCaseInfo {
				type = .DeeplyNested,
				detected = true,
				description = fmt.tprintf(
					"Deep nesting detected: %d levels",
					chars.max_nesting_depth,
				),
				suggestion = "Consider refactoring deeply nested structures",
			},
		)
	}

	// Check for large scripts
	if chars.line_count > 10000 {
		append(
			&edge_cases,
			EdgeCaseInfo {
				type = .LargeScript,
				detected = true,
				description = fmt.tprintf("Large script: %d lines", chars.line_count),
				suggestion = "Performance may be impacted for very large scripts",
			},
		)
	}

	// Check for complex pipelines
	if chars.pipeline_commands > 5 {
		append(
			&edge_cases,
			EdgeCaseInfo {
				type = .ComplexPipeline,
				detected = true,
				description = fmt.tprintf(
					"Complex pipeline: %d commands",
					chars.pipeline_commands,
				),
				suggestion = "Multi-command pipelines are supported but may need verification",
			},
		)
	}

	return edge_cases
}

import "core:fmt"

// format_edge_case formats an edge case info for display
format_edge_case :: proc(info: EdgeCaseInfo) -> string {
	return fmt.tprintf("[%v] %s: %s", info.type, info.description, info.suggestion)
}

// should_warn_about_edge_case determines if a warning should be generated
should_warn_about_edge_case :: proc(info: EdgeCaseInfo) -> bool {
	#partial switch info.type {
	case .MismatchedQuotes, .MalformedSyntax:
		return true // These are errors
	case .DeeplyNested, .LargeScript, .ComplexPipeline:
		return true // These are performance concerns
	case .UnicodeContent, .CommentsOnly:
		return false // These are informational only
	case .EmptyScript, .WhitespaceOnly:
		return true // These are noteworthy
	}
	return false
}

// create_empty_program_result creates a result for edge case scenarios
create_empty_program_result :: proc() -> string {
	return "# Empty script - no content to translate\n"
}

// validate_before_translation performs pre-translation validation
validate_before_translation :: proc(
	source: string,
) -> (
	valid: bool,
	issues: [dynamic]EdgeCaseInfo,
) {
	issues = detect_edge_cases(source)

	// Check for blocking issues
	for issue in issues {
		#partial switch issue.type {
		case .EmptyScript, .WhitespaceOnly:
			return false, issues
		case .MismatchedQuotes:
			// Mismatched quotes may block translation
			return false, issues
		}
	}

	return true, issues
}

// sanitize_for_translation sanitizes source code before translation
sanitize_for_translation :: proc(source: string, allocator := context.allocator) -> string {
	result := source

	// Remove BOM if present
	if len(result) >= 3 && result[0] == 0xEF && result[1] == 0xBB && result[2] == 0xBF {
		result = result[3:]
	}

	// Normalize line endings to LF
	sanitized, _ := strings.replace_all(result, "\r\n", "\n", allocator)
	return sanitized
}

// estimate_translation_complexity estimates the complexity of translation
estimate_translation_complexity :: proc(source: string) -> int {
	chars := analyze_script(source)

	// Simple scoring algorithm
	score := 0

	// Base score from line count
	score += chars.line_count / 10

	// Penalize deep nesting
	score += chars.max_nesting_depth * 5

	// Penalize complex pipelines
	score += chars.pipeline_commands * 2

	// Penalize Unicode content
	if chars.has_unicode {
		score += 10
	}

	// Penalize special characters
	if chars.has_special_chars {
		score += 5
	}

	return score
}

// is_translation_complex determines if a translation is considered complex
is_translation_complex :: proc(source: string) -> bool {
	return estimate_translation_complexity(source) > 100
}

// ScriptSizeCategory categorizes script sizes
ScriptSizeCategory :: enum {
	Empty,
	Tiny, // < 10 lines
	Small, // 10-100 lines
	Medium, // 100-1000 lines
	Large, // 1000-10000 lines
	VeryLarge, // > 10000 lines
}

// categorize_script_size categorizes a script by its size
categorize_script_size :: proc(source: string) -> ScriptSizeCategory {
	lines := strings.split_lines(source)
	defer delete(lines)

	line_count := 0
	for line in lines {
		if strings.trim_space(line) != "" {
			line_count += 1
		}
	}

	switch {
	case line_count == 0:
		return .Empty
	case line_count < 10:
		return .Tiny
	case line_count < 100:
		return .Small
	case line_count < 1000:
		return .Medium
	case line_count < 10000:
		return .Large
	case:
		return .VeryLarge
	}
}
