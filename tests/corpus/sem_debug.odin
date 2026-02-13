package main
import shellx "../.."
import "core:fmt"
import "core:os"
import "core:os/os2"

main :: proc() {
	src := "set arr one two three\necho $arr[2]"
	opts := shellx.DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	tr := shellx.translate(src, .Fish, .Bash, opts)
	defer shellx.destroy_translation_result(&tr)
	fmt.println("success", tr.success)
	fmt.println(tr.output)
	_ = os.write_entire_file("/tmp/sem_array.bash", transmute([]byte)tr.output)
	state, out, err_out, err := os2.process_exec(os2.Process_Desc{command = []string{"bash", "/tmp/sem_array.bash"}}, context.allocator)
	if err != nil {
		fmt.println("err", err)
		return
	}
	fmt.println("exit", state.exit_code)
	fmt.println("stdout", string(out))
	fmt.println("stderr", string(err_out))
}
