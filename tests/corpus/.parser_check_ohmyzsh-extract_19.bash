__shellx_zsh_expand() {
  # fallback shim for zsh-only parameter expansion forms not directly translatable
  printf "%s" ""
}

alias x=extract

extract() {
  setopt localoptions noautopushd

  if (( $# == 0 )); then
:
:
:
:
:
:
  fi

  local remove_archive=1
  if [[ "$1" == "-r" ]] || [[ "$1" == "--remove" ]]; then
    remove_archive=0
    shift
  fi

  local pwd="$PWD"
  while (( $# > 0 )); do
    if [[ ! -f "$1" ]]; then
      echo "extract: '$1' is not a valid file" >&2
      shift
      continue
    fi

    local success=0
:
:

    # Remove the .tar extension if the file name is .tar.*
    if [[ $extract_dir =~ '\.tar$' ]]; then
:
    fi

    # If there's a file or directory with the same name as the archive
    # add a random string to the end of the extract directory
    if [[ -e "$extract_dir" ]]; then
:
      extract_dir="${extract_dir}-${rnd}"
    fi

    # Create an extraction directory based on the file name
    command mkdir -p "$extract_dir"
    builtin cd -q "$extract_dir"
    echo "extract: extracting to $extract_dir" >&2

:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
}