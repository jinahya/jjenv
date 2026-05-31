# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

`jjenv` is a standalone bash CLI that **wraps `jenv`** (the Java version manager at https://github.com/jenv/jenv) with extra commands jenv does not ship. It is **not** a jenv plugin — it is its own executable that shells out to `jenv` for operations on jenv's state (`~/.jenv/versions/`). `jenv` must be on `PATH` at runtime.

The first/canonical command is `jjenv add-all`: discover every JDK installed on the machine and run `jenv add` for each one not already registered.

## Running and testing

This is pure bash — no build step, no package manager, no test framework yet.

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

The `test/` directory is empty — there is no test suite yet.

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

Linux paths are coded but **not yet verified on Linux** — treat them as best-effort until tested.

## Completions

`completions/jjenv.bash` and `completions/jjenv.zsh` are sourced by the user from their shell rc. Both call `jjenv commands` to enumerate subcommands dynamically, so new commands appear in completion without editing the completion scripts — **unless** the new command takes flags, in which case add a case branch for it in both files.
