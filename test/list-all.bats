#!/usr/bin/env bats

load test_helper

setup() { setup_env; }

@test "errors on unknown option" {
  run_jjenv list-all --nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "--path requires an argument" {
  run_jjenv list-all --path
  [ "$status" -ne 0 ]
  [[ "$output" == *"--path"* ]]
}

@test "prints nothing on empty stdout when no JDKs are found" {
  run_jjenv list-all --no-defaults
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "prints one path per line for every discovered JDK" {
  jdk_a="$(make_jdk a)"
  jdk_b="$(make_jdk b)"
  run_jjenv list-all --no-defaults --path "$JJENV_TEST_JDKS"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [[ " ${lines[*]} " == *" $jdk_a "* ]]
  [[ " ${lines[*]} " == *" $jdk_b "* ]]
}

@test "dedup collapses the same JDK reached via multiple paths" {
  jdk="$(make_jdk real)"
  ln -s "$jdk" "$JJENV_TEST_JDKS/alias"
  run_jjenv list-all --no-defaults --path "$JJENV_TEST_JDKS"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = "$jdk" ]
}

@test "--unregistered hides JDKs that are already in jenv" {
  jdk_a="$(make_jdk a)"
  jdk_b="$(make_jdk b)"
  register_jdk 1.0 "$jdk_a"
  run_jjenv list-all --no-defaults --unregistered --path "$JJENV_TEST_JDKS"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = "$jdk_b" ]
}

@test "without --unregistered, already-registered JDKs are still listed" {
  jdk_a="$(make_jdk a)"
  jdk_b="$(make_jdk b)"
  register_jdk 1.0 "$jdk_a"
  run_jjenv list-all --no-defaults --path "$JJENV_TEST_JDKS"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "JJENV_JDK_PATHS env var adds extra search roots" {
  jdk="$(make_jdk env-only)"
  JJENV_JDK_PATHS="$JJENV_TEST_JDKS" run_jjenv list-all --no-defaults
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$jdk" ]
}

@test "verbose progress goes to stderr, stdout stays only paths" {
  jdk="$(make_jdk a)"
  # Capture stdout and stderr separately by re-running with a wrapper.
  out_file="$BATS_TEST_TMPDIR/stdout"
  err_file="$BATS_TEST_TMPDIR/stderr"
  "$JJENV_ROOT_DIR/bin/jjenv" list-all --no-defaults -v --path "$JJENV_TEST_JDKS" \
    >"$out_file" 2>"$err_file"
  # stdout: exactly one line, the JDK path.
  [ "$(wc -l < "$out_file" | tr -d ' ')" -eq 1 ]
  grep -qxF -- "$jdk" "$out_file"
  # stderr: contains scan/platform logs.
  grep -q "platform:" "$err_file"
  grep -q "scan" "$err_file"
}

@test "directories without bin/java are skipped" {
  mkdir -p "$JJENV_TEST_JDKS/not-a-jdk"
  run_jjenv list-all --no-defaults --path "$JJENV_TEST_JDKS"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "output of list-all --unregistered is consumable by jenv add" {
  jdk_a="$(make_jdk a)"
  jdk_b="$(make_jdk b)"
  register_jdk 1.0 "$jdk_a"
  # Pipe to xargs invoking our fake jenv.
  out="$( "$JJENV_ROOT_DIR/bin/jjenv" list-all --no-defaults --unregistered --path "$JJENV_TEST_JDKS" \
          | xargs -L1 jenv add )"
  grep -qxF "add $jdk_b" "$JJENV_LOG"
  ! grep -qxF "add $jdk_a" "$JJENV_LOG"
}
