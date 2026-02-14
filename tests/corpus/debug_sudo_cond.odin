package main
import "core:fmt"
import "core:os"
import "core:strings"
import shellx "../.."
main :: proc() {
  data, _ := os.read_entire_file("tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh")
  opts := shellx.DEFAULT_TRANSLATION_OPTIONS
  opts.insert_shims = true
  tr := shellx.translate(string(data), .Zsh, .Bash, opts)
  defer shellx.destroy_translation_result(&tr)
  lines := strings.split_lines(tr.output)
  defer delete(lines)
  for i := 80; i <= 110 && i <= len(lines); i += 1 {
    fmt.println(fmt.tprintf("%d: %s", i, lines[i-1]))
  }
}
