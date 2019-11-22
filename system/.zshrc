for file in ~/.{exports,aliases,functions}; do
    test -e "$file" && source "$file"
done
unset file


source /usr/local/share/antigen/antigen.zsh

antigen use oh-my-zsh

# oh-my-zsh plugins
antigen bundle git
antigen bundle brew
antigen bundle extract
antigen bundle virtualenv
antigen bundle virtualenvwrapper
antigen bundle rvm

# extra plugins
antigen bundle rupa/z
# antigen bundle unixorn/autoupdate-antigen.zshplugin

# should be loaded last
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-syntax-highlighting

antigen theme robbyrussell

antigen apply

# rvm
test -e "$HOME/.rvm/scripts/rvm" && source "$HOME/.rvm/scripts/rvm"

# venv prompt
export ZSH_THEME_VIRTUALENV_PREFIX="%{$fg_bold[yellow]%}["
export ZSH_THEME_VIRTUALENV_SUFFIX="]%{$reset_color%}%b "
export PROMPT="\$(virtualenv_prompt_info)$PROMPT"

