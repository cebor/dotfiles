for file in ~/.dotfiles/{exports,aliases,functions,completions}; do
    [ -r "$file" ] && source "$file"
done
unset file

source /usr/local/share/antigen/antigen.zsh

antigen use oh-my-zsh

antigen bundle git
antigen bundle brew
antigen bundle extract
antigen bundle virtualenv
antigen bundle virtualenvwrapper
antigen bundle rupa/z

antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-syntax-highlighting

antigen theme robbyrussell

antigen apply

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
