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
TARBALL_SOURCE=http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-latest.tar.gz
TARBALL_SOURCE_SIG="${TARBALL_SOURCE}.sig"

# download tar
curl --location $TARBALL_SOURCE --output $TARBALL
curl --location $TARBALL_SOURCE_SIG --output $TARBALL_SIG

# check gpg
gpg --verify $TARBALL_SIG $TARBALL

# delete partitions
for p in $(parted -s $DEVICE print|awk '/^ / {print $1}'); do
  parted --script  $DEVICE rm $p
done

# partitioning
parted --script $DEVICE mkpart primary fat32 1MiB 100MiB
parted --script $DEVICE mkpart primary ext4  100Mib 100%

# file systems
mkfs.vfat $BOOT -L boot
mkfs.ext4 $ROOT -L root

# mount file systems
if [ ! -d boot ]; then
  mkdir boot
fi

if [ ! -d root ]; then
  mkdir root
fi

mount $BOOT ./boot
mount $ROOT ./root


# extract tar
tar --extract --gunzip --same-permissions --file $PI_IMAGE --directory ./root
sync

# move bootloader
mv ./root/boot/* ./boot

# install ssh pub key
mkdir ./root/root/.ssh
cat > ./root/root/.ssh/authorized_keys <<EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPOydCxv9/tAV7AdS2HsUIEu547Z5qUJnWYwiO7rI9YL markus-pc
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJUTcUBb+55jRY9TkpLgm8K/8nJfEXyjEX8zljdCCRpi markus-nb
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVGxeVfkycwzP7UkLujGzDjC+9lPML45V7+bBmkKyD0 backup
EOF
chown root: ./root/root/.ssh/authorized_keys
chmod 640 ./root/root/.ssh/authorized_keys

# umount partitions and remove old files
umount $BOOT $ROOT
rm -Rf ./boot ./root $PI_IMAGE
