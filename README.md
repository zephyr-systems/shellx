# ShellX

![CI](https://img.shields.io/badge/CI-local%20tests-blue)
![License](https://img.shields.io/badge/license-unspecified-lightgrey)

ShellX is an Odin library for translating shell scripts between dialects:

- Bash
- Zsh
- Fish
- POSIX shell

## Vision

ShellX aims to provide a practical shell translation pipeline that is:

- Safe to embed in other Odin projects
- Explicit about errors and compatibility limits
- Fast enough for batch translation workflows

## Features

- Dialect detection from source text and file path
- End-to-end translation pipeline:
  - Parse -> IR -> optimize -> emit
- Structured error reporting with source locations
- Compatibility analysis and optional shim discovery
- Batch and file-based translation APIs
- Builder utilities for constructing scripts in tests/examples

## Installation

ShellX is currently consumed as source in an Odin workspace.

1. Clone the repository.
2. Ensure Odin is installed and available in `PATH`.
3. Build or test from the repo root:

```bash
odin test . -all-packages
```

## Quick Start

```odin
package app

import "core:fmt"
import "shellx"

main :: proc() {
	result := shellx.translate("x=5\necho $x\n", .Bash, .Fish)
	defer shellx.destroy_translation_result(&result)

	if !result.success {
		fmt.println("translation failed")
		for err in result.errors {
			fmt.println(shellx.report_error(err))
		}
		return
	}

	fmt.println(result.output)
}
```

## Usage Examples

### Detect source dialect

```odin
dialect := shellx.detect_shell(source_code)
```

```odin
dialect := shellx.detect_shell_from_path("script.zsh", source_code)
```

### Translate from file

```odin
result := shellx.translate_file("./script.sh", .Bash, .Zsh)
defer shellx.destroy_translation_result(&result)
```

### Batch translation

```odin
results := shellx.translate_batch(files, .Bash, .Fish)
defer {
	for &r in results {
		shellx.destroy_translation_result(&r)
	}
	delete(results)
}
```

### Build scripts programmatically

```odin
builder := shellx.create_script_builder(.Bash)
defer shellx.destroy_script_builder(&builder)

shellx.script_add_var(&builder, "name", "world")
shellx.script_add_call(&builder, "echo", "hello", "$name")

output := shellx.script_emit(&builder, .Bash)
defer delete(output)
```

## Documentation

- [API reference](docs/api_reference.md)
- [Architecture](docs/architecture.md)
- [IR specification](docs/ir_spec.md)
- [Compatibility matrix](docs/compatibility_matrix.md)
- [Contributing](CONTRIBUTING.md)

## Status

ShellX is under active development. Translation quality varies by syntax pattern and dialect pair.
Run the integration tests for current coverage.
