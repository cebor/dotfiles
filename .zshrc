# Load config files
for file in ~/.{exports,aliases,functions}; do
    [ -r "$file" ] && source "$file"
done
unset file

# nvm
source $(brew --prefix nvm)/nvm.sh

# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
ZSH_THEME="robbyrussell"

# Plugins 
plugins=(git brew extract virtualenv virtualenvwrapper node npm bower osx)

source $ZSH/oh-my-zsh.sh

# Virtualenv Pompt
PROMPT="\$(virtualenv_prompt_info)$PROMPT"

# # Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi
