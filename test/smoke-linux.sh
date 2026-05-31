#!/usr/bin/env bash
# End-to-end smoke test of jjenv's Linux discovery against a real OpenJDK
# install inside a Debian container. Verifies the /usr/lib/jvm/* glob actually
# matches the distro's JDK layout — something the hermetic bats suite cannot do.
#
# Independent from ./run-tests.sh.
#
# Usage:
#   test/smoke-linux.sh
#
set -e

cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null 2>&1; then
  echo "smoke-linux.sh: docker not found on PATH" >&2
  exit 127
fi

docker build -f test/smoke-linux.Dockerfile -t jjenv:smoke-linux . >&2

exec docker run --rm jjenv:smoke-linux bash -c '
set -e

echo "==> JDK layout in container:"
ls -1 /usr/lib/jvm/ 2>/dev/null || true
echo

echo "==> jjenv list-all -v (defaults enabled):"
jjenv list-all -v

echo
echo "==> assertion: list-all found a JDK under /usr/lib/jvm/"
jjenv list-all | grep -q "^/usr/lib/jvm/" \
  || { echo "FAIL: no /usr/lib/jvm/ JDK in list-all output" >&2; exit 1; }

echo
echo "==> jjenv add-all --dry-run -v (defaults enabled):"
jjenv add-all --dry-run -v

echo
echo "==> assertion: add-all proposes adding the /usr/lib/jvm/ JDK"
jjenv add-all --dry-run | grep -q "^would add: /usr/lib/jvm/" \
  || { echo "FAIL: add-all did not propose adding /usr/lib/jvm/ JDK" >&2; exit 1; }

echo
echo "SMOKE TEST PASSED"
'
