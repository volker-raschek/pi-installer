#!/bin/bash

set -e

pacman --sync --sysupgrade --refresh --noconfirm
pacman --sync --noconfirm vim

# Checkout the repository that contains the VIM configuration
# and set the appropriate symbolic link. Checkout vim konfiguration
# without plugins.
git clone https://git.cryptic.systems/volker.raschek/vim.git ${HOME}/.vim

if [ -f ${HOME}/.vimrc ]; then
  rm ${HOME}/.vimrc
fi

cd ${HOME}/workspace/vim
git checkout -b no-plugins origin/no-plugins
