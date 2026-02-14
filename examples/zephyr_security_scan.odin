// Example: Zephyr-Oriented Security Scanning with ShellX
// Demonstrates policy injection, batch scanning, and JSON output.

package main

import ".."
import "core:fmt"
import "core:os"

make_fixture :: proc(path: string, content: string) -> bool {
	return os.write_entire_file(path, transmute([]byte)content)
}

main :: proc() {
	policy_json := `{
  "use_builtin_rules": true,
  "block_threshold": "High",
  "ruleset_version": "zephyr-policy-2026-02"
}`
	policy, validation_errors, ok := shellx.load_security_policy_json(policy_json)
	defer {
		for err in validation_errors {
			delete(err.rule_id)
			delete(err.message)
			delete(err.suggestion)
			delete(err.snippet)
		}
		delete(validation_errors)
	}
	if !ok {
		fmt.println("invalid policy json")
		for err in validation_errors {
			fmt.println(shellx.report_error(err))
		}
		return
	}
	policy.allowlist_paths = []string{"trusted/vendor"}

	opts := shellx.DEFAULT_SECURITY_SCAN_OPTIONS
	opts.max_file_size = 2 * 1024 * 1024
	opts.timeout_ms = 3000
	opts.ast_parse_failure_mode = .FailOpen
	opts.max_files = 1000
	opts.max_total_bytes = 128 * 1024 * 1024

	p1 := "/tmp/zephyr_scan_fixture_1.zsh"
	p2 := "/tmp/zephyr_scan_fixture_2.zsh"
	ok1 := make_fixture(p1, "eval \"$(echo hi)\"\n")
	ok2 := make_fixture(p2, "echo safe\n")
	if !ok1 || !ok2 {
		fmt.println("failed to create fixtures")
		return
	}
	defer os.remove(p1)
	defer os.remove(p2)

	one := shellx.scan_security_file(p1, .Zsh, policy, opts)
	defer shellx.destroy_security_scan_result(&one)
	if !one.success {
		fmt.println("scanner runtime failure:")
		for err in one.errors {
			fmt.println(shellx.report_error(err))
		}
		return
	}
	fmt.println("single-file blocked:", one.blocked)
	for finding in one.findings {
		fmt.println("finding:", finding.rule_id, finding.severity, finding.fingerprint)
	}
	json_one := shellx.format_security_scan_json(one, true)
	defer delete(json_one)
	fmt.println(json_one)

	files := []string{p1, p2}
	batch := shellx.scan_security_batch(files, .Zsh, policy, opts)
	defer shellx.destroy_security_scan_batch(&batch)
	for item in batch {
		fmt.println("file:", item.filepath, "success:", item.result.success, "blocked:", item.result.blocked)
	}
	json_batch := shellx.format_security_scan_batch_json(batch[:], true)
	defer delete(json_batch)
	fmt.println(json_batch)
}
