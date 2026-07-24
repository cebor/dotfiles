for file in ~/.{exports,aliases,functions}; do
    [ -e "$file" ] && source "$file"
done
unset file

# Homebrew (macOS): sets up PATH and provides `brew --prefix`
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# user-local binaries (starship etc. on Linux)
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"

# antidote: brew keg on macOS, ~/.antidote clone on Linux
if command -v brew &>/dev/null && [ -e "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh" ]; then
  source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
elif [ -e "$HOME/.antidote/antidote.zsh" ]; then
  source "$HOME/.antidote/antidote.zsh"
fi
antidote load

command -v starship &>/dev/null && eval "$(starship init zsh)"
