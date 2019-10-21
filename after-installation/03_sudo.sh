#!/bin/bash

pacman --sync --sysupgrade --refresh
pacman --sync sudo

sed --in-place 's@# %wheel ALL=(ALL) ALL@%wheel ALL=(ALL) ALL@g' /etc/sudoers
