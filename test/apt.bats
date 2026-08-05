#!/usr/bin/env bats
#
# setup/packages-linux.sh — the apt.txt parser. The _apt_repo_* steps run
# `curl | sudo bash` and are out of reach here; _apt_read_list is pure and is
# the only place Linux package names are decided.
#
# The design it has to keep: it fills the global $APT_PACKAGES rather than
# echoing. In a `pkgs="$(_apt_read_list)"` the warn below would land in $pkgs as
# if it were a package name, and its $LOG_WARNINGS increment would die with the
# subshell — both of which are asserted here.

load helper

setup() {
  setup_sandbox
  load_dotfiles
  # shellcheck source=../setup/packages-linux.sh
  source "$DOTFILES_ROOT/setup/packages-linux.sh"
  REPO_ROOT="$DOTFILES_ROOT"
}

teardown() { teardown_sandbox; }

# Point _apt_read_list at a throwaway packages/apt.txt.
apt_fixture() {
  DOTFILES_ROOT="$SANDBOX/fix"
  mkdir -p "$DOTFILES_ROOT/packages"
  printf '%s\n' "$1" > "$DOTFILES_ROOT/packages/apt.txt"
}

# The two predicates the tags dispatch on are plain functions, so a test just
# redefines them rather than faking /proc/version and /etc/os-release.
platform() {
  eval "is_wsl() { return $1; }"
  eval "is_ubuntu() { return $2; }"
}

FIXTURE='# a header comment

zsh
git         # inline comment
wslu        @wsl
xclip       @!wsl
helix       @ubuntu
   tmux
'

@test "_apt_read_list drops comments, blank lines and padding" {
  apt_fixture 'zsh

# a comment
git   # trailing comment
   tmux   '
  platform 1 1
  _apt_read_list
  [ "${APT_PACKAGES[*]}" = "zsh git tmux" ]
}

@test "@wsl and @!wsl select on the machine" {
  apt_fixture "$FIXTURE"

  platform 0 1          # WSL, not Ubuntu
  _apt_read_list
  [ "${APT_PACKAGES[*]}" = "zsh git wslu tmux" ]

  platform 1 1          # not WSL, not Ubuntu
  _apt_read_list
  [ "${APT_PACKAGES[*]}" = "zsh git xclip tmux" ]
}

@test "@ubuntu selects on the distribution" {
  apt_fixture "$FIXTURE"

  platform 1 0          # not WSL, Ubuntu
  _apt_read_list
  [ "${APT_PACKAGES[*]}" = "zsh git xclip helix tmux" ]

  platform 0 0          # WSL and Ubuntu
  _apt_read_list
  [ "${APT_PACKAGES[*]}" = "zsh git wslu helix tmux" ]
}

@test "an unknown tag warns and drops the line" {
  apt_fixture 'zsh
mystery   @nope
git'
  platform 1 1

  # capturing the output takes a subshell, so this call's array and counter are
  # lost with it — the exact reason _apt_read_list fills a global instead of
  # echoing, and why the assertions below need a second, direct call
  bats_run _apt_read_list
  [[ "$output" == *"unknown tag @nope on mystery"* ]]

  _apt_read_list

  # a typo'd tag is indistinguishable from a real one, and installing anyway
  # would be the wrong guess as often as not
  [ "${APT_PACKAGES[*]}" = "zsh git" ]

  # the two things the design exists for: the warning text is not mistaken for a
  # package name, and the counter increment survives
  [ "$LOG_WARNINGS" -eq 1 ]
  [[ "${APT_PACKAGES[*]}" != *"unknown tag"* ]]
  [[ "${APT_PACKAGES[*]}" != *"mystery"* ]]
}

@test "_apt_read_list starts from empty on every call" {
  apt_fixture 'zsh'
  platform 1 1
  _apt_read_list
  _apt_read_list
  [ "${#APT_PACKAGES[@]}" -eq 1 ]
}

@test "the repo's own apt.txt parses cleanly on every platform" {
  DOTFILES_ROOT="$REPO_ROOT"
  local wsl ubuntu
  for wsl in 0 1; do
    for ubuntu in 0 1; do
      platform "$wsl" "$ubuntu"
      reset_counters
      _apt_read_list
      [ "$LOG_WARNINGS" -eq 0 ]
      [ "${#APT_PACKAGES[@]}" -gt 0 ]
      local pkg
      for pkg in "${APT_PACKAGES[@]}"; do
        [[ "$pkg" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || {
          echo "not a plausible package name: $pkg"
          return 1
        }
      done
    done
  done
}

@test "the tagged packages in the repo's apt.txt land on the right machines" {
  DOTFILES_ROOT="$REPO_ROOT"

  platform 0 1          # WSL
  _apt_read_list
  [[ " ${APT_PACKAGES[*]} " == *" wslu "* ]]
  [[ " ${APT_PACKAGES[*]} " != *" xclip "* ]]

  platform 1 0          # bare Ubuntu
  _apt_read_list
  [[ " ${APT_PACKAGES[*]} " == *" xclip "* ]]
  [[ " ${APT_PACKAGES[*]} " == *" helix "* ]]
  [[ " ${APT_PACKAGES[*]} " != *" wslu "* ]]

  platform 1 1          # bare Debian — no helix package exists there
  _apt_read_list
  [[ " ${APT_PACKAGES[*]} " != *" helix "* ]]
}
