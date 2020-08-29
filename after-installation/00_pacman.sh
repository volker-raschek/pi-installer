#!/bin/bash

set -e

# pacman: initiate key ring
pacman-key --init
pacman-key --populate archlinuxarm

# pacman: add developer key
pacman-key --recv-keys 9B146D11A9ED6CA7E279EB1A852BCC170D81A982
pacman-key --lsign 9B146D11A9ED6CA7E279EB1A852BCC170D81A982

# pacman: sysupgrade
pacman --sync --refresh --sysupgrade --noconfirm

# pacman: install pkgs
pacman --sync --noconfirm base-devel bash-completion bind-tools pacman-contrib

# pacman: add repositories
cat >> /etc/pacman.conf <<EOF

[cs_any]
Server = https://aur.cryptic.systems/any/

[cs_armv7]
Server = https://aur.cryptic.systems/armv7/
EOF

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
