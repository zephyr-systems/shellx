# Compatibility Matrix

Compatibility is evaluated by comparing source and target shell capabilities.

## Feature Support by Dialect

| Feature | Bash | Zsh | Fish | POSIX |
|---|---|---|---|---|
| Arrays | Yes | Yes | No (lists) | No |
| Associative arrays | Yes | Yes | No | No |
| Process substitution | Yes | Yes | No | No |
| Command substitution | Yes | Yes | Yes | Yes |
| Brace expansion | Yes | Yes | Yes | No |
| Parameter expansion modifiers | Yes | Yes | No | Partial |
| Here documents | Yes | Yes | No | Yes |
| Local variables | Yes | Yes | Yes | No |
| Functions | Yes | Yes | Yes | Yes |
| Pipelines | Yes | Yes | Yes | Yes |

Source: capability declarations in `compat/capabilities.odin`.

## Known Incompatibilities

Most common high-friction paths:

- `Bash/Zsh -> Fish`
  - arrays
  - associative arrays
  - process substitution
  - parameter expansion modifiers
  - here documents

- `* -> POSIX`
  - non-POSIX shell features are not guaranteed to preserve behavior

## Available Shims

`compat/shims.odin` defines shim categories:

- `ArrayToList`
- `ParameterExpansion`
- `ProcessSubstitution`

`insert_shims` currently collects required shim feature names in result metadata.

## Workaround Suggestions

- Arrays to Fish: use `set arr one two three` patterns.
- Process substitution in Fish: temp-file based workaround.
- Parameter expansion in Fish: use `string` builtin equivalents.
- POSIX target: avoid shell-specific extensions (`[[ ]]`, associative arrays, etc.).

## Explicit Failure Boundaries

ShellX fails explicitly (never silently) for these constructs:

| Construct | Target | Reason |
|---|---|---|
| `zle`, `bindkey` | POSIX | No readline editing API in POSIX `sh`; keybinding/widget semantics cannot be preserved |
| Zsh `zstyle` theming | POSIX | No equivalent style/theming model in POSIX shell |
| Fish `abbr` | POSIX | Abbreviation expansion is interactive-shell behavior with no POSIX equivalent |

For corpus-covered paths outside these boundaries, ShellX targets behavioral parity and reports degraded/unsupported features in `TranslationResult` metadata.
