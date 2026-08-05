#!/usr/bin/env bash

# System prerequisites — what has to be in place before `packages` can run:
#   macOS -> Xcode Command Line Tools + Homebrew
#   Linux -> the apt packages the third-party sources in packages-linux.sh need
#
# Deliberately no apt sources here: this step installs the tools the source step
# needs (curl, gnupg, add-apt-repository), the source step uses them. A repo
# added without the apt.txt batch behind it would also leave a machine with a
# source and none of its packages.
#
# Not to be confused with the root bootstrap.sh, which is curl-fetched on a bare
# machine and only installs git and clones this repo.
#
# Sourced by `dot`; defines setup_prereqs and runs nothing on its own.

setup_prereqs() {
  section "Installing prerequisites"

  if is_macos; then
    _prereqs_macos
  elif is_linux; then
    _prereqs_linux
  else
    warn "unknown platform — skipping prerequisites"
  fi
}

_prereqs_macos() {
  if xcode-select -p &>/dev/null; then
    skip "Xcode Command Line Tools already installed"
  elif [ -n "$DRY_RUN" ]; then
    # nothing was started, so there is nothing to wait for — failing here would
    # abort the whole dry run (cmd_install turns it into `die`) and never show
    # what sync/packages/configure would do
    run xcode-select --install
    info "would wait for the Xcode installer, then continue"
  else
    info "Installing Xcode Command Line Tools..."
    # the status matters: told to "finish the installer" after a `--install` that
    # never opened one (already running, no network, MDM policy) the user would be
    # waiting on a window that is not coming
    if run xcode-select --install; then
      err "Finish the Xcode installer, then re-run ./dot install"
    else
      err "could not start the Xcode installer — run xcode-select --install by hand, then re-run ./dot install"
    fi
    return 1
  fi

  if has brew; then
    skip "Homebrew already installed"
  else
    info "Installing Homebrew..."
    # NONINTERACTIVE under --yes because the installer waits for RETURN.
    local nonint=""
    [ -n "$ASSUME_YES" ] && nonint="NONINTERACTIVE=1 "
    # Via a temp file, not `/bin/bash -c "$(curl …)"`: a failed fetch makes the
    # command substitution empty and `bash -c ""` exits 0. pipefail cannot catch
    # that — this is a substitution, not a pipeline — so fetch and run are
    # separated and an empty body is caught by -s. Same shape as the yq/kubectl
    # installs in packages-linux.sh. The download stays inside `run bash -c '…'`:
    # as an argument it would be fetched even under --dry-run.
    if run bash -c "tmp=\$(mktemp) &&
        curl -fsSL -o \"\$tmp\" https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh &&
        [ -s \"\$tmp\" ] &&
        ${nonint}/bin/bash \"\$tmp\"
      rc=\$?; rm -f \"\$tmp\"; exit \$rc"; then
      ok_run "Homebrew installed" "would install Homebrew"
    else
      err "Homebrew installation failed"
      return 1
    fi
  fi

  brew_shellenv
  # brew_shellenv is a no-op when brew sits under neither probed prefix, and an
  # `if` without a matching branch returns 0 — as the last statement it would put
  # this step's ✓ on an installation nothing can find. Not under --dry-run, where
  # nothing was installed (same guard as in setup/packages.sh).
  if ! has brew && [ -z "$DRY_RUN" ]; then
    err "Homebrew installed but not on PATH — see the installer's \"Next steps\" output"
    return 1
  fi
  return 0
}

# The apt sources in setup/packages-linux.sh need curl, gpg and — on Ubuntu —
# add-apt-repository before any third-party repo exists, so these cannot come out
# of the apt.txt batch that runs after them. git is here for a different reason:
# packages-linux.sh clones antidote with it, and that must not depend on the
# apt.txt batch having gone through either. They are all listed in apt.txt too:
# installing them twice costs nothing, and that list stays the full picture of
# what a machine gets. On Ubuntu the batch then upgrades git to the PPA version.
_prereqs_linux() {
  local prereqs="git curl ca-certificates gnupg"
  is_ubuntu && prereqs="$prereqs software-properties-common"

  info "apt prerequisites"
  run sudo apt-get update || warn "apt-get update failed — package versions may be stale"
  # shellcheck disable=SC2086 # deliberate word splitting: one arg per package
  if run sudo apt-get install -y $prereqs; then
    ok_run "apt prerequisites installed" "would install the apt prerequisites ($prereqs)"
  else
    warn "could not install the prerequisites ($prereqs) — ./dot packages may not be able to add its apt sources"
  fi

  # curl is what separates a degraded run from no run at all: every apt source
  # and every upstream installer downloads with it. packages-linux.sh checks the
  # same thing again, because it can be reached without ever coming through here.
  if ! has curl && [ -z "$DRY_RUN" ]; then
    err "curl is missing — ./dot packages cannot add the apt sources"
    return 1
  fi
  return 0
}
