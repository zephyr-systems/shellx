package unit_tests

import "../../detection"
import "core:strings"
import "core:testing"

LOCAL_SHELLX_TEST_NAME :: #config(LOCAL_SHELLX_TEST_NAME, "")

should_run_local_test :: proc(name: string) -> bool {
	if LOCAL_SHELLX_TEST_NAME == "" {
		return true
	}
	return strings.contains(name, LOCAL_SHELLX_TEST_NAME)
}

@(test)
test_detection_extension :: proc(t: ^testing.T) {
	if !should_run_local_test("test_detection_extension") { return }

	res := detection.detect_shell_from_path("script.zsh", "echo hi")
	testing.expect(t, res.dialect == .Zsh, "Extension .zsh should detect Zsh")
	testing.expect(t, res.method == .Extension, "Detection method should be extension")
	testing.expect(t, res.confidence >= 0.90, "Extension detection confidence should be high")
}

@(test)
test_detection_shebang :: proc(t: ^testing.T) {
	if !should_run_local_test("test_detection_shebang") { return }

	code := "#!/usr/bin/env fish\necho hi\n"
	res := detection.detect_dialect(code, "")
	testing.expect(t, res.dialect == .Fish, "Shebang should detect Fish")
	testing.expect(t, res.method == .Shebang, "Method should be shebang")
}

@(test)
test_detection_content :: proc(t: ^testing.T) {
	if !should_run_local_test("test_detection_content") { return }

	code := "set -g name value\nfunction greet\n echo hi\nend\n"
	res := detection.detect_dialect(code, "unknown")
	testing.expect(t, res.dialect == .Fish, "Fish-like content should detect Fish")
	testing.expect(t, res.method == .Content || res.method == .Unknown, "Method should be content fallback")
}

@(test)
test_detection_combined_priority :: proc(t: ^testing.T) {
	if !should_run_local_test("test_detection_combined_priority") { return }

	code := "#!/usr/bin/env bash\necho hi\n"
	res := detection.detect_dialect(code, "script.zsh")
	testing.expect(t, res.dialect == .Zsh, "Extension should win over shebang in current implementation")
}

@(test)
test_detection_confidence_range :: proc(t: ^testing.T) {
	if !should_run_local_test("test_detection_confidence_range") { return }

	res := detection.detect_dialect("echo hello", "noext")
	testing.expect(t, res.confidence >= 0.0 && res.confidence <= 1.0, "Confidence should be in [0,1]")
}
