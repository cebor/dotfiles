#!/usr/bin/env bash

# setup vim directories
mkdir -p \
  "$HOME"/.vim/backups \
  "$HOME"/.vim/swaps \
  "$HOME"/.vim/undo

# install vim-plug if not present
if [ ! -f "$HOME"/.vim/autoload/plug.vim ]; then
  echo "Installing vim-plug..."
  curl -fLo "$HOME"/.vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
else
  echo "vim-plug already installed, updating plugins..."
fi

# install/update vim plugins
vim +PlugInstall +PlugUpdate +qall
