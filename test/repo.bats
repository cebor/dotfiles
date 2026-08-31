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
  # home/.exports, home/.aliases and home/.functions all run on every interactive
  # shell start — one loop in .zshrc sources all three — so none of them may
  # source lib/*.sh or otherwise pull the repo into the startup path.
  #
  # Anchored at column 0, because the rule is about sourcing at *file* scope:
  # svenv sources a venv's activate script from inside a function body, which
  # costs a shell start nothing.
  #
  # Asserted with `if grep`, not `! grep`: set -e is documented not to fire on a
  # command whose status is inverted, so `! grep -q …` can only ever fail the
  # test when it happens to be its last statement — everywhere else it is a
  # no-op that reads like an assertion.
  local f
  for f in "$REPO"/home/.exports "$REPO"/home/.aliases "$REPO"/home/.functions; do
    if grep -nE '^(source|\.)[[:space:]]' "$f"; then
      echo "$f sources something at file scope"
      return 1
    fi
    if grep -n 'DOTFILES_ROOT' "$f"; then
      echo "$f reaches into the repo"
      return 1
    fi
  done
}

@test "home/.zshrc defines has_brew before antidote loads the plugins" {
  # .zsh_plugins.txt gates the omz brew bundle on `conditional:has_brew`, and
  # antidote resolves that when it loads — a definition after `antidote load`
  # would never be seen, and the bundle would silently not load anywhere.
  local zshrc def load
  zshrc="$REPO/home/.zshrc"
  grep -q 'conditional:has_brew' "$REPO/home/.zsh_plugins.txt"
  def="$(grep -n '^has_brew()' "$zshrc" | head -n 1 | cut -d: -f1)"
  load="$(grep -n 'antidote load' "$zshrc" | head -n 1 | cut -d: -f1)"

  [ -n "$def" ] && [ -n "$load" ]
  [ "$def" -lt "$load" ] || {
    echo "has_brew (line $def) must be defined before antidote load (line $load)"
    return 1
  }
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
