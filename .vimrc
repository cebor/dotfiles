" Pathogen
execute pathogen#infect()

" 256 Colors
let g:solarized_termcolors=256
let g:rehash256=1

" Syntax Highlighting
syntax enable
set background=dark
colorscheme molokai

" Local dirs
set backupdir=~/.vim/backups
set directory=~/.vim/swaps
set undodir=~/.vim/undo

" Line numbers
set number

" Uncomment the following to have Vim jump to the last position when
" reopening a file
if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif

" Wrap gitcommit file types at the appropriate length
filetype indent plugin on

" Indent Settings
set smartindent
set tabstop=4
set shiftwidth=4
set expandtab

" Set some configs
set backspace=indent,eol,start " Backspace fix
set cursorline " Highlight current line
