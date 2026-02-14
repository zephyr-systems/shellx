package main
import shellx "../.."
import "core:fmt"
import "core:os"
main :: proc() {
  data, ok := os.read_entire_file("tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh")
  if !ok { fmt.println("read fail"); return }
  opts := shellx.DEFAULT_TRANSLATION_OPTIONS
  opts.insert_shims = true
  tr := shellx.translate(string(data), .Zsh, .Bash, opts)
  defer shellx.destroy_translation_result(&tr)
  fmt.println("success", tr.success)
  _ = os.write_entire_file("/tmp/omz_z_dbg.bash", transmute([]byte)tr.output)
  fmt.println("wrote", len(tr.output))
}
