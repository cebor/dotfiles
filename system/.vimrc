" vim-plug
call plug#begin('~/.vim/plugged')
Plug 'tpope/vim-sensible'
Plug 'altercation/vim-colors-solarized'
Plug 'ConradIrwin/vim-bracketed-paste'
Plug 'leafgarland/typescript-vim'
call plug#end()

" Local dirs
set backupdir=~/.vim/backups
set directory=~/.vim/swaps
set undodir=~/.vim/undo

" 256 Colors
let g:solarized_termcolors=256
let g:rehash256=1

" Theme
set background=dark
silent! colorscheme solarized

set number " Line numbers
set cursorline " Highlight current line
set undofile " Persistent Undo

" Start in line where you left
if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif
