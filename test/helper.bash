# Shared setup for the bats suites. Sourced as `load helper` from every *.bats.
#
# The repo is testable as it stands (see CLAUDE.md): nothing under lib/ or setup/
# runs at source time, and the paths link.sh works on are plain globals. So a test
# only has to point $HOME and $XDG_STATE_HOME at a temp dir and source normally —
# no root, no network, and nothing in the real $HOME is ever touched.

# The repo root, from this file's location. Tests never cd into it.
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export DOTFILES_ROOT
DOT="$DOTFILES_ROOT/dot"

# Create the sandbox and point the environment at it. Call this *before*
# load_dotfiles: lib/link.sh reads $HOME and $XDG_STATE_HOME at source time.
setup_sandbox() {
  SANDBOX="$(mktemp -d "${BATS_TMPDIR:-/tmp}/dotfiles-test.XXXXXX")"
  export SANDBOX
  export HOME="$SANDBOX/home"
  export XDG_STATE_HOME="$SANDBOX/state"
  export TMPDIR="$SANDBOX/tmp"
  mkdir -p "$HOME" "$XDG_STATE_HOME" "$TMPDIR" "$SANDBOX/src" "$SANDBOX/bin"

  # $PATH prefix for stub_bin. Prepended unconditionally so a test that stubs
  # nothing still runs with the same PATH shape as one that does.
  export PATH="$SANDBOX/bin:$PATH"

  # the flags every test starts from; individual tests set them as needed
  DRY_RUN=""
  ASSUME_YES=""
}

teardown_sandbox() {
  [ -n "$SANDBOX" ] || return 0
  # a test may have chmod'ed a directory read-only to force a failure path
  chmod -R u+rwX "$SANDBOX" 2>/dev/null
  rm -rf "$SANDBOX"
}

# Source the libraries into the test process and reset the log counters.
# $LINK_SRC is repointed at the sandbox afterwards, so link tests get a home/
# tree they own; pass "real" to keep the repo's own home/ instead.
#
# lib/log.sh defines run() and skip(), which shadow the bats builtins of the same
# name for the rest of the process. Tests need both meanings — the repo's to
# exercise, bats' to drive the test — so the builtins are preserved as bats_run()
# and bats_skip() before the sourcing that shadows them. Every test that calls
# load_dotfiles must therefore use `bats_run`, never `run`.
load_dotfiles() {
  local fn
  for fn in run skip; do
    if declare -f "$fn" >/dev/null && ! declare -f "bats_$fn" >/dev/null; then
      eval "$(declare -f "$fn" | sed "1s/^$fn/bats_$fn/")"
    fi
  done
  # shellcheck source=../lib/os.sh
  source "$DOTFILES_ROOT/lib/os.sh"
  # shellcheck source=../lib/log.sh
  source "$DOTFILES_ROOT/lib/log.sh"
  # shellcheck source=../lib/link.sh
  source "$DOTFILES_ROOT/lib/link.sh"
  if [ "$1" != "real" ]; then
    LINK_SRC="$SANDBOX/src"
  fi
  reset_counters
}

reset_counters() {
  LOG_WARNINGS=0
  LOG_ERRORS=0
}

# Put a fake command on $PATH. It records the call in $SANDBOX/calls and exits
# with $2 (default 0), so a test can assert that a command ran — or, with a
# non-zero code and no expected call, that it never ran at all.
stub_bin() {
  local name="$1" code="${2:-0}"
  cat > "$SANDBOX/bin/$name" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "$name" "\$*" >> "$SANDBOX/calls"
exit $code
EOF
  chmod +x "$SANDBOX/bin/$name"
}

# Put a fake command on $PATH with an explicit body, for the stubs that have to
# answer with something rather than just succeed or fail (uname, getent, locale).
stub_script() {
  local name="$1" body="$2"
  { printf '#!/usr/bin/env bash\n'; printf '%s\n' "$body"; } > "$SANDBOX/bin/$name"
  chmod +x "$SANDBOX/bin/$name"
}

# Was a stub invoked? $1 is the command name.
stub_called() {
  [ -f "$SANDBOX/calls" ] && grep -q "^$1 " "$SANDBOX/calls"
}

# A reproducible picture of a directory tree: every path with its mode, and for
# symlinks their target, for files their checksum. This is what "a dry run writes
# nothing at all" is asserted against, so it has to notice a created file, a
# changed mode and a repointed link alike. `ls -ld` for the mode because stat(1)
# takes different flags on GNU and BSD.
snapshot_fs() {
  local root="$1" p mode
  [ -e "$root" ] || { printf '(absent)\n'; return 0; }
  find "$root" -mindepth 0 | sort | while IFS= read -r p; do
    mode="$(ls -ld "$p" | awk '{print $1}')"
    if [ -L "$p" ]; then printf '%s %s -> %s\n' "$mode" "$p" "$(readlink "$p")"
    elif [ -d "$p" ]; then printf '%s %s/\n' "$mode" "$p"
    else printf '%s %s %s\n' "$mode" "$p" "$(cksum < "$p")"
    fi
  done
}

# Several failure paths are reached by making a directory unwritable, which root
# ignores. Those tests are skipped rather than silently passing for the wrong
# reason — CI runs the suite as a non-root user precisely so they do run.
skip_if_root() {
  if [ "$(id -u)" -eq 0 ]; then
    if declare -f bats_skip >/dev/null; then
      bats_skip "needs a non-root user: root ignores file permissions"
    else
      skip "needs a non-root user: root ignores file permissions"
    fi
  fi
}

# Run a bash snippet with a real pty on stdin, fed with $1. Without this the
# `[ -t 0 ]` guards in confirm/ask short-circuit and the interactive branches —
# where the stdout/stderr split actually matters — are unreachable.
# with_tty itself discards both channels; the snippet is expected to redirect
# them where the test wants them (the callers in log.bats use $SANDBOX/out and
# $SANDBOX/err).
#
# util-linux script(1) only; BSD script takes its command differently. The
# snippet must contain no single quotes: it is passed through `bash -c '…'`.
with_tty() {
  local input="$1" snippet="$2"
  script --version 2>/dev/null | grep -q util-linux ||
    bats_skip "needs util-linux script(1) to allocate a pty"
  printf '%s' "$input" |
    script -qec "bash -c '$snippet'" /dev/null >/dev/null 2>&1
}

# Write a file, creating parents. Used to build home/ trees in the sandbox.
mkfile() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "${2-content of $1}" > "$1"
}

# A small but representative home/ tree in $SANDBOX/src: two top-level dotfiles,
# a nested config, and the .ssh file whose parent link_tree chmods to 700.
seed_src() {
  mkfile "$SANDBOX/src/.zshrc" "zshrc"
  mkfile "$SANDBOX/src/.aliases" "aliases"
  mkfile "$SANDBOX/src/.config/helix/config.toml" "helix"
  mkfile "$SANDBOX/src/.ssh/config" "ssh"
}
