#!/usr/bin/env bash

# setup vim
mkdir -p \
  "$HOME"/.vim/backups \
  "$HOME"/.vim/swaps \
  "$HOME"/.vim/undo
curl -fLo "$HOME"/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
vim +PlugInstall +qall
