#!/bin/bash

set -e

# pacman: initiate key ring
pacman-key --init
pacman-key --populate archlinuxarm

# pacman: add key from reflector developer
pacman-key --recv-key EC3CBE7F607D11E663149E811D1F0DC78F173680
pacman-key --lsign-key EC3CBE7F607D11E663149E811D1F0DC78F173680

# pacman: add reflector developer repository
# cat >> /etc/pacman.conf <<EOF
# [xyne-any]
# # A repo for Xyne's own projects: https://xyne.archlinux.ca/projects/
# # Packages for "any" architecture.
# # Use this repo only if there is no matching [xyne-*] repo for your architecture.
# SigLevel = Required
# Server = https://xyne.archlinux.ca/repos/xyne

# EOF

# pacman: sysupgrade
pacman --sync --refresh --sysupgrade --noconfirm

# pacman: install pkgs
pacman --sync --noconfirm bash-completion bind-tools git pacman-contrib reflector vim

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
Exec = /usr/bin/paccache -rvk3
EOF

# pacman: reflector hook
cat > /etc/pacman.d/hooks/reflector.hook <<EOF
[Trigger]
Operation = Upgrade
Type = Package
Target = pacman-mirrorlist

[Action]
Description = Updating pacman-mirrorlist with reflactor and removing pacnew
When = PostTransaction
Depends = reflector
Exec = /bin/sh -c "reflector --verbose --latest 10 --sort rate --protocol https --country Germany --save /etc/pacman.d/mirrorlist; rm -f /etc/pacman.d/mirrorlist.pacnew"
EOF

# pacman: enable hooks
sed -i -E 's@^#(HookDir.*)@\1@' /etc/pacman.conf
