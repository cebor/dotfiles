source /usr/local/share/antigen/antigen.zsh

antigen use oh-my-zsh

antigen bundle git
antigen bundle brew
antigen bundle extract
antigen bundle virtualenv
antigen bundle virtualenvwrapper
antigen bundle rvm
antigen bundle rupa/z

antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-syntax-highlighting

antigen theme robbyrussell

antigen apply
