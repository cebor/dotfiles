# oh-my-zsh path
export ZSH=$HOME/.oh-my-zsh

# Load config files
for file in ~/.{exports,aliases,functions}; do
    [ -r "$file" ] && source "$file"
done
unset file

# z
source ~/.plugins/z/z.sh

# Set name of the theme to load.
ZSH_THEME="robbyrussell"

# Plugins
plugins=(git brew extract virtualenv virtualenvwrapper)

source $ZSH/oh-my-zsh.sh

# Virtualenv Pompt
ZSH_THEME_VIRTUALENV_PREFIX="%{$fg_bold[yellow]%}["
ZSH_THEME_VIRTUALENV_SUFFIX="]%{$reset_color%}%b "
PROMPT="\$(virtualenv_prompt_info)$PROMPT"

# locales
LC_ALL=en_US.UTF-8
LC_CTYPE=en_US.UTF-8
LANG=en_US.UTF-8
