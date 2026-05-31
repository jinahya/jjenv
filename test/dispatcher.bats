#!/usr/bin/env bats

load test_helper

setup() { setup_env; }

@test "--version prints jjenv and a version" {
  run_jjenv --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^jjenv\ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "no args prints version + help and exits non-zero" {
  run_jjenv
  [ "$status" -ne 0 ]
  [[ "$output" == *"jjenv"* ]]
  [[ "$output" == *"Usage:"* ]]
}

@test "unknown command exits non-zero with a clear error" {
  run_jjenv not-a-real-command
  [ "$status" -ne 0 ]
  [[ "$output" == *"no such command"* ]]
  [[ "$output" == *"not-a-real-command"* ]]
}

@test "commands lists the built-in commands" {
  run_jjenv commands
  [ "$status" -eq 0 ]
  [[ "$output" == *"add-all"* ]]
  [[ "$output" == *"commands"* ]]
  [[ "$output" == *"help"* ]]
}

@test "help (no args) shows summaries for each command" {
  run_jjenv help
  [ "$status" -eq 0 ]
  [[ "$output" == *"add-all"* ]]
  [[ "$output" == *"Discover all installed JDKs"* ]]
}

@test "help add-all renders Usage and Help sections" {
  run_jjenv help add-all
  [ "$status" -eq 0 ]
  [[ "$output" == *"jjenv add-all"* ]]
  [[ "$output" == *"--dry-run"* ]]
  [[ "$output" == *"JJENV_JDK_PATHS"* ]]
  # Bare `#` lines in the source must render as blank lines, not literal `#`.
  ! [[ "$output" =~ ^#$ ]]
}

@test "help on unknown command errors" {
  run_jjenv help not-a-real-command
  [ "$status" -ne 0 ]
  [[ "$output" == *"no such command"* ]]
}
