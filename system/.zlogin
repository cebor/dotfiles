# rvm
test -e "$HOME/.rvm/scripts/rvm" && source "$HOME/.rvm/scripts/rvm"

# Virtualenv Pompt
export ZSH_THEME_VIRTUALENV_PREFIX="%{$fg_bold[yellow]%}["
export ZSH_THEME_VIRTUALENV_SUFFIX="]%{$reset_color%}%b "
export PROMPT="\$(virtualenv_prompt_info)$PROMPT"
