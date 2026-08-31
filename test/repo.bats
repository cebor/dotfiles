#!/usr/bin/env bats
#
# Conventions from CLAUDE.md that are properties of the repo rather than of any
# one function — the kind of thing that gets "cleaned up" by someone who has not
# read the comment explaining why it is that way.

load helper

setup() {
  setup_sandbox
  REPO="$DOTFILES_ROOT"
}

teardown() { teardown_sandbox; }

@test "home/.config/git/ignore keeps its two literal carriage returns" {
  # macOS names folder-icon files Icon\r, and .editorconfig and .gitattributes
  # both carve out an exception for this line. Stripping the CRs makes the
  # pattern silently stop matching.
  local content
  content="$(cat "$REPO/home/.config/git/ignore")"
  [[ "$content" == *$'Icon\r\r'* ]]
}

@test "the shell files sourced on every prompt stay self-contained" {
  # home/.aliases and home/.functions run on every interactive shell start, so
  # they must not source lib/*.sh or otherwise pull the repo into the startup path
  local f
  for f in "$REPO"/home/.aliases "$REPO"/home/.functions; do
    ! grep -qE '^[[:space:]]*(source|\.)[[:space:]]+' "$f"
    ! grep -q 'DOTFILES_ROOT' "$f"
  done
}

@test "each setup file defines exactly one public function" {
  local f public
  for f in "$REPO"/setup/*.sh; do
    public="$(grep -oE '^[a-z][a-z_]*\(\)' "$f" | wc -l)"
    [ "$public" -eq 1 ] || {
      echo "$f defines $public public functions, expected 1"
      return 1
    }
    # and it is named after the step
    grep -qE '^setup_[a-z_]*\(\)' "$f"
  done
}

@test "nothing under lib/ or setup/ runs at source time" {
  local f
  for f in "$REPO"/lib/*.sh "$REPO"/setup/*.sh; do
    run bash -c "
      DOTFILES_ROOT='$REPO'
      source '$REPO/lib/os.sh'
      source '$REPO/lib/log.sh'
      source '$f'
    "
    [ "$status" -eq 0 ] || { echo "sourcing $f failed: $output"; return 1; }
    # lib/os.sh is the one exception and it only assigns \$OS
    case "$f" in
      */os.sh|*/log.sh) ;;
      *) [ -z "$output" ] || { echo "$f produced output at source time: $output"; return 1; } ;;
    esac
  done
}

@test "no script turns on set -e" {
  # deliberate: a step may soft-fail with a warning and let the run continue,
  # which is why every mutating command is checked by hand instead. Anchored, so
  # the comments explaining the choice do not count as violations of it.
  ! grep -rnE '^[[:space:]]*set -[eu]' \
    "$REPO/dot" "$REPO/bootstrap.sh" "$REPO/lib" "$REPO/setup"
}

@test "dot and bootstrap.sh are the only executables" {
  run bash -c "cd '$REPO' && git ls-files -s | awk '\$1 == \"100755\" { print \$4 }' | sort"
  [ "$output" = "bootstrap.sh
dot" ]
}

@test "bootstrap.sh sources nothing from the repo" {
  # it is fetched by curl and runs before the repo exists, so its output helpers
  # are deliberate duplicates of lib/log.sh and must stay self-contained
  ! grep -qE '^[[:space:]]*(source|\.)[[:space:]]+' "$REPO/bootstrap.sh"
}

@test "every file under home/ is a real file, not a symlink" {
  # link_files only picks up -type f, so a committed symlink would silently
  # never be linked into \$HOME
  run find "$REPO/home" -type l
  [ -z "$output" ]
}

@test "home/.zshrc sets up Homebrew's PATH before it sources anything" {
  local zshrc brew exports antidote
  zshrc="$REPO/home/.zshrc"
  brew="$(grep -n 'brew shellenv' "$zshrc" | head -n 1 | cut -d: -f1)"
  exports="$(grep -n 'exports,aliases,functions' "$zshrc" | head -n 1 | cut -d: -f1)"
  antidote="$(grep -n 'HOMEBREW_PREFIX' "$zshrc" | head -n 1 | cut -d: -f1)"

  [ -n "$brew" ] && [ -n "$exports" ] && [ -n "$antidote" ]
  [ "$brew" -lt "$exports" ] || {
    echo "brew shellenv (line $brew) must come before the sourcing loop (line $exports)"
    return 1
  }
  [ "$brew" -lt "$antidote" ] || {
    echo "brew shellenv (line $brew) must come before the antidote block (line $antidote)"
    return 1
  }
}
