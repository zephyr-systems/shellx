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
	policy := shellx.DEFAULT_SECURITY_SCAN_POLICY
	policy.ruleset_version = "zephyr-policy-2026-02"
	policy.allowlist_paths = []string{"trusted/vendor"}
	policy.custom_rules = []shellx.SecurityScanRule{
		{
			rule_id = "zephyr.custom.runtime_source_tmp",
			enabled = true,
			severity = .High,
			match_kind = .Regex,
			category = "source",
			confidence = 0.90,
			phases = { .Source },
			pattern = "source\\s+/tmp/",
			message = "Temporary source path detected",
			suggestion = "Use trusted immutable module paths",
		},
		{
			rule_id = "zephyr.custom.eval_exec",
			enabled = true,
			severity = .Critical,
			match_kind = .AstCommand,
			category = "execution",
			confidence = 0.95,
			phases = { .Source },
			command_name = "eval",
			arg_pattern = "$(",
			message = "Dynamic eval pattern detected",
			suggestion = "Avoid eval on dynamic command strings",
		},
	}

	opts := shellx.DEFAULT_SECURITY_SCAN_OPTIONS
	opts.max_file_size = 2 * 1024 * 1024
	opts.timeout_ms = 3000

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

