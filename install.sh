#!/bin/bash
cd "$(dirname "$0")"

# sync files
./sync.sh
cp .gitconfig ~/

# homebrew
if test ! $(which brew)
then
  echo "Installing Homebrew."
  ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
fi

# zsh
BREWZSH="/usr/local/bin/zsh"
if ! grep -Fxq "$BREWZSH" /etc/shells
then
  echo "Installing ZSH."
  brew install zsh
  echo "$BREWZSH" | sudo tee -a  /etc/shells
  chsh -s "$BREWZSH"
fi
unset BREWZSH

# nvm
if test ! $(brew --prefix nvm)
then
  echo "Installing nvm."
  brew install nvm
fi

# oh-my-zsh
if [ ! -d ~/.oh-my-zsh ]; then
  echo "Installing oh-my-zsh."
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

echo "Installation & configuration finished!"

# source
/usr/bin/env zsh
. ~/.zshrc
