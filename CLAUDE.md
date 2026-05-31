# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

`jjenv` is a standalone bash CLI that **wraps `jenv`** (the Java version manager at https://github.com/jenv/jenv) with extra commands jenv does not ship. It is **not** a jenv plugin — it is its own executable that shells out to `jenv` for operations on jenv's state (`~/.jenv/versions/`). `jenv` must be on `PATH` at runtime.

The first/canonical command is `jjenv add-all`: discover every JDK installed on the machine and run `jenv add` for each one not already registered.

## Running and testing

This is pure bash — no build step, no package manager.

```bash
# Run the CLI directly from the repo
bin/jjenv --version
bin/jjenv commands
bin/jjenv help <command>

# Exercise add-all without touching jenv state
bin/jjenv add-all --dry-run -v

# Enable shell trace for any command
JJENV_DEBUG=1 bin/jjenv add-all --dry-run

# Point at a non-default jenv root
JENV_ROOT=/tmp/fake-jenv bin/jjenv add-all --dry-run

# Add extra JDK search roots
JJENV_JDK_PATHS=/opt/mine:/srv/jdks bin/jjenv add-all --dry-run -v
bin/jjenv add-all --dry-run --path /opt/mine --path /srv/jdks
```

### Test suite

bats lives under `test/`: `test_helper.bash` + one `.bats` file per command
(`dispatcher.bats`, `add-all.bats`, `list-all.bats`). Run with:

```bash
./run-tests.sh                          # local bats, target = test/
./run-tests.sh test/list-all.bats       # one file
./run-tests.sh --docker                 # Alpine container, CI parity (hermetic, fake JDKs)
./test/smoke-linux.sh                   # Debian + real OpenJDK, end-to-end Linux smoke
```

The bats helper isolates each test inside `$BATS_TEST_TMPDIR` with a fake
`$HOME`, a fake `$JENV_ROOT/versions/`, and a fake `jenv` on `PATH` that logs
invocations to `$JJENV_LOG`. New tests should drive discovery with
`--no-defaults --path "$JJENV_TEST_JDKS"` so they never see real JDKs on the
developer's machine.

`--docker` builds `test/Dockerfile` (Alpine + bash + bats + GNU coreutils) and
runs the same hermetic bats suite inside. It verifies that the bash code is
Linux-portable, but it does *not* exercise the Linux discovery globs against
real JDKs (the tests use fakes).

`test/smoke-linux.sh` is the separate non-hermetic smoke test: it builds
`test/smoke-linux.Dockerfile` (Debian bookworm-slim + `openjdk-17-jdk-headless`
+ a fake `jenv` stub), then runs `jjenv list-all` and `jjenv add-all --dry-run`
with **defaults enabled** and asserts that the `/usr/lib/jvm/*` glob matches
the real OpenJDK install. This is what closes the loop on the Linux discovery
branch.

Caveat: neither container ships bash 3.2, so bash 3.2 incompatibilities are
still only caught by the local macOS run.

## Target bash version: 3.2

macOS still ships bash 3.2 as `/bin/bash`, and the shebang resolves there. **Do not use bash 4+ features** (associative arrays `declare -A`, `${var,,}`, `mapfile`/`readarray`, `${!array[@]}` on assoc arrays, `coproc`, etc.). For dedup/set membership, use `sort -u` and `grep -qxF` against a newline-separated string instead of associative arrays. This already bit us once in `jjenv-add-all`.

## Architecture: dispatcher + command-per-file

Modeled on rbenv/jenv:

1. **`bin/jjenv`** is a thin entry point. It resolves its own real path (following symlinks via `readlink`/`greadlink`), prepends `libexec/` to `PATH`, then execs `libexec/jjenv`.
2. **`libexec/jjenv`** is the router. For `jjenv <cmd> <args...>`, it looks up `jjenv-<cmd>` on `PATH` (which now includes `libexec/`) and execs it. Bare `--version`/`--help` are special-cased.
3. **`libexec/jjenv-<cmd>`** scripts are the actual commands. Each must be executable and live on `PATH`. **Adding a new command = dropping a `jjenv-<name>` executable into `libexec/`.** No registration step.

`jjenv-commands` discovers commands by globbing `$PATH` entries for `jjenv-*`. This means commands shipped outside `libexec/` (e.g. a plugin dropping into a `PATH` dir) are picked up automatically.

**Shared library code** lives in `libexec/lib/*.bash` and is sourced from commands via `. "${BASH_SOURCE[0]%/*}/lib/<name>.bash"`. The `lib/` directory is invisible to `jjenv-commands` because nothing inside matches the `jjenv-*` glob. Today there's one library, `lib/jjenv-discover.bash`, shared by `add-all` and `list-all`. Its caller contract (`verbose`, `no_defaults`, `extra_paths` variables; `_jjenv_discover`, `_jjenv_load_registered`, `_jjenv_is_registered` functions) is documented in the file header — read it before adding a third consumer.

## Magic comment headers

Each command script declares its help text via shell comments at the top of the file. `jjenv-help` parses these from the file itself — there is no separate manpage or help registry.

```bash
#!/usr/bin/env bash
#
# Summary: One-line description shown by `jjenv help` (no args).
#
# Usage: jjenv my-cmd [--flag] <arg>
#
# Help: Multi-line body shown by `jjenv help my-cmd`. Can include
# blank lines (written as bare `#`) and indented option blocks.
#
```

Rules `jjenv-help`'s `extract` function enforces:
- A section starts at `# <Label>:` and ends at the next `# Summary:`/`# Usage:`/`# Help:` header **or** any non-comment line.
- A bare `#` inside a section becomes a blank line in the rendered output.
- `# ` (hash-space) lines are stripped of the prefix and printed verbatim.

If you add a new command, mirror this header convention exactly or `jjenv help <new-cmd>` will look broken.

## Path resolution conventions

- Always resolve JDK paths with `readlink -f` (or `greadlink -f` on macOS) before comparing/deduping. The same JDK frequently appears under multiple names (Homebrew Cellar vs. opt, system vs. user `JavaVirtualMachines`), and jenv stores its versions as symlinks. Resolved-path comparison is the only reliable dedup.
- jenv's state root is `${JENV_ROOT:-$HOME/.jenv}`. Respect `JENV_ROOT` — do not hardcode `~/.jenv`.

## Platform handling in `jjenv-add-all`

Discovery is platform-specific. Detection uses `uname -s`. **Only macOS and Linux are supported** — Windows (Git Bash / MSYS / Cygwin / WSL) is deliberately out of scope. Do not add Windows-shaped paths back.

- **macOS**: globs under `/Library/Java/JavaVirtualMachines`, user equivalent, Homebrew `openjdk*` formulas, plus `/usr/libexec/java_home -V` parsed for `/Contents/Home` paths.
- **Linux**: globs `/usr/lib/jvm/*`, `/usr/lib64/jvm/*`, `/opt/java|jdk|jdks/*`.
- **SDKMAN** (both platforms): `$SDKMAN_DIR/candidates/java/*` or `~/.sdkman/candidates/java/*`.
- **User-supplied**: `JJENV_JDK_PATHS` (colon-separated) and repeated `--path <dir>`.
- **`--no-defaults` / `JJENV_NO_DEFAULTS`**: skips the platform + SDKMAN scans. Tests rely on this to get a hermetic environment; users can also use it for surgical control.

When adding a new discovery path, also add a `log "scan: <pattern>"` call so `-v` output stays useful. A candidate counts only if `<path>/bin/java` exists and is executable (`add_candidate` enforces this).

Linux paths are exercised end-to-end by `test/smoke-linux.sh` against a real `openjdk-17-jdk-headless` install on Debian. Other Linux distros (Fedora's `/usr/lib64/jvm/*`, third-party tarballs under `/opt/...`) are not yet covered — extend the smoke image if you want those validated.

## Completions

`completions/jjenv.bash` and `completions/jjenv.zsh` are sourced by the user from their shell rc. Both call `jjenv commands` to enumerate subcommands dynamically, so new commands appear in completion without editing the completion scripts — **unless** the new command takes flags, in which case add a case branch for it in both files.

## Distribution

jjenv ships via a personal Homebrew tap at `jinahya/tap`:

```bash
brew install jinahya/tap/jjenv
```

The tap source is the **sibling** repo `github.com/jinahya/homebrew-tap`,
cloned at `~/gitcl/github.com/jinahya/homebrew-tap`. It is intentionally a
separate top-level repo (not a submodule) — see the rationale captured during
v0.1.0 setup. The formula `Formula/jjenv.rb` pins a tarball URL + sha256
against a tag in *this* repo.

To cut a new release:

1. Commit changes here, push to `main`.
2. `git tag vX.Y.Z && git push --tags`.
3. Compute the sha256:
   `curl -fsSL https://github.com/jinahya/jjenv/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256`.
4. In the tap repo, bump `url` and `sha256` in `Formula/jjenv.rb`, commit, push.
5. Smoke test:
   ```bash
   brew update
   brew upgrade jinahya/tap/jjenv
   brew test jjenv
   brew audit --strict --online jjenv
   ```

`_HOMEBREW_CORE.asciidoc` in this repo is the source of truth for the tap
layout, formula shape, and the eventual path to `homebrew-core`. Read it
before changing the publishing flow.

## Documentation files

- `README.md` — English README. Single source of truth for user-facing prose.
- `README_ko.md` — Korean translation. **Must be kept in sync section-by-section
  with `README.md`.** Both link to each other at the top
  (`**English** · [한국어](README_ko.md)` and vice versa). When you change one,
  change the other in the same commit.
- `_HOMEBREW_CORE.asciidoc` — notes on the personal-tap layout, the formula
  shape, and the long-term path to homebrew-core.
- `LICENSE` — MIT, © 2026 Jin Kwon. Must remain MIT for the formula's
  `license "MIT"` declaration to stay valid.
