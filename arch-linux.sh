#!/bin/bash

set -e

# Device, define device for the new arch installation
DEVICE=/dev/sdb

# boot and root partitions
BOOT="${DEVICE}1"
ROOT="${DEVICE}2"

# Arch Linux Image
TARBALL=ArchLinuxARM-rpi-latest.tar.gz
TARBALL_SIG="${TARBALL}.sig"
TARBALL_SOURCE=http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-3-latest.tar.gz
TARBALL_SOURCE_SIG="${TARBALL_SOURCE}.sig"
TARBALL_SIG_KEY="68B3537F39A313B3E574D06777193F152BDBE6A6"

# download tar
if [ ! -f ${TARBALL} ]; then
  curl --location ${TARBALL_SOURCE} --output ${TARBALL}
fi

if [ ! -f ${TARBALL_SIG} ]; then
  curl --location ${TARBALL_SOURCE_SIG} --output ${TARBALL_SIG}
fi

# check gpg
# gpg --recv-keys ${TARBALL_SIG_KEY}
# gpg --verify ${TARBALL_SIG} ${TARBALL}

# delete partitions
for p in $(parted -s $DEVICE print|awk '/^ / {print $1}'); do
  parted --script  $DEVICE rm $p
done

# partitioning
parted --script $DEVICE mkpart primary fat32 1MiB 100MiB
parted --script $DEVICE mkpart primary ext4  100Mib 100%

# file systems
mkfs.vfat ${BOOT}
mkfs.ext4 ${ROOT} -L root

# mount file systems
if [ ! -d boot ]; then
  mkdir boot
fi

if [ ! -d root ]; then
  mkdir root
fi

mount ${BOOT} ./boot
mount ${ROOT} ./root

# extract tar
tar --extract --gunzip --same-permissions --directory="./root" --file ${TARBALL}
sync

# move bootloader
mv ./root/boot/* ./boot

# install ssh pub key
cat > ./root/root/.ssh/authorized_keys <<EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPOydCxv9/tAV7AdS2HsUIEu547Z5qUJnWYwiO7rI9YL markus-pc
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJUTcUBb+55jRY9TkpLgm8K/8nJfEXyjEX8zljdCCRpi markus-nb
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVGxeVfkycwzP7UkLujGzDjC+9lPML45V7+bBmkKyD0 backup
EOF

chown root:root -R ./root/root/.ssh/authorized_keys
chmod 640 ./root/root/.ssh/authorized_keys

# set hosts
cat > ./root/etc/hosts <<EOF
127.0.0.1       localhost
127.0.1.1       localhost.localdomain localhost

# The following lines are desirable for IPv6 capable hosts
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF



# default bashrc
cat > ./root/root/.bashrc <<"EOF"
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Bash settings
shopt -s globstar
shopt -s histappend

# Aliases
uap='pacman --sync --sysupgrade --refresh'

export PS1='\u@\h:\w$(__git_ps1 " (%s)")\$ '
EOF


# umount partitions and remove old files
umount ${BOOT} ${ROOT}
rm -Rf ./boot ./root ${TARBALL} ${TARBALL_SIG}
