for file in ~/.{exports,aliases,functions}; do
    test -e "$file" && source "$file"
done
unset file

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
antidote load

eval "$(starship init zsh)"
