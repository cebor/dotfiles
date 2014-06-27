#!/usr/bin/env bash
cd "$(dirname "$0")"

# sync files
./sync.sh
cp .gitconfig $HOME

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
  git clone https://github.com/robbyrussell/oh-my-zsh.git $HOME/.oh-my-zsh
fi

# gnu coreutils
if test ! $(brew --prefix coreutils)
then
  echo "Installing coreutils."
  brew install coreutils
fi

# gnu findutils
if test ! $(brew --prefix findutils)
then
  echo "Installing findutils."
  brew install findutils
fi

# python
if test ! $(brew --prefix python)
then
  echo "Installing python."
  brew install python
fi

# nvm
if [ ! -d $HOME/.nvm ]; then
  echo "Installing nvm."
  curl https://raw.githubusercontent.com/creationix/nvm/v0.7.0/install.sh | sh
fi

# vim
if test ! $(brew --prefix vim)
then
  echo "Installing vim."
  brew install vim

  # Add Theme
  [ ! -d $HOME/.vim/colors ] && mkdir -p $HOME/.vim/colors
  curl -s -o $HOME/.vim/colors/badwolf.vim https://raw.githubusercontent.com/sjl/badwolf/master/colors/badwolf.vim
  curl -s -o $HOME/.vim/colors/molokai.vim https://raw.githubusercontent.com/tomasr/molokai/master/colors/molokai.vim
fi

# git
echo "Configurating GIT ...."
read -p "Username: "
git config --global user.name "$REPLY"
read -p "Email: "
git config --global user.email "$REPLY"
git config --global credential.helper osxkeychain

echo "Installation & configuration finished! Please reload you shell!"
