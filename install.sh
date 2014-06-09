#!/bin/bash
cd "$(dirname "$0")"

# sync files
./sync.sh
cp .gitconfig ~

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
  echo "Changing shell to ZSH."
  chsh -s "$BREWZSH"
fi
unset BREWZSH

# oh-my-zsh
if [ ! -d ~/.oh-my-zsh ]; then
  echo "Installing oh-my-zsh."
  git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
fi

# gnu coreutils
if test ! $(brew --prefix coreutils)
then
  echo "Installing coreutils."
  brew install coreutils
fi

# python
if test ! $(brew --prefix python)
then
  echo "Installing python."
  brew install python
fi

# nvm
if [ ! -d ~/.nvm ]; then
  echo "Installing nvm."
  curl https://raw.githubusercontent.com/creationix/nvm/v0.7.0/install.sh | sh
fi

# git
echo "Configurating GIT ...."
read -p "Username: "
git config --global user.name "$REPLY"
read -p "Email: "
git config --global user.email "$REPLY"
git config --global credential.helper osxkeychain

echo "Installation & configuration finished!"

# source .zshrc
./source.zsh
