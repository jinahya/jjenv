# Shared helpers for jjenv bats tests.
#
# Each test runs in an isolated $BATS_TEST_TMPDIR:
#   - $JJENV_TEST_HOME      fake $HOME (used for ~/.jenv if JENV_ROOT unset)
#   - $JENV_ROOT            fake jenv state root (versions live here as symlinks)
#   - $JJENV_TEST_JDKS      directory holding fake JDK trees
#   - $JJENV_TEST_BIN       directory prepended to PATH; holds a fake `jenv`
#
# Each test calls `setup_env` from its setup() and uses make_jdk / register_jdk /
# fake_jenv to build the world it wants.

JJENV_ROOT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

_canon() { (cd "$1" && pwd -P); }

setup_env() {
  mkdir -p "$BATS_TEST_TMPDIR/home" \
           "$BATS_TEST_TMPDIR/jenv/versions" \
           "$BATS_TEST_TMPDIR/jdks" \
           "$BATS_TEST_TMPDIR/bin"
  # Canonicalize so test variables match the resolved paths add-all produces.
  export JJENV_TEST_HOME="$(_canon "$BATS_TEST_TMPDIR/home")"
  export JENV_ROOT="$(_canon "$BATS_TEST_TMPDIR/jenv")"
  export JJENV_TEST_JDKS="$(_canon "$BATS_TEST_TMPDIR/jdks")"
  export JJENV_TEST_BIN="$(_canon "$BATS_TEST_TMPDIR/bin")"
  export JJENV_LOG="$BATS_TEST_TMPDIR/jenv.log"
  export HOME="$JJENV_TEST_HOME"
  # Keep a minimal PATH so coreutils still work but our fake `jenv` wins.
  export PATH="$JJENV_TEST_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
  # Make sure no real jenv state leaks in via env.
  unset JJENV_DEBUG JJENV_JDK_PATHS SDKMAN_DIR JJENV_NO_DEFAULTS
  fake_jenv
}

# Create a fake JDK Home at $JJENV_TEST_JDKS/<name> with an executable bin/java.
make_jdk() {
  local name="$1"
  local dir="$JJENV_TEST_JDKS/$name"
  mkdir -p "$dir/bin"
  cat > "$dir/bin/java" <<'EOF'
#!/usr/bin/env bash
echo "fake jdk"
EOF
  chmod +x "$dir/bin/java"
  echo "$dir"
}

# Register an existing JDK path with the fake jenv root by symlinking it into
# $JENV_ROOT/versions/<version>.
register_jdk() {
  local version="$1" path="$2"
  ln -sfn "$path" "$JENV_ROOT/versions/$version"
}

# Drop a fake `jenv` executable on PATH that just logs invocations to
# $BATS_TEST_TMPDIR/jenv.log so tests can assert what was called.
fake_jenv() {
  cat > "$JJENV_TEST_BIN/jenv" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "$JJENV_LOG"
EOF
  chmod +x "$JJENV_TEST_BIN/jenv"
  : > "$JJENV_LOG"
}

# Run jjenv with PATH that includes our fake $JJENV_TEST_BIN ahead of the real
# system PATH but excludes the user's normal PATH so tests are reproducible.
run_jjenv() {
  run "$JJENV_ROOT_DIR/bin/jjenv" "$@"
}
