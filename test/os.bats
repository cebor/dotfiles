#!/usr/bin/env bats
#
# lib/os.sh — platform detection and the predicates the rest of the repo is
# written in. The two deliberate choices worth pinning are `current_user` using
# `id -un` rather than $USER, and $DOTFILES_OS overriding detection (that is what
# `./dot install --linux` rides on).

load helper

setup() {
  setup_sandbox
  load_dotfiles
}

teardown() { teardown_sandbox; }

@test "detect_os honors \$DOTFILES_OS" {
  DOTFILES_OS=macos detect_os
  [ "$OS" = "macos" ]
  is_macos
  ! is_linux

  DOTFILES_OS=linux detect_os
  [ "$OS" = "linux" ]
  is_linux
  ! is_macos
}

@test "detect_os maps uname -s when nothing overrides it" {
  DOTFILES_OS=""

  stub_script uname 'echo Darwin'
  detect_os
  [ "$OS" = "macos" ]

  stub_script uname 'echo Linux'
  detect_os
  [ "$OS" = "linux" ]

  stub_script uname 'echo SunOS'
  detect_os
  [ "$OS" = "unknown" ]
}

@test "arch_name maps uname -m onto the upstream asset names" {
  stub_script uname 'echo x86_64'
  [ "$(arch_name)" = "amd64" ]

  stub_script uname 'echo amd64'
  [ "$(arch_name)" = "amd64" ]

  stub_script uname 'echo aarch64'
  [ "$(arch_name)" = "arm64" ]

  stub_script uname 'echo arm64'
  [ "$(arch_name)" = "arm64" ]

  # anything else is passed through rather than guessed at
  stub_script uname 'echo riscv64'
  [ "$(arch_name)" = "riscv64" ]
}

@test "has reports whether a command exists" {
  has bash
  ! has definitely-not-a-real-command-xyz
}

@test "current_user works with \$USER unset" {
  # the regression this function exists for: su, sudo -i, cron and containers
  # leave \$USER empty, and an empty name is what turns chsh into a failed run
  bats_run env -u USER bash -c "source '$DOTFILES_ROOT/lib/os.sh'; current_user"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ "$output" = "$(id -un)" ]
}

@test "login_shell_path reads the passwd entry, not \$SHELL" {
  # \$SHELL keeps the pre-chsh value until the next login, so using it would make
  # every re-run of setup_shell ask for a sudo password again
  stub_script getent 'echo "someone:x:1000:1000::/home/someone:/bin/zsh"'
  SHELL=/bin/bash
  [ "$(login_shell_path)" = "/bin/zsh" ]
}

@test "the wsl and ubuntu predicates answer without erroring" {
  # both read hardcoded system paths, so only their contract is testable here:
  # a clean true/false, never a stray message or a non-boolean status
  local out
  out="$( { is_wsl; is_ubuntu; } 2>&1 || true )"
  [ -z "$out" ]

  if is_wsl; then true; else true; fi
  if is_ubuntu; then true; else true; fi
}
