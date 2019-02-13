#!/bin/bash

# Checkout the repository that contains the VIM configuration
# and set the appropriate symbolic link
git clone ssh://git@git.cryptic.systems:10022/volker.raschek/vim.git ${HOME}/workspace/vim
ln -s ${HOME}/workspace/vim/vimrc ${HOME}/.vimrc
