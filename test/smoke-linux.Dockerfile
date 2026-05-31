# Smoke-test image: real OpenJDK on Debian, used by test/smoke-linux.sh to
# verify jjenv's Linux discovery globs (/usr/lib/jvm/*) actually match a real
# distro layout.
#
# NOT used by ./run-tests.sh, which stays hermetic with fakes.

FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates openjdk-17-jdk-headless \
 && rm -rf /var/lib/apt/lists/*

# jjenv requires `jenv` on PATH. Install a stub that records invocations to
# /tmp/jenv.log instead of pulling real jenv (which would need its own setup).
RUN printf '%s\n' \
      '#!/usr/bin/env bash' \
      'echo "$@" >> /tmp/jenv.log' \
    > /usr/local/bin/jenv \
 && chmod +x /usr/local/bin/jenv

WORKDIR /jjenv
COPY . /jjenv

ENV PATH="/jjenv/bin:${PATH}"
