# Homebrew (macOS): sets up PATH and provides `brew --prefix`
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

for file in ~/.{exports,aliases,functions}; do
    [ -e "$file" ] && source "$file"
done
unset file

# antidote: brew keg on macOS, ~/.antidote clone on Linux.
# $HOMEBREW_PREFIX comes from the shellenv above — `brew --prefix` would fork a
# brew process on every single shell start.
if [ -n "$HOMEBREW_PREFIX" ] && [ -e "$HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh" ]; then
  source "$HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh"
elif [ -e "$HOME/.antidote/antidote.zsh" ]; then
  source "$HOME/.antidote/antidote.zsh"
fi

# used by `conditional:has_brew` on the omz brew plugin in .zsh_plugins.txt, so
# that bundle only loads where Homebrew exists (macOS)
has_brew() { command -v brew &>/dev/null; }

# guarded so a machine without antidote yet does not error on every shell start
if command -v antidote &>/dev/null; then
  antidote load
fi

command -v starship &>/dev/null && eval "$(starship init zsh)"
