#!/usr/bin/env bash
# Run the jjenv test suite with bats.
#
# Usage:
#   ./run-tests.sh [bats args...]            Run bats locally (default target: test/).
#   ./run-tests.sh --docker [bats args...]   Run inside a Linux container for CI parity.
#
# The Docker mode catches Linux-portability bugs, but the container ships modern
# bash — bash 3.2 incompatibilities are still only caught by the local macOS run.
#
set -e

cd "$(dirname "$0")"

if [ "${1-}" = "--docker" ]; then
  shift
  if [ "$#" -eq 0 ]; then set -- test; fi
  docker build -f test/Dockerfile -t jjenv:test . >&2
  exec docker run --rm jjenv:test bats "$@"
fi

if ! command -v bats >/dev/null 2>&1; then
  echo "run-tests.sh: 'bats' not found on PATH" >&2
  echo "  install with: brew install bats-core   # or see https://github.com/bats-core/bats-core" >&2
  echo "  or run in a container:  ./run-tests.sh --docker" >&2
  exit 127
fi

if [ "$#" -eq 0 ]; then set -- test; fi
exec bats "$@"
