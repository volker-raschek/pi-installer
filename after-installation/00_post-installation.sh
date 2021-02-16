#!/bin/bash

# pacman
pacman-key --init
pacman-key --populate archlinuxarm

# markus.pesch [at] cryptic.systems
pacman-key --recv-keys 9B146D11A9ED6CA7E279EB1A852BCC170D81A982
pacman-key --lsign 9B146D11A9ED6CA7E279EB1A852BCC170D81A982

# pacman: add repositories
cat >> /etc/pacman.conf <<EOF

[any]
Server = https://aur.cryptic.systems/any/

[armv7]
Server = https://aur.cryptic.systems/armv7/
EOF

pacman --sync --refresh --sysupgrade --noconfirm base-devel bash-completion bind-tools pacman-contrib

# pacman: hooks directory
mkdir /etc/pacman.d/hooks

# pacman: paccache hook
cat > /etc/pacman.d/hooks/paccache.hook <<EOF
[Trigger]
Operation = Remove
Operation = Install
Operation = Upgrade
Type = Package
Target = *

[Action]
Description = Keep the last cache and the currently installed.
When = PostTransaction
Exec = /usr/bin/paccache --remove --verbose --keep 3
EOF

# pacman: enable hooks
sed --in-place --regexp-extended 's@^#(HookDir.*)@\1@' /etc/pacman.conf

# pacman: install own pkgs
pacman --sync --sysupgrade --refresh cs-dev-sshkeys git git-prompt inetutils sudo vim

# enable sudo for wheel group
sed --in-place 's@# %wheel ALL=(ALL) ALL@%wheel ALL=(ALL) ALL@g' /etc/sudoers

# vim config
git config --global user.name "${USER}"
git config --global user.email "${USER}@$(hostname)"
git config --global help.autocorrect 10
git config --global alias.lo "log --abbrev-commit --decorate --graph --histogram --all"
git config --global alias.los "log --abbrev-commit --decorate --graph --histogram --all --show-signature"
git config --global alias.loo "log --abbrev-commit --decorate --graph --histogram --all --oneline"
git config --global alias.loos "log --abbrev-commit --decorate --graph --histogram --all --oneline --show-signature"
git config --global alias.fixup "commit --amend --no-edit"
git config --global color.ui auto
git config --global core.editor "vim -c 'set textwidth=72'"

# Checkout the repository that contains the VIM configuration
# and set the appropriate symbolic link. Checkout vim konfiguration
# without plugins.

if [ -f ${HOME}/.vimrc ]; then
  rm ${HOME}/.vimrc
fi

git clone https://git.cryptic.systems/volker.raschek/vim.git ${HOME}/.vim
cd ${HOME}/.vim
git checkout -b no-plugins origin/no-plugins
cd ${HOME}/workspace/pi-installer/after-installation