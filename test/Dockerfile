# Linux + bats sandbox for the jjenv test suite.
#
# Built by ./run-tests.sh --docker (build context = repo root).
#
# Caveat: this image ships modern bash (5.x). It catches Linux-portability
# regressions, but NOT bash 3.2 incompatibilities — those are only caught by
# running ./run-tests.sh locally on the macOS system bash.

FROM alpine:3.20

RUN apk add --no-cache bash bats coreutils findutils grep sed

WORKDIR /jjenv
COPY . /jjenv

CMD ["bats", "test"]
