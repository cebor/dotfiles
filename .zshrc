# Load config files
for file in ~/.{exports,aliases,functions}; do
    [ -r "$file" ] && source "$file"
done
unset file

# nvm
source ~/.nvm/nvm.sh

# Set name of the theme to load.
ZSH_THEME="robbyrussell"

# Plugins
plugins=(git brew extract virtualenv virtualenvwrapper npm)

source $ZSH/oh-my-zsh.sh

# Virtualenv Pompt
ZSH_THEME_VIRTUALENV_PREFIX="%B%{$fg[yellow]%}["
ZSH_THEME_VIRTUALENV_SUFFIX="]%{$reset_color%}%B"
PROMPT="\$(virtualenv_prompt_info) $PROMPT"
