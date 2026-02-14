package shellx

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:text/regex"
import "core:time"
import "frontend"
import "ir"

SECURITY_RULESET_VERSION :: "shellx-rules-2026-02-14"

scanner_severity_rank :: proc(s: FindingSeverity) -> int {
	switch s {
	case .Info:
		return 0
	case .Warning:
		return 1
	case .High:
		return 2
	case .Critical:
		return 3
	}
	return 0
}

scanner_phase_name :: proc(phase: SecurityScanPhase) -> string {
	switch phase {
	case .Source:
		return "source"
	case .Translated:
		return "translated"
	}
	return "source"
}

scanner_command_allowlisted :: proc(command: string, policy: SecurityScanPolicy) -> bool {
	for allowed in policy.allowlist_commands {
		if allowed == command {
			return true
		}
	}
	return false
}

scanner_path_allowlisted :: proc(path: string, policy: SecurityScanPolicy) -> bool {
	if path == "" {
		return false
	}
	for allowed in policy.allowlist_paths {
		if allowed != "" && strings.contains(path, allowed) {
			return true
		}
	}
	return false
}

scanner_find_override :: proc(policy: SecurityScanPolicy, rule_id: string) -> (SecurityRuleOverride, bool) {
	for override in policy.rule_overrides {
		if override.rule_id == rule_id {
			return override, true
		}
	}
	return SecurityRuleOverride{}, false
}

scanner_rule_effective :: proc(policy: SecurityScanPolicy, rule: SecurityScanRule) -> (SecurityScanRule, bool) {
	out := rule
	if out.enabled == false {
		return out, false
	}
	override, ok := scanner_find_override(policy, rule.rule_id)
	if ok {
		if !override.enabled {
			return out, false
		}
		if override.has_severity_override {
			out.severity = override.severity_override
		}
	}
	return out, true
}

scanner_fingerprint :: proc(rule_id: string, loc: ir.SourceLocation, matched: string, phase: string) -> string {
	hash: u64 = 1469598103934665603
	write_byte :: proc(v: ^u64, b: byte) {
		v^ = (v^ ~ u64(b)) * 1099511628211
	}
	write_string :: proc(v: ^u64, s: string) {
		for ch in s {
			write_byte(v, byte(ch))
		}
	}
	write_string(&hash, rule_id)
	write_string(&hash, loc.file)
	write_string(&hash, fmt.tprintf("%d:%d:%d", loc.line, loc.column, loc.length))
	write_string(&hash, matched)
	write_string(&hash, phase)
	return strings.clone(fmt.tprintf("%016x", hash), context.allocator)
}

scanner_append_finding :: proc(
	result: ^SecurityScanResult,
	rule_id: string,
	severity: FindingSeverity,
	message: string,
	location: ir.SourceLocation,
	suggestion: string,
	phase: SecurityScanPhase,
	category: string,
	confidence: f32,
	matched_text: string,
) {
	phase_name := scanner_phase_name(phase)
	fingerprint := scanner_fingerprint(rule_id, location, matched_text, phase_name)
	defer {
		if fingerprint != "" {
			delete(fingerprint)
		}
	}
	for finding in result.findings {
		if finding.fingerprint != "" && finding.fingerprint == fingerprint {
			return
		}
	}
	append(
		&result.findings,
		SecurityFinding{
			rule_id = strings.clone(rule_id, context.allocator),
			severity = severity,
			message = strings.clone(message, context.allocator),
			location = location,
			suggestion = strings.clone(suggestion, context.allocator),
			phase = strings.clone(phase_name, context.allocator),
			category = strings.clone(category, context.allocator),
			confidence = confidence,
			matched_text = strings.clone(matched_text, context.allocator),
			fingerprint = strings.clone(fingerprint, context.allocator),
		},
	)
}

scanner_append_runtime_error :: proc(
	result: ^SecurityScanResult,
	err: Error,
	message: string,
	location := ir.SourceLocation{},
	suggestion := "",
	rule_id := "",
) {
	result.success = false
	if result.error == .None {
		result.error = err
	}
	append(
		&result.errors,
		ErrorContext{
			error = err,
			rule_id = strings.clone(rule_id, context.allocator),
			message = strings.clone(message, context.allocator),
			location = location,
			suggestion = strings.clone(suggestion, context.allocator),
		},
	)
}

scanner_expired :: proc(sw: time.Stopwatch, options: SecurityScanOptions) -> bool {
	if options.timeout_ms <= 0 {
		return false
	}
	return time.duration_milliseconds(time.stopwatch_duration(sw)) > f64(options.timeout_ms)
}

scanner_check_timeout :: proc(result: ^SecurityScanResult, sw: time.Stopwatch, options: SecurityScanOptions) -> bool {
	if !scanner_expired(sw, options) {
		return false
	}
	scanner_append_runtime_error(
		result,
		.ScanTimeout,
		"Security scan timed out",
		ir.SourceLocation{},
		"Increase timeout_ms or reduce scanned file size",
		"sec.runtime.timeout",
	)
	return true
}

scanner_maybe_add_builtin_line_findings :: proc(
	result: ^SecurityScanResult,
	policy: SecurityScanPolicy,
	source_name: string,
	line: string,
	line_no: int,
	phase: SecurityScanPhase,
) {
	trimmed := strings.trim_space(line)
	if trimmed == "" {
		return
	}
	loc := ir.SourceLocation{
		file = source_name,
		line = line_no,
		column = 0,
		length = len(trimmed),
	}

	if (strings.contains(trimmed, "| sh") || strings.contains(trimmed, "| bash") ||
		strings.contains(trimmed, "| zsh") || strings.contains(trimmed, "| fish")) &&
		(strings.contains(trimmed, "curl ") || strings.contains(trimmed, "wget ") || strings.contains(trimmed, "fetch ")) {
		if !scanner_path_allowlisted(source_name, policy) && !scanner_command_allowlisted("sh", policy) {
			scanner_append_finding(
				result,
				"sec.pipe_download_exec",
				.Critical,
				"Downloaded content is piped directly into a shell interpreter",
				loc,
				"Download to a file, verify checksum/signature, then execute explicitly",
				phase,
				"execution",
				0.98,
				trimmed,
			)
		}
	}
	if strings.contains(trimmed, "eval ") && (strings.contains(trimmed, "curl ") || strings.contains(trimmed, "wget ")) {
		if !scanner_path_allowlisted(source_name, policy) && !scanner_command_allowlisted("eval", policy) {
			scanner_append_finding(
				result,
				"sec.eval_download",
				.Critical,
				"Dynamic eval with network-fetched content detected",
				loc,
				"Avoid eval on external input; parse and validate input first",
				phase,
				"execution",
				0.95,
				trimmed,
			)
		}
	}
	if strings.contains(trimmed, "rm -rf /") || strings.contains(trimmed, "rm -rf ~") {
		if !scanner_command_allowlisted("rm", policy) {
			scanner_append_finding(
				result,
				"sec.dangerous_rm",
				.Critical,
				"Potentially destructive recursive delete target detected",
				loc,
				"Use explicit safe paths and add guard checks before deletion",
				phase,
				"filesystem",
				0.96,
				trimmed,
			)
		}
	}
	if strings.contains(trimmed, "chmod 777") {
		if !scanner_command_allowlisted("chmod", policy) {
			scanner_append_finding(
				result,
				"sec.overpermissive_chmod",
				.Warning,
				"Overly permissive file mode detected",
				loc,
				"Use least-privilege file permissions",
				phase,
				"permissions",
				0.90,
				trimmed,
			)
		}
	}
	if strings.has_prefix(trimmed, "source /tmp/") || strings.has_prefix(trimmed, ". /tmp/") {
		scanner_append_finding(
			result,
			"sec.source_tmp",
			.High,
			"Sourcing code from /tmp detected",
			loc,
			"Use immutable trusted paths for sourced files",
			phase,
			"source",
			0.93,
			trimmed,
		)
	}
}

scanner_regex_match :: proc(line: string, pattern: string) -> (bool, string, string) {
	r, err := regex.create(pattern)
	if err != nil {
		return false, "", fmt.tprintf("%v", err)
	}
	defer regex.destroy(r)
	capture, ok := regex.match_and_allocate_capture(r, line)
	if ok && len(capture.groups) > 0 {
		matched := capture.groups[0]
		regex.destroy(capture)
		return true, matched, ""
	}
	regex.destroy(capture)
	return ok, "", ""
}

scanner_line_matches_rule :: proc(line: string, rule: SecurityScanRule) -> (bool, string, string) {
	switch rule.match_kind {
	case .Substring:
		if strings.contains(line, rule.pattern) {
			return true, rule.pattern, ""
		}
		return false, "", ""
	case .Regex:
		return scanner_regex_match(line, rule.pattern)
	case .AstCommand:
		return false, "", ""
	}
	return false, "", ""
}

scanner_scan_text_rules :: proc(
	result: ^SecurityScanResult,
	code: string,
	source_name: string,
	phase: SecurityScanPhase,
	policy: SecurityScanPolicy,
	options: SecurityScanOptions,
	sw: ^time.Stopwatch,
) {
	lines := strings.split_lines(code)
	defer delete(lines)
	for line, i in lines {
		if scanner_check_timeout(result, sw^, options) {
			return
		}
		line_no := i + 1
		result.stats.lines_scanned += 1
		if policy.use_builtin_rules {
			scanner_maybe_add_builtin_line_findings(result, policy, source_name, line, line_no, phase)
		}
		trimmed := strings.trim_space(line)
		if trimmed == "" {
			continue
		}
		for raw_rule in policy.custom_rules {
			effective_rule, enabled := scanner_rule_effective(policy, raw_rule)
			if !enabled {
				continue
			}
			if effective_rule.match_kind == .AstCommand {
				continue
			}
			if card(effective_rule.phases) > 0 && phase not_in effective_rule.phases {
				continue
			}
			result.stats.rules_evaluated += 1
			matched, matched_text, match_err := scanner_line_matches_rule(trimmed, effective_rule)
			if match_err != "" {
				scanner_append_runtime_error(
					result,
					.ScanInvalidRule,
					fmt.tprintf("Invalid rule pattern for %s: %s", effective_rule.rule_id, match_err),
					ir.SourceLocation{file = source_name, line = line_no, column = 0, length = len(trimmed)},
					"Fix rule pattern syntax",
					effective_rule.rule_id,
				)
				continue
			}
			if !matched {
				continue
			}
			loc := ir.SourceLocation{file = source_name, line = line_no, column = 0, length = len(trimmed)}
			scanner_append_finding(
				result,
				effective_rule.rule_id,
				effective_rule.severity,
				effective_rule.message,
				loc,
				effective_rule.suggestion,
				phase,
				effective_rule.category,
				effective_rule.confidence,
				matched_text,
			)
		}
	}
}

scanner_eval_ast_rules_for_call :: proc(
	result: ^SecurityScanResult,
	policy: SecurityScanPolicy,
	call: ir.Call,
	phase: SecurityScanPhase,
	source_name: string,
) {
	if call.function == nil {
		return
	}
	name := strings.trim_space(call.function.name)
	if name == "" {
		return
	}
	arg_text := strings.builder_make()
	defer strings.builder_destroy(&arg_text)
	for arg in call.arguments {
		#partial switch a in arg {
		case ^ir.Literal:
			strings.write_string(&arg_text, a.value)
		case ^ir.Variable:
			strings.write_string(&arg_text, a.name)
		case ^ir.RawExpression:
			strings.write_string(&arg_text, a.text)
		}
		strings.write_byte(&arg_text, ' ')
	}
	joined_args := strings.clone(strings.to_string(arg_text), context.allocator)
	defer delete(joined_args)

	loc := call.location
	loc.file = source_name
	if scanner_path_allowlisted(source_name, policy) {
		return
	}

	if name == "eval" && !scanner_command_allowlisted(name, policy) {
		scanner_append_finding(
			result,
			"sec.ast.eval",
			.High,
			"AST command analysis detected eval invocation",
			loc,
			"Avoid eval; use explicit command construction",
			phase,
			"execution",
			0.94,
			name,
		)
		if strings.contains(joined_args, "$(") || strings.contains(joined_args, "`") {
			scanner_append_finding(
				result,
				"sec.ast.dynamic_exec",
				.Critical,
				"Dynamic execution with command substitution detected",
				loc,
				"Avoid runtime command construction from untrusted input",
				phase,
				"execution",
				0.96,
				joined_args,
			)
		}
	}
	if (name == "source" || name == ".") && !scanner_command_allowlisted("source", policy) {
		scanner_append_finding(
			result,
			"sec.ast.source",
			.High,
			"AST command analysis detected runtime source invocation",
			loc,
			"Source only trusted immutable files",
			phase,
			"source",
			0.93,
			joined_args,
		)
	}

	for raw_rule in policy.custom_rules {
		effective_rule, enabled := scanner_rule_effective(policy, raw_rule)
		if !enabled || effective_rule.match_kind != .AstCommand {
			continue
		}
		if card(effective_rule.phases) > 0 && phase not_in effective_rule.phases {
			continue
		}
		if effective_rule.command_name != "" && effective_rule.command_name != name {
			continue
		}
		if effective_rule.arg_pattern != "" && !strings.contains(joined_args, effective_rule.arg_pattern) {
			continue
		}
		scanner_append_finding(
			result,
			effective_rule.rule_id,
			effective_rule.severity,
			effective_rule.message,
			loc,
			effective_rule.suggestion,
			phase,
			effective_rule.category,
			effective_rule.confidence,
			name,
		)
	}
}

scanner_walk_ast_statement :: proc(
	result: ^SecurityScanResult,
	policy: SecurityScanPolicy,
	stmt: ir.Statement,
	phase: SecurityScanPhase,
	source_name: string,
) {
	#partial switch stmt.type {
	case .Call:
		scanner_eval_ast_rules_for_call(result, policy, stmt.call, phase, source_name)
	case .Pipeline:
		has_fetch := false
		has_shell := false
		for call in stmt.pipeline.commands {
			if call.function == nil {
				continue
			}
			name := call.function.name
			if name == "curl" || name == "wget" || name == "fetch" {
				has_fetch = true
			}
			if name == "sh" || name == "bash" || name == "zsh" || name == "fish" {
				has_shell = true
			}
			scanner_eval_ast_rules_for_call(result, policy, call, phase, source_name)
		}
		if has_fetch && has_shell && !scanner_command_allowlisted("sh", policy) {
			scanner_append_finding(
				result,
				"sec.ast.pipe_download_exec",
				.Critical,
				"AST command analysis detected network download piped into shell",
				stmt.location,
				"Split download and execution into separate verified steps",
				phase,
				"execution",
				0.98,
				"pipeline",
			)
		}
	case .Branch:
		for inner in stmt.branch.then_body {
			scanner_walk_ast_statement(result, policy, inner, phase, source_name)
		}
		for inner in stmt.branch.else_body {
			scanner_walk_ast_statement(result, policy, inner, phase, source_name)
		}
	case .Loop:
		for inner in stmt.loop.body {
			scanner_walk_ast_statement(result, policy, inner, phase, source_name)
		}
	case .Case:
		for arm in stmt.case_.arms {
			for inner in arm.body {
				scanner_walk_ast_statement(result, policy, inner, phase, source_name)
			}
		}
	}
}

scanner_scan_ast_rules :: proc(
	result: ^SecurityScanResult,
	code: string,
	source_name: string,
	dialect: ShellDialect,
	phase: SecurityScanPhase,
	policy: SecurityScanPolicy,
	options: SecurityScanOptions,
	sw: ^time.Stopwatch,
) {
	if scanner_check_timeout(result, sw^, options) {
		return
	}
	arena_size := len(code) * 8
	if arena_size < 1024*1024 {
		arena_size = 1024 * 1024
	}
	arena := ir.create_arena(arena_size)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(dialect)
	defer frontend.destroy_frontend(&fe)
	tree, parse_err := frontend.parse(&fe, code)
	if parse_err.error != .None || tree == nil {
		scanner_append_runtime_error(
			result,
			.ScanParseError,
			"AST scan failed to parse source",
			ir.SourceLocation{file = source_name},
			"Fix parser errors or disable AST rules for this pass",
			"sec.runtime.parse",
		)
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := convert_to_ir(&arena, dialect, tree, code)
	if conv_err.error != .None || program == nil {
		scanner_append_runtime_error(
			result,
			.ScanParseError,
			"AST scan failed during IR conversion",
			ir.SourceLocation{file = source_name},
			"Fix parser conversion issues for this dialect",
			"sec.runtime.convert",
		)
		return
	}
	for stmt in program.statements {
		if scanner_check_timeout(result, sw^, options) {
			return
		}
		result.stats.rules_evaluated += 1
		scanner_walk_ast_statement(result, policy, stmt, phase, source_name)
	}
	for fn in program.functions {
		for stmt in fn.body {
			if scanner_check_timeout(result, sw^, options) {
				return
			}
			result.stats.rules_evaluated += 1
			scanner_walk_ast_statement(result, policy, stmt, phase, source_name)
		}
	}
}

scanner_has_ast_rules :: proc(policy: SecurityScanPolicy) -> bool {
	for rule in policy.custom_rules {
		if rule.match_kind == .AstCommand {
			return true
		}
	}
	return policy.use_builtin_rules
}

scanner_apply_allowlist :: proc(result: ^SecurityScanResult, policy: SecurityScanPolicy) {
	if len(policy.allowlist_paths) == 0 && len(policy.allowlist_commands) == 0 {
		return
	}
	filtered := make([dynamic]SecurityFinding, 0, len(result.findings), context.allocator)
	for finding in result.findings {
		if scanner_path_allowlisted(finding.location.file, policy) {
			delete(finding.rule_id)
			delete(finding.message)
			delete(finding.suggestion)
			delete(finding.phase)
			delete(finding.category)
			delete(finding.matched_text)
			delete(finding.fingerprint)
			continue
		}
		skip := false
		for command in policy.allowlist_commands {
			if command != "" && (finding.matched_text == command || strings.contains(finding.matched_text, command)) {
				skip = true
				break
			}
		}
		if skip {
			delete(finding.rule_id)
			delete(finding.message)
			delete(finding.suggestion)
			delete(finding.phase)
			delete(finding.category)
			delete(finding.matched_text)
			delete(finding.fingerprint)
			continue
		}
		append(&filtered, finding)
	}
	clear(&result.findings)
	for finding in filtered {
		append(&result.findings, finding)
	}
	delete(filtered)
}

scanner_finalize :: proc(result: ^SecurityScanResult, policy: SecurityScanPolicy) {
	result.blocked = false
	for finding in result.findings {
		if scanner_severity_rank(finding.severity) >= scanner_severity_rank(policy.block_threshold) {
			result.blocked = true
			break
		}
	}
}

scanner_scan_phase :: proc(
	result: ^SecurityScanResult,
	code: string,
	source_name: string,
	dialect: ShellDialect,
	phase: SecurityScanPhase,
	policy: SecurityScanPolicy,
	options: SecurityScanOptions,
	sw: ^time.Stopwatch,
) {
	if code == "" {
		return
	}
	scanner_scan_text_rules(result, code, source_name, phase, policy, options, sw)
	if !result.success {
		return
	}
	if scanner_has_ast_rules(policy) {
		scanner_scan_ast_rules(result, code, source_name, dialect, phase, policy, options, sw)
	}
}

scanner_scan_security_impl :: proc(
	source_code: string,
	dialect: ShellDialect,
	policy: SecurityScanPolicy,
	options: SecurityScanOptions,
	source_name: string,
	translated_output: string,
) -> SecurityScanResult {
	result := SecurityScanResult{
		success = true,
		ruleset_version = strings.clone(policy.ruleset_version, context.allocator),
	}

	if result.ruleset_version == "" {
		result.ruleset_version = strings.clone(SECURITY_RULESET_VERSION, context.allocator)
	}
	sw := time.Stopwatch{}
	time.stopwatch_start(&sw)

	if options.max_file_size > 0 && len(source_code) > options.max_file_size {
		scanner_append_runtime_error(
			&result,
			.ScanMaxFileSizeExceeded,
			"Input exceeds max_file_size",
			ir.SourceLocation{file = source_name},
			"Increase max_file_size or scan files individually",
			"sec.runtime.max_file_size",
		)
		time.stopwatch_stop(&sw)
		result.stats.duration_ms = i64(time.duration_milliseconds(time.stopwatch_duration(sw)))
		return result
	}

	if .Source in options.include_phases {
		scanner_scan_phase(&result, source_code, source_name, dialect, .Source, policy, options, &sw)
	}
	if result.success && options.scan_translated_output && translated_output != "" && .Translated in options.include_phases {
		scanner_scan_phase(&result, translated_output, source_name, dialect, .Translated, policy, options, &sw)
	}

	scanner_apply_allowlist(&result, policy)
	scanner_finalize(&result, policy)
	time.stopwatch_stop(&sw)
	result.stats.duration_ms = i64(time.duration_milliseconds(time.stopwatch_duration(sw)))
	return result
}

scan_security_batch :: proc(
	files: []string,
	dialect: ShellDialect,
	policy := DEFAULT_SECURITY_SCAN_POLICY,
	options := DEFAULT_SECURITY_SCAN_OPTIONS,
	allocator := context.allocator,
) -> [dynamic]SecurityBatchItemResult {
	results := make([dynamic]SecurityBatchItemResult, 0, len(files), allocator)
	for file in files {
		item := SecurityBatchItemResult{filepath = strings.clone(file, allocator)}
		item.result = scan_security_file(file, dialect, policy, options)
		append(&results, item)
	}
	return results
}

format_security_scan_json :: proc(
	result: SecurityScanResult,
	pretty := false,
	allocator := context.allocator,
) -> string {
	opt := json.Marshal_Options{}
	if pretty {
		opt.pretty = true
		opt.use_spaces = true
		opt.spaces = 2
	}
	data, err := json.marshal(result, opt, allocator)
	if err != nil {
		return strings.clone(
			fmt.tprintf("{\"success\":false,\"error\":\"json_marshal_failed\",\"message\":\"%v\"}", err),
			allocator,
		)
	}
	defer delete(data)
	return strings.clone(string(data), allocator)
}

format_security_scan_batch_json :: proc(
	results: []SecurityBatchItemResult,
	pretty := false,
	allocator := context.allocator,
) -> string {
	opt := json.Marshal_Options{}
	if pretty {
		opt.pretty = true
		opt.use_spaces = true
		opt.spaces = 2
	}
	data, err := json.marshal(results, opt, allocator)
	if err != nil {
		return strings.clone(
			fmt.tprintf("{\"success\":false,\"error\":\"json_marshal_failed\",\"message\":\"%v\"}", err),
			allocator,
		)
	}
	defer delete(data)
	return strings.clone(string(data), allocator)
}

scan_security :: proc(
	source_code: string,
	dialect: ShellDialect,
	policy := DEFAULT_SECURITY_SCAN_POLICY,
	source_name := "<input>",
	options := DEFAULT_SECURITY_SCAN_OPTIONS,
	translated_output := "",
) -> SecurityScanResult {
	return scanner_scan_security_impl(source_code, dialect, policy, options, source_name, translated_output)
}

scan_security_file :: proc(
	filepath: string,
	dialect: ShellDialect,
	policy := DEFAULT_SECURITY_SCAN_POLICY,
	options := DEFAULT_SECURITY_SCAN_OPTIONS,
) -> SecurityScanResult {
	data, ok := os.read_entire_file(filepath)
	if !ok {
		result := SecurityScanResult{
			success = false,
			ruleset_version = strings.clone(policy.ruleset_version, context.allocator),
		}
		if result.ruleset_version == "" {
			result.ruleset_version = strings.clone(SECURITY_RULESET_VERSION, context.allocator)
		}
		scanner_append_runtime_error(
			&result,
			.IOError,
			"Failed to read input file",
			ir.SourceLocation{file = filepath},
			"Check file path and permissions",
			"sec.runtime.io",
		)
		return result
	}
	defer delete(data)
	result := scanner_scan_security_impl(string(data), dialect, policy, options, filepath, "")
	result.stats.files_scanned = 1
	return result
}
