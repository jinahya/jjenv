#compdef jjenv

_jjenv() {
  local -a commands
  local state

  _arguments -C \
    '1: :->command' \
    '*:: :->args'

  case "$state" in
  command )
    commands=(${(f)"$(jjenv commands 2>/dev/null)"})
    _describe -t commands 'jjenv command' commands
    _values 'options' '--version[print version]' '--help[show help]'
    ;;
  args )
    case "$words[1]" in
    add-all )
      _arguments \
        '(-n --dry-run)'{-n,--dry-run}'[do not call jenv add]' \
        '(-v --verbose)'{-v,--verbose}'[print scanned paths]' \
        '--no-defaults[skip built-in scans]' \
        '*--path[extra search root]:dir:_files -/' \
        '(-h --help)'{-h,--help}'[show help]'
      ;;
    list-all )
      _arguments \
        '(-v --verbose)'{-v,--verbose}'[log scan progress to stderr]' \
        '--no-defaults[skip built-in scans]' \
        '--unregistered[only print JDKs not yet in jenv]' \
        '*--path[extra search root]:dir:_files -/' \
        '(-h --help)'{-h,--help}'[show help]'
      ;;
    help )
      commands=(${(f)"$(jjenv commands 2>/dev/null)"})
      _describe -t commands 'command' commands
      ;;
    esac
    ;;
  esac
}

_jjenv "$@"
