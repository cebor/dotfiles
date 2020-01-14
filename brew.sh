#!/usr/bin/env bash

brew_install () {
  if [ ! -d "$(brew --prefix "$1")" ]; then
    echo "Installing $1."
    brew install "$1"
  fi
}

cask_install () {
  echo "Installing $1."
  brew cask install "$1"
}

if [ ! -x "$(which brew)" ]; then
  echo "Installing Homebrew."
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

brew update
brew upgrade

brew tap mongodb/brew

while read brew; do
  brew_install "$brew"
done <brews.txt

while read cask; do
  cask_install "$cask"
done <casks.txt

brew cleanup
