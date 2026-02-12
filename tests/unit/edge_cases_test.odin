package unit_tests

import "../../utils"
import "core:fmt"
import "core:strings"
import "core:testing"

SHELLX_TEST_NAME :: #config(SHELLX_TEST_NAME, "")

should_run_test :: proc(name: string) -> bool {
	if SHELLX_TEST_NAME == "" {
		return true
	}
	return strings.contains(name, SHELLX_TEST_NAME)
}

// 25.1 Handle empty scripts

@(test)
test_empty_script :: proc(t: ^testing.T) {
	if !should_run_test("test_empty_script") {return}

	empty_source := ""

	// Test is_empty_script
	testing.expect(
		t,
		utils.is_empty_script(empty_source),
		"Empty string should be detected as empty script",
	)

	// Test is_whitespace_only (should also be true for empty)
	testing.expect(
		t,
		utils.is_whitespace_only(empty_source),
		"Empty string should be whitespace-only",
	)

	// Test edge case detection
	edge_cases := utils.detect_edge_cases(empty_source)
	defer delete(edge_cases)

	testing.expect(
		t,
		len(edge_cases) >= 1,
		"Should detect at least one edge case for empty script",
	)

	found_empty := false
	for ec in edge_cases {
		if ec.type == .EmptyScript {
			found_empty = true
			break
		}
	}
	testing.expect(t, found_empty, "Should detect EmptyScript edge case")

	// Test validation
	valid, issues := utils.validate_before_translation(empty_source)
	defer delete(issues)
	testing.expect(t, !valid, "Empty script should fail validation")
}

@(test)
test_whitespace_only_script :: proc(t: ^testing.T) {
	if !should_run_test("test_whitespace_only_script") {return}

	whitespace_sources := []string{"   ", "\t\t\t", "\n\n\n", " \t\n \t\n", "   \r\n  \t  "}

	for source in whitespace_sources {
		// Should NOT be empty
		testing.expect(t, !utils.is_empty_script(source), "Whitespace-only should not be empty")

		// Should be whitespace-only
		testing.expect(
			t,
			utils.is_whitespace_only(source),
			"Should detect whitespace-only content",
		)

		// Edge case detection
		edge_cases := utils.detect_edge_cases(source)
		defer delete(edge_cases)

		found_whitespace := false
		for ec in edge_cases {
			if ec.type == .WhitespaceOnly {
				found_whitespace = true
				break
			}
		}
		testing.expect(t, found_whitespace, "Should detect WhitespaceOnly edge case")

		// Validation should fail
		valid, issues := utils.validate_before_translation(source)
		defer delete(issues)
		testing.expect(t, !valid, "Whitespace-only should fail validation")
	}
}

@(test)
test_comments_only_script :: proc(t: ^testing.T) {
	if !should_run_test("test_comments_only_script") {return}

	comments_only_sources := []string {
		"# This is a comment",
		"#!/bin/bash\n# Just a comment",
		"# Comment 1\n# Comment 2\n# Comment 3",
		"   \n# Indented comment\n   ",
	}

	for source in comments_only_sources {
		// Should detect comments-only
		edge_cases := utils.detect_edge_cases(source)
		defer delete(edge_cases)

		found_comments := false
		for ec in edge_cases {
			if ec.type == .CommentsOnly {
				found_comments = true
				break
			}
		}
		testing.expect(t, found_comments, "Should detect CommentsOnly edge case")
	}

	// Script with actual code should NOT be comments-only
	code_with_comments := "# Comment\necho hello\n# Another comment"
	testing.expect(
		t,
		!utils.is_comments_only(code_with_comments),
		"Script with code should not be comments-only",
	)
}

// 25.2 Handle malformed input

@(test)
test_mismatched_quotes :: proc(t: ^testing.T) {
	if !should_run_test("test_mismatched_quotes") {return}

	// Unclosed single quote
	single_unclosed := "echo 'hello"
	mismatched, msg := utils.has_mismatched_quotes(single_unclosed)
	testing.expect(t, mismatched, "Should detect unclosed single quote")
	testing.expect(t, strings.contains(msg, "single"), "Message should mention single quote")

	// Unclosed double quote
	double_unclosed := `echo "hello`
	mismatched, msg = utils.has_mismatched_quotes(double_unclosed)
	testing.expect(t, mismatched, "Should detect unclosed double quote")
	testing.expect(t, strings.contains(msg, "double"), "Message should mention double quote")

	// Properly balanced quotes
	balanced := `echo "hello"`
	mismatched, _ = utils.has_mismatched_quotes(balanced)
	testing.expect(t, !mismatched, "Should not detect mismatched quotes in balanced string")

	// Nested quotes
	nested := `echo "it's working"`
	mismatched, _ = utils.has_mismatched_quotes(nested)
	testing.expect(t, !mismatched, "Should handle nested quotes correctly")

	// Escaped quotes
	escaped := `echo \"hello\"`
	mismatched, _ = utils.has_mismatched_quotes(escaped)
	testing.expect(t, !mismatched, "Should handle escaped quotes correctly")
}

@(test)
test_edge_case_detection_malformed :: proc(t: ^testing.T) {
	if !should_run_test("test_edge_case_detection_malformed") {return}

	malformed_sources := []string {
		"echo 'unclosed",
		`echo "unclosed`,
		"if [ $x -eq 1 ]; then echo 'test",
	}

	for source in malformed_sources {
		edge_cases := utils.detect_edge_cases(source)
		defer delete(edge_cases)

		found_mismatched := false
		for ec in edge_cases {
			if ec.type == .MismatchedQuotes {
				found_mismatched = true
				break
			}
		}
		testing.expect(t, found_mismatched, "Should detect mismatched quotes in malformed input")
	}
}

// 25.3 Handle large scripts

@(test)
test_large_script_detection :: proc(t: ^testing.T) {
	if !should_run_test("test_large_script_detection") {return}

	// Create a large script (simulate 10001 lines)
	builder := strings.builder_make()
	for i in 0 ..< 10001 {
		strings.write_string(&builder, "echo line\n")
	}
	large_script := strings.to_string(builder)
	defer delete(large_script)

	// Analyze characteristics
	chars := utils.analyze_script(large_script)
	testing.expect(t, chars.line_count >= 10000, "Should detect large script size")

	// Detect edge cases
	edge_cases := utils.detect_edge_cases(large_script)
	defer delete(edge_cases)

	found_large := false
	for ec in edge_cases {
		if ec.type == .LargeScript {
			found_large = true
			break
		}
	}
	testing.expect(t, found_large, "Should detect LargeScript edge case")

	// Test size categorization
	category := utils.categorize_script_size(large_script)
	testing.expect(t, category == .VeryLarge, "Should categorize as VeryLarge")
}

@(test)
test_deeply_nested_detection :: proc(t: ^testing.T) {
	if !should_run_test("test_deeply_nested_detection") {return}

	// Create deeply nested script (11 levels)
	deeply_nested := `#!/bin/bash
if true; then
  if true; then
    if true; then
      if true; then
        if true; then
          if true; then
            if true; then
              if true; then
                if true; then
                  if true; then
                    if true; then
                      echo "deep"
                    fi
                  fi
                fi
              fi
            fi
          fi
        fi
      fi
    fi
  fi
fi`

	// Calculate nesting depth
	depth := utils.calculate_nesting_depth(deeply_nested)
	testing.expect(t, depth > 10, "Should detect deep nesting (>10 levels)")

	// Detect edge cases
	edge_cases := utils.detect_edge_cases(deeply_nested)
	defer delete(edge_cases)

	found_deep := false
	for ec in edge_cases {
		if ec.type == .DeeplyNested {
			found_deep = true
			break
		}
	}
	testing.expect(t, found_deep, "Should detect DeeplyNested edge case")
}

@(test)
test_script_size_categories :: proc(t: ^testing.T) {
	if !should_run_test("test_script_size_categories") {return}

	test_cases := []struct {
		source:   string,
		expected: utils.ScriptSizeCategory,
	} {
		{"", .Empty},
		{"\n\n\n", .Empty},
		{"echo hello", .Tiny},
		{"echo 1\necho 2\necho 3\necho 4\necho 5\necho 6\necho 7\necho 8\necho 9", .Tiny},
		{strings.repeat("echo line\n", 50), .Small},
		{strings.repeat("echo line\n", 500), .Medium},
		{strings.repeat("echo line\n", 5000), .Large},
	}

	for tc in test_cases {
		category := utils.categorize_script_size(tc.source)
		testing.expect(
			t,
			category == tc.expected,
			fmt.tprintf("Expected category %v but got %v", tc.expected, category),
		)
	}
}

// 25.4 Handle special characters

@(test)
test_unicode_detection :: proc(t: ^testing.T) {
	if !should_run_test("test_unicode_detection") {return}

	// Scripts with Unicode
	unicode_sources := []string {
		`echo "Hello 世界"`,
		`echo "Привет мир"`,
		`echo "🎉 Party"`,
		`# Comment with émojis 🚀`,
	}

	for source in unicode_sources {
		has_unicode := utils.has_unicode_content(source)
		testing.expect(t, has_unicode, "Should detect Unicode content")

		// Check edge case detection
		edge_cases := utils.detect_edge_cases(source)
		defer delete(edge_cases)

		found_unicode := false
		for ec in edge_cases {
			if ec.type == .UnicodeContent {
				found_unicode = true
				break
			}
		}
		testing.expect(t, found_unicode, "Should detect UnicodeContent edge case")
	}

	// Script without Unicode
	ascii_only := `echo "Hello World"`
	testing.expect(
		t,
		!utils.has_unicode_content(ascii_only),
		"Should not detect ASCII-only as Unicode",
	)
}

@(test)
test_special_shell_chars :: proc(t: ^testing.T) {
	if !should_run_test("test_special_shell_chars") {return}

	// Scripts with special characters
	special_sources := []string {
		`echo $VAR`,
		"echo `date`",
		`echo "hello\nworld"`,
		`ls | grep test`,
		`cmd1 && cmd2`,
		`echo "test" > file.txt`,
		`cat < input.txt`,
		`$(echo test)`,
		`{ echo a; echo b; }`,
		`[ -f file ]`,
		`rm *.txt`,
		`echo ???`,
		`echo ~/home`,
	}

	for source in special_sources {
		has_special := utils.has_special_shell_chars(source)
		testing.expect(t, has_special, "Should detect special shell characters")
	}

	// Plain script without special characters
	plain := `echo hello world`
	testing.expect(
		t,
		!utils.has_special_shell_chars(plain),
		"Should not detect special chars in plain script",
	)
}

@(test)
test_script_characteristics :: proc(t: ^testing.T) {
	if !should_run_test("test_script_characteristics") {return}

	script := `#!/bin/bash
# This is a comment
x=5
# Another comment
echo $x
if [ $x -eq 5 ]; then
  echo "yes"
fi`

	chars := utils.analyze_script(script)

	testing.expect(t, chars.line_count > 0, "Should count lines")
	testing.expect(t, chars.char_count > 0, "Should count characters")
	testing.expect(t, chars.non_whitespace_chars > 0, "Should count non-whitespace")
	testing.expect(t, chars.comment_lines >= 2, "Should detect comment lines")
	testing.expect(t, chars.code_lines >= 3, "Should detect code lines")
}

// 25.5 Handle shell-specific edge cases

@(test)
test_validation_before_translation :: proc(t: ^testing.T) {
	if !should_run_test("test_validation_before_translation") {return}

	// Valid script
	valid_script := `echo "hello world"`
	valid, issues := utils.validate_before_translation(valid_script)
	defer delete(issues)
	testing.expect(t, valid, "Valid script should pass validation")

	// Empty script should fail
	empty_script := ""
	valid, issues = utils.validate_before_translation(empty_script)
	defer delete(issues)
	testing.expect(t, !valid, "Empty script should fail validation")

	// Whitespace-only should fail
	whitespace_script := "   \n\t  "
	valid, issues = utils.validate_before_translation(whitespace_script)
	defer delete(issues)
	testing.expect(t, !valid, "Whitespace-only should fail validation")

	// Mismatched quotes should fail
	mismatched_script := `echo "unclosed`
	valid, issues = utils.validate_before_translation(mismatched_script)
	defer delete(issues)
	testing.expect(t, !valid, "Mismatched quotes should fail validation")
}

@(test)
test_sanitize_for_translation :: proc(t: ^testing.T) {
	if !should_run_test("test_sanitize_for_translation") {return}

	// Test CRLF normalization
	crlf_script := "line1\r\nline2\r\nline3"
	sanitized := utils.sanitize_for_translation(crlf_script)
	defer delete(sanitized)
	testing.expect(t, !strings.contains(sanitized, "\r\n"), "Should normalize CRLF to LF")
	testing.expect(t, strings.contains(sanitized, "\n"), "Should have LF line endings")
}

@(test)
test_translation_complexity :: proc(t: ^testing.T) {
	if !should_run_test("test_translation_complexity") {return}

	// Simple script - low complexity
	simple := `echo hello`
	complexity := utils.estimate_translation_complexity(simple)
	testing.expect(t, complexity < 10, "Simple script should have low complexity")
	testing.expect(t, !utils.is_translation_complex(simple), "Simple script should not be complex")

	// Large nested script - high complexity
	builder := strings.builder_make()
	for i in 0 ..< 100 {
		for j in 0 ..< 5 {
			strings.write_string(&builder, "if true; then\n")
		}
		for j in 0 ..< 5 {
			strings.write_string(&builder, "fi\n")
		}
	}
	complex := strings.to_string(builder)
	defer delete(complex)

	complexity = utils.estimate_translation_complexity(complex)
	testing.expect(t, complexity > 100, "Large nested script should have high complexity")
	testing.expect(
		t,
		utils.is_translation_complex(complex),
		"Complex script should be marked as complex",
	)
}

// 25.6 Handle complex pipelines

@(test)
test_pipeline_detection :: proc(t: ^testing.T) {
	if !should_run_test("test_pipeline_detection") {return}

	// Simple pipeline
	simple := `cat file | grep test`
	commands := utils.count_pipeline_commands(simple)
	testing.expect(t, commands == 2, "Should count 2 commands in simple pipeline")

	// Complex pipeline (5+ commands)
	complex := `cat file | grep test | sed 's/old/new/' | sort | uniq | wc -l`
	commands = utils.count_pipeline_commands(complex)
	testing.expect(t, commands >= 5, "Should count 6 commands in complex pipeline")

	// Multiple pipelines, should return max
	multi := `echo a | echo b
cat x | grep y | sed z | awk w | sort | uniq`
	commands = utils.count_pipeline_commands(multi)
	testing.expect(t, commands >= 5, "Should return max pipeline count")
}

@(test)
test_complex_pipeline_edge_case :: proc(t: ^testing.T) {
	if !should_run_test("test_complex_pipeline_edge_case") {return}

	// Pipeline with 6 commands
	complex_pipeline := `cmd1 | cmd2 | cmd3 | cmd4 | cmd5 | cmd6`

	edge_cases := utils.detect_edge_cases(complex_pipeline)
	defer delete(edge_cases)

	found_complex := false
	for ec in edge_cases {
		if ec.type == .ComplexPipeline {
			found_complex = true
			break
		}
	}
	testing.expect(t, found_complex, "Should detect ComplexPipeline edge case")
}

@(test)
test_pipeline_with_strings :: proc(t: ^testing.T) {
	if !should_run_test("test_pipeline_with_strings") {return}

	// Pipeline with strings containing pipes
	with_strings := `echo "a | b" | cat | grep test`
	commands := utils.count_pipeline_commands(with_strings)
	testing.expect(t, commands == 3, "Should not count pipes inside strings")

	// Pipeline with single quotes
	single_quotes := `echo 'a | b' | cat | grep test`
	commands = utils.count_pipeline_commands(single_quotes)
	testing.expect(t, commands == 3, "Should not count pipes inside single quotes")
}

// Edge case utilities tests

@(test)
test_edge_case_formatting :: proc(t: ^testing.T) {
	if !should_run_test("test_edge_case_formatting") {return}

	info := utils.EdgeCaseInfo {
		type        = .EmptyScript,
		detected    = true,
		description = "Test description",
		suggestion  = "Test suggestion",
	}

	formatted := utils.format_edge_case(info)
	testing.expect(t, len(formatted) > 0, "Should format edge case info")
	testing.expect(t, strings.contains(formatted, "EmptyScript"), "Should include type name")
	testing.expect(
		t,
		strings.contains(formatted, "Test description"),
		"Should include description",
	)
}

@(test)
test_should_warn_about_edge_case :: proc(t: ^testing.T) {
	if !should_run_test("test_should_warn_about_edge_case") {return}

	// Should warn about these
	warn_types := []utils.EdgeCaseType {
		.MismatchedQuotes,
		.MalformedSyntax,
		.DeeplyNested,
		.LargeScript,
		.ComplexPipeline,
		.EmptyScript,
		.WhitespaceOnly,
	}

	for warn_type in warn_types {
		info := utils.EdgeCaseInfo {
			type     = warn_type,
			detected = true,
		}
		testing.expect(
			t,
			utils.should_warn_about_edge_case(info),
			fmt.tprintf("Should warn about %v", warn_type),
		)
	}

	// Should NOT warn about these
	no_warn_types := []utils.EdgeCaseType{.UnicodeContent, .CommentsOnly, .None}

	for no_warn_type in no_warn_types {
		info := utils.EdgeCaseInfo {
			type     = no_warn_type,
			detected = true,
		}
		testing.expect(
			t,
			!utils.should_warn_about_edge_case(info),
			fmt.tprintf("Should NOT warn about %v", no_warn_type),
		)
	}
}

@(test)
test_create_empty_program_result :: proc(t: ^testing.T) {
	if !should_run_test("test_create_empty_program_result") {return}

	result := utils.create_empty_program_result()
	testing.expect(t, len(result) > 0, "Should return non-empty result")
	testing.expect(t, strings.contains(result, "Empty"), "Should mention empty in result")
}

// Integration with translation pipeline

@(test)
test_edge_cases_integration :: proc(t: ^testing.T) {
	if !should_run_test("test_edge_cases_integration") {return}

	// Test that edge case detection works with actual translation scenarios

	// Scenario 1: Empty script
	empty := ""
	valid, issues := utils.validate_before_translation(empty)
	defer delete(issues)
	testing.expect(t, !valid, "Empty script should be invalid")

	// Scenario 2: Valid script with Unicode
	unicode_script := `echo "Hello 世界"`
	valid, issues = utils.validate_before_translation(unicode_script)
	defer delete(issues)
	testing.expect(t, valid, "Unicode script should be valid")

	// Check that Unicode was detected as info (not error)
	found_unicode := false
	for issue in issues {
		if issue.type == .UnicodeContent {
			found_unicode = true
			break
		}
	}
	testing.expect(t, found_unicode, "Should detect Unicode in valid script")
}

@(test)
test_edge_case_type_enum :: proc(t: ^testing.T) {
	if !should_run_test("test_edge_case_type_enum") {return}

	// Verify all edge case types exist
	types := []utils.EdgeCaseType {
		.None,
		.EmptyScript,
		.WhitespaceOnly,
		.CommentsOnly,
		.MalformedSyntax,
		.MismatchedQuotes,
		.UnicodeContent,
		.DeeplyNested,
		.LargeScript,
		.ComplexPipeline,
	}

	for edge_type in types {
		// Just verify they compile and can be used
		info := utils.EdgeCaseInfo {
			type = edge_type,
		}
		testing.expect(t, info.type == edge_type, "Edge case type should be set correctly")
	}
}

@(test)
test_quote_balance_in_characteristics :: proc(t: ^testing.T) {
	if !should_run_test("test_quote_balance_in_characteristics") {return}

	// Balanced quotes
	balanced := `echo "hello"`
	chars := utils.analyze_script(balanced)
	testing.expect(t, chars.quote_balance, "Balanced quotes should be detected")

	// Unbalanced quotes
	unbalanced := `echo "hello`
	chars = utils.analyze_script(unbalanced)
	testing.expect(t, !chars.quote_balance, "Unbalanced quotes should be detected")
}

@(test)
test_escape_sequence_handling :: proc(t: ^testing.T) {
	if !should_run_test("test_escape_sequence_handling") {return}

	// Script with escape sequences
	escaped := `echo "hello\nworld\t\"quoted\""`

	// Should NOT be detected as mismatched (escaped quotes don't count)
	mismatched, _ := utils.has_mismatched_quotes(escaped)
	testing.expect(t, !mismatched, "Escaped quotes should not cause mismatch detection")
}
