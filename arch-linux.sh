#!/bin/bash

set -ex

# NOTE:
# Starting with raspberry pi 3+, the boot partition can be on the same device as
# the root partition, because this model can boot from external devices such as
# the sdcard. For older models the boot partition must be on a sdcard. The
# variables below defines the device for the boot and root partition. If your
# raspberry pi model is equal or greater than model 3+, use the same device to
# create both partitions on it.
BOOT_DEVICE=/dev/sde
ROOT_DEVICE=/dev/sde

# Hostname/FQDN
PI_HOSTNAME="archlinux-aarch64-002"

# Arch Linux Image
SOURCES=(
  # http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz
  # http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz.sig

  # http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-4-latest.tar.gz
  # http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-4-latest.tar.gz.sig

  http://de4.mirror.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz
  http://de4.mirror.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz.sig
)

SIG_KEYS=(
  68B3537F39A313B3E574D06777193F152BDBE6A6
)

# Locale
LOCALE=("LANG=de_DE.UTF-8")
LOCALE_GEN=("de_DE.UTF-8 UTF-8" "en_US.UTF-8 UTF-8")

# Keyboad language
VCONSOLE="de-latin1"

# Timezone
TIMEZONE=Europe/Berlin

#########################################################################################

# download sources
for SOURCE in ${SOURCES[@]}; do
  if [ ! -f $(basename ${SOURCE}) ]; then
    curl --location ${SOURCE} --output $(basename ${SOURCE})
  fi
done

# # download gpg signing keys and verify tarball
# for SIG_KEY in ${SIG_KEYS}; do
#   gpg --recv-keys ${SIG_KEY}
#   gpg --verify $(basename ${SOURCES[1]}) $(basename ${SOURCES[0]})
# done

# define BOOT and ROOT_PARTITIONS
if [ "${BOOT_DEVICE}" == "${ROOT_DEVICE}" ]; then
  BOOT="${BOOT_DEVICE}1"
  ROOT="${ROOT_DEVICE}2"
else
  BOOT="${BOOT_DEVICE}1"
  ROOT="${ROOT_DEVICE}1"
fi

# unmount if mounted
for fs in {"./root/boot","./root"}; do
  umount ${fs} || true
done

# delete partitions
for P in $(parted --script ${BOOT_DEVICE} print | awk '/^ / {print $1}'); do
  parted --script ${BOOT_DEVICE} rm ${P}
done

for P in $(parted --script ${ROOT_DEVICE} print | awk '/^ / {print $1}'); do
  parted --script ${ROOT_DEVICE} rm ${P}
done

# partitioning
if [ "${BOOT_DEVICE}" == "${ROOT_DEVICE}" ]; then
  parted --script ${BOOT_DEVICE} mkpart primary fat32 1MiB 2GiB
  parted --script ${ROOT_DEVICE} mkpart primary ext4 2Gib 100%
  parted --script ${BOOT_DEVICE} set 1 boot on
else
  parted --script ${BOOT_DEVICE} mkpart primary fat32 0% 100%
  parted --script ${ROOT_DEVICE} mkpart primary ext4 0% 100%
  parted --script ${BOOT_DEVICE} set 1 boot on
fi

# create file systems
mkfs.vfat ${BOOT}
mkfs.ext4 ${ROOT} -L root

# check filesystem
fsck.vfat -vy ${BOOT}
fsck.ext4 -vy ${ROOT}

# read partition UUIDs
BOOT_UUID=$(blkid --match-tag UUID --output value ${BOOT})
ROOT_UUID=$(blkid --match-tag UUID --output value ${ROOT})

# mount file systems
mkdir ./root || true
mount ${ROOT} ./root
mkdir ./root/boot || true
mount ${BOOT} ./root/boot

# extract tar
# tar --extract --gzip --same-permissions --file $(basename ${SOURCES[0]}) --directory="./root"
bsdtar --extract --preserve-permissions --file $(basename ${SOURCES[0]}) --directory="./root"

# write cached files on disk
sync --file-system ${BOOT_DEVICE}
sync --file-system ${ROOT_DEVICE}

# add module, otherwise can not be booted from usb
# https://archlinuxarm.org/forum/viewtopic.php?f=67&t=14756
sed --in-place --regexp-extended 's/^MODULES=\(\)/MODULES=(pcie_brcmstb)/' ./root/etc/mkinitcpio.conf

# override fstab to mount boot partition with uuid
cat > ./root/etc/fstab <<EOF
# Static information about the filesystems.
# See fstab(5) for details.

# <file system>                             <dir>       <type>  <options>  <dump>   <pass>
UUID=${ROOT_UUID}   /           ext4    defaults        0       0
UUID=${BOOT_UUID}                              /boot       vfat    defaults        0       0
EOF

# set locale.conf
for L in ${LOCALE[@]}; do
  echo ${L} >> ./root/etc/locale.conf
done

# set locale.gen
for L in ${LOCALE_GEN[@]}; do
  sed --in-place "s/#${L}/${L}/" ./root/etc/locale.gen
done

# set vconsole
cat > ./root/etc/vconsole.conf <<EOF
KEYMAP=${VCONSOLE}
EOF

# set timezone
ln --symbolic --force --relative ./root/usr/share/zoneinfo/Europe/Berlin ./root/etc/localtime

# set hosts
cat > ./root/etc/hosts <<EOF
127.0.0.1       localdomain.localhost localhost
::1             localdomain.localhost localhost
EOF

# set hostname
cat > ./root/etc/hostname <<EOF
${PI_HOSTNAME}
EOF

# default bash_profile for login-shells
cat > ./root/root/.bash_profile <<EOF
[[ -f ~/.bashrc ]] && . ~/.bashrc
EOF

# create XDG-Specificantion-Based Directories
mkdir --parents \
  ./root/etc/pacman.d/gnupg \
  ./root/root/.cache/less \
  ./root/root/.config \
  ./root/root/.config/gnupg \
  ./root/root/.config/less \
  ./root/root/.local/share \
  ./root/root/.local/share/bash

# umount partitions and remove old files
umount ${BOOT} ${ROOT}
rm --recursive --force ./root