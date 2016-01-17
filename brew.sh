#!/usr/bin/env bash
cd "$(dirname "$0")"

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

# install homebrew
if [ ! -x "$(which brew)" ]; then
  echo "Installing Homebrew."
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

brew prune
brew doctor
brew update
brew upgrade

# install brews
for brew in {coreutils,findutils,zsh,openssl,openssh,wget,curl,rsync,git,python,node,vim}; do
  brew_install "$brew"
done

brew cask doctor

# install brew casks
for cask in {google-chrome,iterm2,atom,visual-studio-code}; do
  cask_install "$cask"
done

unset brew
unset brew_install
unset cask
unset cask_install

brew cleanup
