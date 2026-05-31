# jjenv

**English** · [한국어](README_ko.md)

Extra commands for [jenv](https://github.com/jenv/jenv), the Java version manager.

`jjenv` is a standalone bash CLI that wraps `jenv` and adds operations jenv does not ship out of the box. It does **not** replace jenv — `jenv` must be installed and on your `PATH`.

## Status

Early. Two commands (`list-all`, `add-all`) are implemented and working. Tested on macOS and inside a Linux container (Alpine, via `./run-tests.sh --docker`) — 31/31 bats tests pass on both. Real-world Linux usage with actual `/usr/lib/jvm/*` JDKs is still unverified.

## Requirements

- `jenv` on `PATH`
- `bash` (any version ≥ 3.2 — works with the macOS system bash)

## Install

### Homebrew (recommended)

```bash
brew install jinahya/tap/jjenv
```

`jenv` is pulled in automatically as a dependency. Bash and zsh completions are installed by Homebrew — restart your shell (or `source $(brew --prefix)/etc/profile.d/bash_completion.sh` for bash) to pick them up.

### From source

Clone the repo and put `bin/` on your `PATH`:

```bash
git clone https://github.com/jinahya/jjenv.git ~/.jjenv
export PATH="$HOME/.jjenv/bin:$PATH"
```

Optional shell completion:

```bash
# bash
source ~/.jjenv/completions/jjenv.bash

# zsh
fpath=(~/.jjenv/completions $fpath)
source ~/.jjenv/completions/jjenv.zsh
```

## Commands

```
jjenv list-all    List all installed JDK paths suitable for `jenv add`
jjenv add-all     Discover all installed JDKs and register them with jenv
jjenv commands    List all available jjenv commands
jjenv help        Display help for a command
```

Run `jjenv help <command>` for details.

### `jjenv list-all`

Prints discovered JDK Home paths to stdout, one per line. Each line is exactly what you would pass to `jenv add`. Scan progress (with `-v`) goes to stderr so stdout stays pipeable.

```
jjenv list-all [-v|--verbose] [--no-defaults] [--unregistered] [--path <dir>]...
```

| Flag             | Description |
| ---------------- | ----------- |
| `-v`, `--verbose`| Log scan progress to stderr. |
| `--no-defaults`  | Skip built-in platform and SDKMAN scans. |
| `--unregistered` | Print only JDKs not already in `jenv`. |
| `--path <dir>`   | Add an extra search root (repeatable). |

Uses the same discovery rules and environment variables (`JJENV_JDK_PATHS`, `JJENV_NO_DEFAULTS`, `JENV_ROOT`) as `add-all`.

Examples:

```bash
# Pipe new JDKs straight into jenv:
jjenv list-all --unregistered | xargs -L1 jenv add

# Snapshot every JDK on the box:
jjenv list-all > jdks.txt
```

### `jjenv add-all`

Searches well-known JDK locations for the current platform and runs `jenv add <path>` for each JDK that is not already registered.

```
jjenv add-all [-n|--dry-run] [-v|--verbose] [--no-defaults] [--path <dir>]...
```

Options:

| Flag              | Description |
| ----------------- | ----------- |
| `-n`, `--dry-run` | Print what would be added without calling `jenv add`. |
| `-v`, `--verbose` | Print each path that is scanned. |
| `--no-defaults`   | Skip the built-in platform and SDKMAN search paths. Only scan roots given via `--path` / `JJENV_JDK_PATHS`. |
| `--path <dir>`    | Add an extra search root (repeatable). |

Environment:

| Variable            | Description |
| ------------------- | ----------- |
| `JJENV_JDK_PATHS`   | Colon-separated list of extra search roots. |
| `JJENV_NO_DEFAULTS` | If non-empty, equivalent to `--no-defaults`. |
| `JENV_ROOT`         | jenv state directory (default `~/.jenv`). Honored when computing the already-registered set. |
| `JJENV_DEBUG`       | Set to any value to enable shell trace for debugging. |

Default search locations:

- **macOS**: `/Library/Java/JavaVirtualMachines/*/Contents/Home`, the per-user equivalent, Homebrew `openjdk*` formulas, and everything `/usr/libexec/java_home -V` reports.
- **Linux**: `/usr/lib/jvm/*`, `/usr/lib64/jvm/*`, `/opt/{java,jdk,jdks}/*`.
- **All platforms**: SDKMAN (`$SDKMAN_DIR/candidates/java/*`).

Example:

```
$ jjenv add-all --dry-run -v
  platform: macos
  scan: /Library/Java/JavaVirtualMachines/*/Contents/Home
  scan: /opt/homebrew/opt/openjdk*/libexec/openjdk.jdk/Contents/Home
  ...
already added: /Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home
would add: /opt/homebrew/Cellar/openjdk/26.0.1/libexec/openjdk.jdk/Contents/Home

summary: 1 would be added, 1 already registered
```

Dedup is by resolved (symlink-followed) path, so the same JDK reached via multiple symlinks counts once and matches existing `~/.jenv/versions/*` entries correctly.

## Project layout

```
bin/jjenv             # entry point
libexec/jjenv         # router
libexec/jjenv-<cmd>   # one file per subcommand
completions/          # bash + zsh completion
```

Adding a new command = drop an executable `libexec/jjenv-<name>` script that follows the magic-comment header convention (`# Summary:`, `# Usage:`, `# Help:`). It is picked up automatically by `jjenv commands`, `jjenv help`, and the completion scripts.

## Development

Test suite is bats. From the repo root:

```bash
./run-tests.sh                    # local, requires bats on PATH (brew install bats-core)
./run-tests.sh test/list-all.bats # one file
./run-tests.sh --docker           # run inside Alpine for Linux/CI parity
```

The container ships modern bash, so it catches Linux-portability bugs but not bash 3.2 incompatibilities — run the local mode on macOS for those.

## License

[MIT](LICENSE) © 2026 Jin Kwon
