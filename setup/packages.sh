#!/usr/bin/env bash

# Package installation, dispatched by platform:
#   macOS -> packages/Brewfile via `brew bundle`
#   Linux -> setup/packages-linux.sh (apt sources, then packages/apt.txt)

setup_packages() {
  section "Installing packages"

  # collected explicitly: a bare sequence would return the last `… || warn`, which
  # is always 0, so a failed `brew bundle` would never reach the exit code.
  local rc=0

  if is_macos; then
    # `./dot packages` on its own never ran setup/prereqs.sh, so brew may be
    # installed without being on this process's PATH — same as in cmd_install
    brew_shellenv
    # On a fresh Mac under --dry-run, the prereqs step only said it *would*
    # install Homebrew, so its absence here is an artefact of the forecast. Same
    # guard as in setup/vim.sh and setup/shell.sh.
    if ! has brew; then
      if [ -z "$DRY_RUN" ]; then
        err "Homebrew missing — run ./dot install"
        return 1
      fi
      info "Homebrew not installed yet — ./dot install installs it before this step"
      ok "would install the Brewfile packages once Homebrew is there"
      return 0
    fi
    run brew update  || warn "brew update failed"
    run brew upgrade || warn "brew upgrade failed"
    # An entry that did not install is a real gap, not a cosmetic one: unlike
    # packages/apt.txt, the Brewfile lists nothing that is expected to be
    # unavailable. Same severity as the upstream installers on Linux.
    if run brew bundle --file="$DOTFILES_ROOT/packages/Brewfile"; then
      ok_run "Homebrew packages up to date" "would install the Brewfile packages"
    else
      err "brew bundle reported failures — see above"
      rc=1
    fi
    run brew cleanup || warn "brew cleanup failed"
  elif is_linux; then
    # shellcheck source=setup/packages-linux.sh
    source "$DOTFILES_ROOT/setup/packages-linux.sh"
    setup_packages_linux || rc=1
  else
    warn "unknown platform — skipping packages"
  fi

  return "$rc"
}
