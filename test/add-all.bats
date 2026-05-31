#!/usr/bin/env bats

load test_helper

setup() { setup_env; }

@test "errors when jenv is not on PATH" {
  rm -f "$JJENV_TEST_BIN/jenv"
  run_jjenv add-all --dry-run --no-defaults
  [ "$status" -ne 0 ]
  [[ "$output" == *"jenv"* ]]
  [[ "$output" == *"not found"* ]]
}

@test "errors on unknown option" {
  run_jjenv add-all --nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "--path requires an argument" {
  run_jjenv add-all --path
  [ "$status" -ne 0 ]
  [[ "$output" == *"--path"* ]]
}

@test "prints a no-JDKs message when nothing is found" {
  run_jjenv add-all --dry-run --no-defaults
  [ "$status" -eq 0 ]
  [[ "$output" == *"no JDKs found"* ]]
}

@test "--dry-run with --path discovers JDKs without calling jenv add" {
  jdk_a="$(make_jdk a)"
  jdk_b="$(make_jdk b)"
  run_jjenv add-all --dry-run --no-defaults --path "$JJENV_TEST_JDKS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would add: $jdk_a"* ]]
  [[ "$output" == *"would add: $jdk_b"* ]]
  [[ "$output" == *"2 would be added"* ]]
  # Dry-run must not call jenv.
  [ ! -s "$JJENV_LOG" ]
}

@test "already-registered JDKs are skipped with a note" {
  jdk_a="$(make_jdk a)"
  jdk_b="$(make_jdk b)"
  register_jdk 1.0 "$jdk_a"
  run_jjenv add-all --dry-run --no-defaults --path "$JJENV_TEST_JDKS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already added: $jdk_a"* ]]
  [[ "$output" == *"would add: $jdk_b"* ]]
  [[ "$output" == *"1 would be added, 1 already registered"* ]]
}

@test "dedup collapses the same JDK reached via multiple paths" {
  jdk="$(make_jdk real)"
  ln -s "$jdk" "$JJENV_TEST_JDKS/alias"
  run_jjenv add-all --dry-run --no-defaults --path "$JJENV_TEST_JDKS"
  [ "$status" -eq 0 ]
  count="$(printf '%s\n' "$output" | grep -c 'would add:' || true)"
  [ "$count" -eq 1 ]
}

@test "verbose mode prints scan progress" {
  make_jdk a >/dev/null
  run_jjenv add-all --dry-run -v --no-defaults --path "$JJENV_TEST_JDKS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"scan"* ]]
  [[ "$output" == *"platform:"* ]]
}

@test "JJENV_JDK_PATHS env var adds extra search roots" {
  jdk="$(make_jdk env-only)"
  JJENV_JDK_PATHS="$JJENV_TEST_JDKS" run_jjenv add-all --dry-run --no-defaults
  [ "$status" -eq 0 ]
  [[ "$output" == *"would add: $jdk"* ]]
}

@test "JJENV_NO_DEFAULTS env var disables built-in scans" {
  jdk="$(make_jdk a)"
  JJENV_NO_DEFAULTS=1 run_jjenv add-all --dry-run --path "$JJENV_TEST_JDKS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would add: $jdk"* ]]
}

@test "without --dry-run, jenv add is invoked for each new JDK" {
  jdk_a="$(make_jdk a)"
  jdk_b="$(make_jdk b)"
  run_jjenv add-all --no-defaults --path "$JJENV_TEST_JDKS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"adding: $jdk_a"* ]]
  [[ "$output" == *"adding: $jdk_b"* ]]
  grep -qxF "add $jdk_a" "$JJENV_LOG"
  grep -qxF "add $jdk_b" "$JJENV_LOG"
}

@test "without --dry-run, jenv add is skipped for already-registered JDKs" {
  jdk_a="$(make_jdk a)"
  jdk_b="$(make_jdk b)"
  register_jdk 1.0 "$jdk_a"
  run_jjenv add-all --no-defaults --path "$JJENV_TEST_JDKS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already added: $jdk_a"* ]]
  [[ "$output" == *"adding: $jdk_b"* ]]
  grep -qxF "add $jdk_b" "$JJENV_LOG"
  ! grep -qxF "add $jdk_a" "$JJENV_LOG"
}

@test "directories without bin/java are not treated as JDKs" {
  mkdir -p "$JJENV_TEST_JDKS/not-a-jdk"
  run_jjenv add-all --dry-run --no-defaults --path "$JJENV_TEST_JDKS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no JDKs found"* ]]
}
