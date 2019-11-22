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

# install homebrew
if [ ! -x "$(which brew)" ]; then
  echo "Installing Homebrew."
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

brew doctor
brew update
brew upgrade

brew tap mongodb/brew

# install brews
for brew in {coreutils,findutils,zsh,wget,rsync,git,python,ipython,ctags,node,vim,antigen,yarn,httpie,gpg,wrk,tree,watch,nmap,mtr,kubernetes-cli,kubernetes-helm,mongodb-community}; do
  brew_install "$brew"
done

brew cask doctor

for cask in {google-chrome,iterm2,visual-studio-code,docker,github,vlc,spotify,skype,whatsapp,teamspeak-client,wireshark}; do
  cask_install "$cask"
done

brew cleanup
