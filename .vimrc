" Syntax Highlighting
syntax on

" Theme
colorscheme molokai

" Line numbers
set number

" Uncomment the following to have Vim jump to the last position when
" reopening a file
if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif

" Wrap gitcommit file types at the appropriate length
filetype indent plugin on
