#!/usr/bin/env bash
#
# What the test suite needs on a bare Ubuntu image, and the unprivileged
# user it runs as. Deliberately not executable and never sourced: both
# test/Dockerfile and .gitlab-ci.yml call it as `bash test/ci-deps.sh`, so the
# package list has exactly one home.
#
# Run as root. Nothing here is part of ./dot — it only provisions the runner.

set -e

# bats runs the suite; shellcheck is the lint stage; util-linux gives script(1),
# which the pty tests in log.bats need. The rest is what `dot` itself calls out
# to while the CLI tests drive it.
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  bats \
  shellcheck \
  bash \
  git \
  curl \
  ca-certificates \
  sudo \
  util-linux \
  findutils \
  coreutils

# Several failure paths in lib/link.sh are only reachable as an unprivileged
# user: they are forced by making a directory unwritable, and root ignores that.
# Running the suite as root would skip them and report green for the wrong reason.
if ! id runner >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash runner
fi
