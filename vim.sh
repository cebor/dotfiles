#!/usr/bin/env bash

# create dirs
mkdir -p \
  "$HOME"/.vim/autoload \
  "$HOME"/.vim/bundle \
  "$HOME"/.vim/colors \
  "$HOME"/.vim/backups \
  "$HOME"/.vim/swaps \
  "$HOME"/.vim/undo

# pathogen
curl -sSLo "$HOME"/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

# themes
curl -sSLo "$HOME"/.vim/colors/molokai.vim https://raw.githubusercontent.com/tomasr/molokai/master/colors/molokai.vim
git clone https://github.com/altercation/vim-colors-solarized.git "$HOME"/.vim/bundle/vim-colors-solarized

# vim-bracketed-paste
git clone https://github.com/ConradIrwin/vim-bracketed-paste.git "$HOME"/.vim/bundle/vim-bracketed-paste

# typescript
git clone https://github.com/leafgarland/typescript-vim.git "$HOME"/.vim/bundle/typescript-vim

