_jjenv() {
  local cur prev
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  if [ "$COMP_CWORD" -eq 1 ]; then
    local commands
    commands="$(jjenv commands 2>/dev/null)"
    COMPREPLY=( $(compgen -W "$commands --version --help" -- "$cur") )
    return 0
  fi

  case "${COMP_WORDS[1]}" in
  add-all )
    COMPREPLY=( $(compgen -W "--dry-run --verbose --no-defaults --path --help" -- "$cur") )
    ;;
  list-all )
    COMPREPLY=( $(compgen -W "--verbose --no-defaults --unregistered --path --help" -- "$cur") )
    ;;
  help )
    local commands
    commands="$(jjenv commands 2>/dev/null)"
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    ;;
  esac
}
complete -F _jjenv jjenv
