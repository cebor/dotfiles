for file in ~/.{exports,aliases,functions}; do
    test -e "$file" && source "$file"
done
unset file

source "$(brew --prefix)/share/antigen/antigen.zsh"

antigen use oh-my-zsh

# oh-my-zsh plugins
antigen bundle git
antigen bundle brew
antigen bundle extract

# extra plugins
antigen bundle rupa/z
#antigen bundle unixorn/autoupdate-antigen.zshplugin

# should be loaded last
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-syntax-highlighting

#antigen theme robbyrussell
#antigen theme spaceship-prompt/spaceship-prompt

antigen apply

eval "$(starship init zsh)"
