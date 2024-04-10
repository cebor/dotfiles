for file in ~/.{exports,aliases,functions}; do
    test -e "$file" && source "$file"
done
unset file

source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
antidote load

eval "$(starship init zsh)"
