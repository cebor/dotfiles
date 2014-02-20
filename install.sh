#!/bin/bash

# homebrew
ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"

# zsh
brew install zsh
BREWZSH="/usr/local/bin/zsh"
if ! grep -Fxq "$BREWZSH" /etc/shells
then
  echo "$BREWZSH" | sudo tee -a  /etc/shells
fi
chsh -s "$BREWZSH"
unset BREWZSH

# oh-my-zsh
if [ ! -d ~/.oh-my-zsh ]; then
  git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
fi

# git
echo "Configurating GIT ...."
echo "Username: \c"
read GITUSER
echo "Email: \c"
read GITEMAIL
git config --global user.name "$GITUSER"
git config --global user.email "$GITEMAIL"
git config --global credential.helper osxkeychain
unset GITUSER
unset GITEMAIL

# source
source ~/.zshrc
