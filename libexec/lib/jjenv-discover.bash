# Shared JDK discovery for jjenv commands.
#
# Sourced by libexec/jjenv-add-all and libexec/jjenv-list-all. NOT a standalone
# command (it lives outside the jjenv-<cmd> naming so jjenv-commands ignores it).
#
# Caller contract:
#   verbose       bool: "true"/"false"; controls log output to stderr.
#   no_defaults   bool: when "true", skips built-in platform + SDKMAN scans.
#   extra_paths   array: extra search roots (from --path).
#   JJENV_JDK_PATHS env: colon-separated extra roots.
#   JENV_ROOT env: jenv state directory; defaults to $HOME/.jenv.
#
# Provides:
#   _jjenv_resolve <path>     -> canonical (symlink-followed) path on stdout.
#   _jjenv_discover           -> prints unique resolved JDK Home paths, one per
#                                line, on stdout. May log scan progress to stderr.
#   _jjenv_load_registered    -> populates `registered_list` (newline-separated
#                                resolved paths from $JENV_ROOT/versions/).
#   _jjenv_is_registered <p>  -> exit 0 if $p (resolved) is in registered_list.

_jjenv_log() { $verbose && echo "  $*" >&2 || true; }

_jjenv_resolve() {
  local p="$1"
  if command -v greadlink >/dev/null 2>&1; then
    greadlink -f "$p" 2>/dev/null || echo "$p"
  else
    readlink -f "$p" 2>/dev/null || echo "$p"
  fi
}

# Internal: appends $1 to `candidates` if it looks like a JDK Home.
_jjenv_add_candidate() {
  local p="$1"
  [ -d "$p" ] || return 0
  [ -x "$p/bin/java" ] || return 0
  candidates+=("$p")
}

# Internal: scan a glob pattern and add each match as a candidate.
_jjenv_scan_glob() {
  local pattern="$1"
  _jjenv_log "scan: $pattern"
  local p
  for p in $pattern; do
    [ -e "$p" ] || continue
    _jjenv_add_candidate "$p"
  done
}

_jjenv_discover() {
  local uname_s platform
  uname_s="$(uname -s 2>/dev/null || echo unknown)"
  case "$uname_s" in
  Darwin* ) platform=macos ;;
  Linux*  ) platform=linux ;;
  *       ) platform=unknown ;;
  esac
  _jjenv_log "platform: $platform"

  local candidates=()

  if ! $no_defaults; then
    case "$platform" in
    macos )
      _jjenv_scan_glob "/Library/Java/JavaVirtualMachines/*/Contents/Home"
      _jjenv_scan_glob "$HOME/Library/Java/JavaVirtualMachines/*/Contents/Home"
      _jjenv_scan_glob "/opt/homebrew/opt/openjdk*/libexec/openjdk.jdk/Contents/Home"
      _jjenv_scan_glob "/usr/local/opt/openjdk*/libexec/openjdk.jdk/Contents/Home"
      if [ -x /usr/libexec/java_home ]; then
        _jjenv_log "scan: /usr/libexec/java_home -V"
        local p
        while IFS= read -r p; do
          _jjenv_add_candidate "$p"
        done < <(/usr/libexec/java_home -V 2>&1 | awk -F'"' '/\/Contents\/Home/ { for (i=1;i<=NF;i++) if ($i ~ /\/Contents\/Home/) print $i }')
      fi
      ;;
    linux )
      _jjenv_scan_glob "/usr/lib/jvm/*"
      _jjenv_scan_glob "/usr/lib64/jvm/*"
      _jjenv_scan_glob "/opt/java/*"
      _jjenv_scan_glob "/opt/jdk/*"
      _jjenv_scan_glob "/opt/jdks/*"
      ;;
    * )
      echo "jjenv: unsupported platform: $uname_s" >&2
      ;;
    esac

    # SDKMAN
    if [ -n "${SDKMAN_DIR-}" ]; then
      _jjenv_scan_glob "$SDKMAN_DIR/candidates/java/*"
    elif [ -d "$HOME/.sdkman/candidates/java" ]; then
      _jjenv_scan_glob "$HOME/.sdkman/candidates/java/*"
    fi
  fi

  # user-supplied roots: JJENV_JDK_PATHS env (colon-separated)
  if [ -n "${JJENV_JDK_PATHS-}" ]; then
    local oldIFS="$IFS" root
    IFS=:
    for root in $JJENV_JDK_PATHS; do
      IFS="$oldIFS"
      _jjenv_log "scan (env): $root"
      _jjenv_add_candidate "$root"
      _jjenv_scan_glob "$root/*"
      _jjenv_scan_glob "$root/*/Contents/Home"
    done
    IFS="$oldIFS"
  fi
  # user-supplied roots: --path
  local root
  for root in "${extra_paths[@]+"${extra_paths[@]}"}"; do
    _jjenv_log "scan (--path): $root"
    _jjenv_add_candidate "$root"
    _jjenv_scan_glob "$root/*"
    _jjenv_scan_glob "$root/*/Contents/Home"
  done

  [ "${#candidates[@]}" -gt 0 ] || return 0
  local p
  for p in "${candidates[@]}"; do _jjenv_resolve "$p"; done | sort -u
}

_jjenv_load_registered() {
  registered_list=""
  local jenv_root="${JENV_ROOT:-$HOME/.jenv}"
  [ -d "$jenv_root/versions" ] || return 0
  local v
  for v in "$jenv_root"/versions/*; do
    [ -e "$v" ] || continue
    registered_list="${registered_list}$(_jjenv_resolve "$v")"$'\n'
  done
}

_jjenv_is_registered() {
  [ -n "${registered_list-}" ] || return 1
  printf '%s' "$registered_list" | grep -qxF -- "$1"
}
