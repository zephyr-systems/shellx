package shellx

import "core:fmt"

main :: proc() {
	fmt.println("ShellX - Shell Translation Engine")
	fmt.println("================================\n")

	// Test Case 1: Simple variable assignment
	fmt.println("--- Test Case 1: Simple variable assignment ---")
	bash_code_1 := `x=5`
	result_1 := translate(bash_code_1, .Bash, .Bash)
	fmt.printf("Input: '%s'\n", bash_code_1)
	fmt.printf("Success: %v, Output: '%s'\n", result_1.success, result_1.output)
	fmt.printf("Error: %v\n\n", result_1.error)

	// Test Case 2: Function definition
	fmt.println("--- Test Case 2: Function definition ---")
	bash_code_2 := `
function hello() {
	echo "Hello, World!"
}
`
	result_2 := translate(bash_code_2, .Bash, .Bash)
	fmt.printf("Input: '%s'\n", bash_code_2)
	fmt.printf("Success: %v, Output: '%s'\n", result_2.success, result_2.output)
	fmt.printf("Error: %v\n\n", result_2.error)

	// Test Case 3: If-else statement
	fmt.println("--- Test Case 3: If-else statement ---")
	bash_code_3 := `
if [ "$x" -eq 5 ]; then
	echo "x is 5"
else
	echo "x is not 5"
fi
`
	result_3 := translate(bash_code_3, .Bash, .Bash)
	fmt.printf("Input: '%s'\n", bash_code_3)
	fmt.printf("Success: %v, Output: '%s'\n", result_3.success, result_3.output)
	fmt.printf("Error: %v\n\n", result_3.error)

	// Test Case 4: For loop
	fmt.println("--- Test Case 4: For loop ---")
	bash_code_4 := `
for i in 1 2 3; do
	echo "Number: $i"
done
`
	result_4 := translate(bash_code_4, .Bash, .Bash)
	fmt.printf("Input: '%s'\n", bash_code_4)
	fmt.printf("Success: %v, Output: '%s'\n", result_4.success, result_4.output)
	fmt.printf("Error: %v\n\n", result_4.error)

	fmt.println("Done.")
}
