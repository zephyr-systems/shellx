// Example: ShellX Demo
// This file demonstrates how to use the ShellX library API.
// ShellX is a library package - import it with: import "shellx"

package main

import ".."
import "core:fmt"

main :: proc() {
	fmt.println("ShellX Library Demo")
	fmt.println("===================\n")

	// Example 1: Simple variable assignment
	fmt.println("Example 1: Variable Assignment")
	bash_code := `x=5`
	result := shellx.translate(bash_code, .Bash, .Bash)
	fmt.printf("Input:  %s\n", bash_code)
	fmt.printf("Output: %s\n", result.output)
	fmt.printf("Success: %v\n\n", result.success)

	// Example 2: Function definition
	fmt.println("Example 2: Function Definition")
	bash_func := `function hello() {
	echo "Hello, World!"
}`
	result2 := shellx.translate(bash_func, .Bash, .Bash)
	fmt.printf("Input:\n%s\n", bash_func)
	fmt.printf("Output:\n%s\n", result2.output)
	fmt.printf("Success: %v\n\n", result2.success)

	// Example 3: Detect shell dialect
	fmt.println("Example 3: Shell Detection")
	code_with_shebang := "#!/bin/bash\necho hello"
	detected := shellx.detect_shell(code_with_shebang)
	fmt.printf("Code starts with shebang: %s\n", code_with_shebang)
	fmt.printf("Detected dialect: %v\n\n", detected)

	fmt.println("Demo complete!")
}
