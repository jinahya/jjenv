# jjenv

[English](README.md) · **한국어**

Java 버전 관리자 [jenv](https://github.com/jenv/jenv)를 위한 부가 명령어 모음.

`jjenv`는 `jenv`를 감싸서, jenv가 기본으로 제공하지 않는 작업들을 추가해 주는 독립 실행형 bash CLI입니다. jenv를 **대체하지 않으며**, `jenv`가 설치되어 있고 `PATH`에 등록되어 있어야 합니다.

## 상태

초기 단계. 현재 두 개의 명령어(`list-all`, `add-all`)가 구현되어 동작합니다. macOS에서 테스트되었고, Linux 탐색 경로는 코딩되어 있지만 아직 Linux에서 검증되지 않았습니다.

## 요구 사항

- `PATH`에 `jenv`가 있어야 함
- `bash` (3.2 이상이면 됨 — macOS 기본 bash에서 동작)

## 설치

### Homebrew (권장)

```bash
brew install jinahya/jjenv/jjenv
```

`jenv`는 의존성으로 자동 설치됩니다.

### 직접 설치

저장소를 클론한 뒤 `bin/`을 `PATH`에 추가합니다.

```bash
git clone https://github.com/jinahya/jjenv.git ~/.jjenv
export PATH="$HOME/.jjenv/bin:$PATH"
```

쉘 자동 완성 (선택):

```bash
# bash
source ~/.jjenv/completions/jjenv.bash

# zsh
fpath=(~/.jjenv/completions $fpath)
source ~/.jjenv/completions/jjenv.zsh
```

## 명령어

```
jjenv list-all    설치된 모든 JDK 경로를 출력 (jenv add에 그대로 사용 가능)
jjenv add-all     설치된 모든 JDK를 찾아서 jenv에 등록
jjenv commands    사용 가능한 jjenv 명령어 목록 출력
jjenv help        명령어별 도움말 표시
```

자세한 설명은 `jjenv help <command>`로 확인할 수 있습니다.

### `jjenv list-all`

탐색된 JDK Home 경로를 한 줄에 하나씩 stdout으로 출력합니다. 각 줄은 그대로 `jenv add`의 인자로 넘길 수 있는 형식입니다. `-v`로 출력되는 스캔 진행 로그는 stderr로 가므로, stdout은 그대로 파이프할 수 있습니다.

```
jjenv list-all [-v|--verbose] [--no-defaults] [--unregistered] [--path <dir>]...
```

| 플래그           | 설명 |
| ---------------- | ----------- |
| `-v`, `--verbose`| 스캔 진행 상황을 stderr로 출력. |
| `--no-defaults`  | 기본 플랫폼 및 SDKMAN 스캔을 건너뜀. |
| `--unregistered` | jenv에 아직 등록되지 않은 JDK만 출력. |
| `--path <dir>`   | 추가 탐색 경로 (반복 지정 가능). |

`add-all`과 동일한 탐색 규칙 및 환경 변수(`JJENV_JDK_PATHS`, `JJENV_NO_DEFAULTS`, `JENV_ROOT`)를 사용합니다.

예시:

```bash
# 미등록 JDK를 바로 jenv로 등록:
jjenv list-all --unregistered | xargs -L1 jenv add

# 머신의 모든 JDK 스냅샷:
jjenv list-all > jdks.txt
```

### `jjenv add-all`

현재 플랫폼의 잘 알려진 JDK 설치 위치들을 탐색하고, 아직 등록되지 않은 JDK 각각에 대해 `jenv add <path>`를 실행합니다.

```
jjenv add-all [-n|--dry-run] [-v|--verbose] [--no-defaults] [--path <dir>]...
```

옵션:

| 플래그            | 설명 |
| ----------------- | ----------- |
| `-n`, `--dry-run` | 실제로 `jenv add`를 호출하지 않고 등록될 항목만 출력. |
| `-v`, `--verbose` | 스캔하는 각 경로를 출력. |
| `--no-defaults`   | 기본 플랫폼 및 SDKMAN 탐색을 건너뜀. `--path` / `JJENV_JDK_PATHS`로 지정된 경로만 스캔. |
| `--path <dir>`    | 추가 탐색 경로 (반복 지정 가능). |

환경 변수:

| 변수                | 설명 |
| ------------------- | ----------- |
| `JJENV_JDK_PATHS`   | 콜론(`:`)으로 구분된 추가 탐색 경로 목록. |
| `JJENV_NO_DEFAULTS` | 비어 있지 않으면 `--no-defaults`와 동일하게 동작. |
| `JENV_ROOT`         | jenv 상태 디렉터리 (기본값 `~/.jenv`). 이미 등록된 JDK 집합을 계산할 때 사용. |
| `JJENV_DEBUG`       | 임의 값을 지정하면 디버깅용 셸 트레이스를 활성화. |

기본 탐색 위치:

- **macOS**: `/Library/Java/JavaVirtualMachines/*/Contents/Home`, 사용자 영역의 동일 경로, Homebrew `openjdk*` formula, `/usr/libexec/java_home -V`가 보고하는 모든 경로.
- **Linux**: `/usr/lib/jvm/*`, `/usr/lib64/jvm/*`, `/opt/{java,jdk,jdks}/*`.
- **모든 플랫폼**: SDKMAN (`$SDKMAN_DIR/candidates/java/*`).

예시:

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

중복 제거는 심볼릭 링크가 해석된(resolved) 경로 기준으로 이뤄지므로, 여러 심볼릭 링크를 통해 도달할 수 있는 동일 JDK는 한 번만 카운트되며 기존 `~/.jenv/versions/*` 항목과도 정확히 매칭됩니다.

## 프로젝트 구조

```
bin/jjenv             # 진입점
libexec/jjenv         # 라우터
libexec/jjenv-<cmd>   # 서브 명령어별 파일 하나
completions/          # bash + zsh 자동 완성
```

새 명령어 추가는 매직 코멘트 헤더 규약(`# Summary:`, `# Usage:`, `# Help:`)을 따르는 실행 가능한 `libexec/jjenv-<name>` 스크립트를 추가하는 것만으로 끝납니다. `jjenv commands`, `jjenv help`, 자동 완성 스크립트가 이를 자동으로 인식합니다.

## 라이선스

[MIT](LICENSE) © 2026 Jin Kwon
