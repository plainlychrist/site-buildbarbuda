" Begin .vimrc

set nocompatible
set bs=2
set background=dark
set wrapmargin=8
syntax on
set ruler

set tabstop=8
set shiftwidth=2
set hidden
filetype indent on
filetype plugin on
set autoindent
set expandtab

"allow deletion of previously entered data in insert mode
set backspace=indent,eol,start

set incsearch
set ignorecase
set smartcase
set hlsearch

if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif

" End .vimrc
