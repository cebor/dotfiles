#!/usr/bin/env bats
#
# setup/locale.sh — the parsing half. setup_locale itself edits /etc/locale.gen
# and needs root, so what is testable is the part that decides *which* locale is
# wanted and whether it is there.
#
# The rule from CLAUDE.md: home/.exports is the single source of truth for LANG,
# so this must read the file, never $LANG from the environment — the process
# running ./dot need never have sourced it.

load helper

setup() {
  setup_sandbox
  load_dotfiles
  # shellcheck source=../setup/locale.sh
  source "$DOTFILES_ROOT/setup/locale.sh"
  REPO_ROOT="$DOTFILES_ROOT"
}

teardown() { teardown_sandbox; }

# Point _locale_wanted at a throwaway home/.exports with the given content.
exports_fixture() {
  DOTFILES_ROOT="$SANDBOX/fix"
  mkdir -p "$DOTFILES_ROOT/home"
  printf '%s\n' "$1" > "$DOTFILES_ROOT/home/.exports"
}

@test "_locale_normalize makes the two spellings comparable" {
  # locale -a prints glibc's normalized charset, LANG carries the canonical one
  [ "$(_locale_normalize en_US.UTF-8)" = "$(_locale_normalize en_US.utf8)" ]
  [ "$(_locale_normalize en_US.UTF-8)" = "en_us.utf8" ]
}

@test "_locale_available compares normalized, not literally" {
  stub_script locale 'printf "C\nen_US.utf8\nPOSIX\n"'

  # the whole point: LANG says en_US.UTF-8, locale -a says en_US.utf8
  _locale_available "en_US.UTF-8"
  ! _locale_available "de_DE.UTF-8"
}

@test "_locale_wanted reads LANG out of home/.exports" {
  exports_fixture 'export LANG=en_US.UTF-8'
  [ "$(_locale_wanted)" = "en_US.UTF-8" ]
}

@test "_locale_wanted handles both quoting styles and trailing comments" {
  exports_fixture 'export LANG="de_DE.UTF-8"'
  [ "$(_locale_wanted)" = "de_DE.UTF-8" ]

  exports_fixture "export LANG='fr_FR.UTF-8'"
  [ "$(_locale_wanted)" = "fr_FR.UTF-8" ]

  exports_fixture '  export   LANG=en_GB.UTF-8   # the one we want'
  [ "$(_locale_wanted)" = "en_GB.UTF-8" ]
}

@test "_locale_wanted takes the last assignment, the way a shell would" {
  exports_fixture 'export LANG=C.UTF-8
export EDITOR=hx
export LANG=en_US.UTF-8'
  [ "$(_locale_wanted)" = "en_US.UTF-8" ]
}

@test "_locale_wanted ignores a commented-out assignment" {
  exports_fixture '#export LANG=de_DE.UTF-8
export LANG=en_US.UTF-8'
  [ "$(_locale_wanted)" = "en_US.UTF-8" ]
}

@test "_locale_wanted is empty when nothing sets LANG" {
  exports_fixture 'export EDITOR=hx'
  [ -z "$(_locale_wanted)" ]

  DOTFILES_ROOT="$SANDBOX/does-not-exist"
  [ -z "$(_locale_wanted)" ]
}

@test "the repo's own home/.exports still parses" {
  # the regression guard: LANG is edited by hand, and a shape the sed cannot
  # read would silently turn ./dot configure locale into a no-op
  DOTFILES_ROOT="$REPO_ROOT"
  [ "$(_locale_wanted)" = "en_US.UTF-8" ]
}

@test "_locale_wanted does not read \$LANG from the environment" {
  exports_fixture 'export LANG=en_US.UTF-8'
  LANG=de_DE.UTF-8
  export LANG
  [ "$(_locale_wanted)" = "en_US.UTF-8" ]
}
