package detection

import "../ir"
import "core:strings"

// DetectionMethod represents how the dialect was detected
DetectionMethod :: enum {
	Unknown, // Could not determine
	Extension, // From file extension (.sh, .bash, .zsh, .fish)
	Shebang, // From shebang line (#!/bin/bash)
	Content, // From content analysis
}

// DetectionResult contains the result of dialect detection
DetectionResult :: struct {
	dialect:    ir.ShellDialect,
	method:     DetectionMethod,
	confidence: f32, // 0.0 to 1.0
}

// detect_dialect is the main entry point for dialect detection
// It tries multiple methods in order of confidence:
// 1. Extension (highest confidence: 0.95)
// 2. Shebang (medium confidence: 0.90)
// 3. Content analysis (lower confidence: 0.70)
// 4. Default to Bash (lowest confidence: 0.30)
detect_dialect :: proc(code: string, filepath: string) -> DetectionResult {
	// Try extension first
	result := detect_from_extension(filepath)
	if result.confidence >= 0.95 {
		return result
	}

	// Try shebang second
	result = detect_from_shebang(code)
	if result.confidence >= 0.90 {
		return result
	}

	// Try content analysis third
	result = detect_from_content(code)
	if result.confidence >= 0.70 {
		return result
	}

	// Default to Bash
	return DetectionResult{dialect = .Bash, method = .Unknown, confidence = 0.30}
}

// detect_from_extension detects dialect from file extension
// Confidence: 0.95
// Handles: .sh, .bash, .zsh, .fish
detect_from_extension :: proc(filepath: string) -> DetectionResult {
	// Extract extension
	dot_idx := strings.last_index(filepath, ".")
	if dot_idx < 0 {
		return DetectionResult{.Bash, .Extension, 0.0}
	}

	ext := strings.to_lower(filepath[dot_idx:])

	switch ext {
	case ".bash":
		return DetectionResult{.Bash, .Extension, 0.95}
	case ".zsh":
		return DetectionResult{.Zsh, .Extension, 0.95}
	case ".fish":
		return DetectionResult{.Fish, .Extension, 0.95}
	case ".sh":
		// .sh is ambiguous, could be Bash or POSIX
		return DetectionResult{.Bash, .Extension, 0.50}
	}

	return DetectionResult{.Bash, .Extension, 0.0}
}

// detect_from_shebang detects dialect from shebang line
// Confidence: 0.90
// Handles: #!/bin/bash, #!/usr/bin/env zsh, #!/bin/fish, etc.
detect_from_shebang :: proc(code: string) -> DetectionResult {
	// Get first line
	nl_idx := strings.index(code, "\n")
	first_line := code
	if nl_idx >= 0 {
		first_line = code[:nl_idx]
	}

	// Must start with shebang
	if !strings.has_prefix(first_line, "#!") {
		return DetectionResult{.Bash, .Shebang, 0.0}
	}

	lower_line := strings.to_lower(first_line)

	// Check for shell names
	if strings.contains(lower_line, "bash") {
		return DetectionResult{.Bash, .Shebang, 0.90}
	}
	if strings.contains(lower_line, "zsh") {
		return DetectionResult{.Zsh, .Shebang, 0.90}
	}
	if strings.contains(lower_line, "fish") {
		return DetectionResult{.Fish, .Shebang, 0.90}
	}
	if strings.contains(lower_line, "sh") {
		// Generic sh, assume Bash
		return DetectionResult{.Bash, .Shebang, 0.60}
	}

	return DetectionResult{.Bash, .Shebang, 0.0}
}

// detect_from_content detects dialect from content heuristics
// Confidence: 0.70
// Uses various patterns unique to each shell
detect_from_content :: proc(code: string) -> DetectionResult {
	bash_score := 0
	zsh_score := 0
	fish_score := 0

	lower_code := strings.to_lower(code)

	// Bash patterns
	bash_patterns := []string {
		"[[", // Bash test syntax
		"]]",
		"declare ", // Bash declare
		"local ", // Bash local (also in Zsh but more common in Bash)
		"source ", // Bash source
		"function ", // Bash function keyword
	}

	// Zsh patterns
	zsh_patterns := []string {
		"typeset ", // Zsh typeset
		"setopt ", // Zsh setopt
		"autoload ", // Zsh autoload
		"zmodload ", // Zsh module loading
		"print ", // Zsh print builtin
		"[[ ", // Zsh uses [[ ]] more than Bash
	}

	// Fish patterns
	fish_patterns := []string {
		"function ", // Fish function keyword
		"end", // Fish end keyword
		"set ", // Fish set command
		"set -g ", // Fish global flag
		"set -l ", // Fish local flag
		"string ", // Fish string builtin
		"status ", // Fish status builtin
	}

	// Count matches
	for pattern in bash_patterns {
		if strings.contains(lower_code, pattern) {
			bash_score += 1
		}
	}

	for pattern in zsh_patterns {
		if strings.contains(lower_code, pattern) {
			zsh_score += 1
		}
	}

	for pattern in fish_patterns {
		if strings.contains(lower_code, pattern) {
			fish_score += 1
		}
	}

	// Determine winner
	if bash_score > zsh_score && bash_score > fish_score && bash_score > 0 {
		return DetectionResult{.Bash, .Content, 0.70}
	}
	if zsh_score > bash_score && zsh_score > fish_score && zsh_score > 0 {
		return DetectionResult{.Zsh, .Content, 0.70}
	}
	if fish_score > bash_score && fish_score > zsh_score && fish_score > 0 {
		return DetectionResult{.Fish, .Content, 0.70}
	}

	return DetectionResult{.Bash, .Content, 0.0}
}

// detect_shell_from_path is a convenience function that uses filepath
detect_shell_from_path :: proc(filepath: string, code: string) -> DetectionResult {
	return detect_dialect(code, filepath)
}
