#!/bin/bash

set -e

# NOTE:
# Starting with raspberry pi 3+, the boot partition can be on the same device as
# the root partition, because this model can boot from external devices such as
# the sdcard. For older models the boot partition must be on a sdcard. The
# variables below defines the device for the boot and root partition. If your
# raspberry pi model is equal or greater than model 3+, use the same device to
# create both partitions on it.
BOOT_DEVICE=/dev/sdf
ROOT_DEVICE=/dev/sdf

# Set this property to 'TRUE' if your boot partition is location on an external
# SSD drive connected via USB.
#
# Background: To boot from an external SSD drive connected via USB is an
# additional module durning the boot of linux kernel by initramfs required. The
# initramfs can not be generated via this installation script and must be done
# manually!
# https://archlinuxarm.org/forum/viewtopic.php?f=67&t=14756
BOOT_ON_USB_SSD="FALSE"

# FIXME: AFTER INSTALLING UPDATE INITRAMFS, OTHERWISE CAN NOT BE THE EXTERNAL
# PARTITION ON A USB DEVICE BE FOUND!
# 1. MOUNT DISK ON OTHER AARCH ENVIRONMENT
# 2. EXECUTE arch-chroot
# 3. UPDATE SYSTEM
# 4. EXECUTE mkinitcpio -p

# Hostname/FQDN
PI_HOSTNAME="archlinux-aarch64-000"

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

# NOTE: Enable initramfs module pci_brcmstb if BOOT_ON_USB_SSD is true.
if [ ${BOOT_ON_USB_SSD} == "TRUE" ]; then
  sed --in-place --regexp-extended 's/^MODULES=\(\)/MODULES=(pcie_brcmstb)/' ./root/etc/mkinitcpio.conf
  cat > /dev/stdout <<EOF
WARNING: ArchLinux ARM will not boot without manual intervention!

You enabled BOOT_ON_USB_SSD. The initramfs module pcie_brcmstb is
not part of the current initramfs. This can lead to boot failures
until the initramfs has been successfully generates with the module
manually.

https://archlinuxarm.org/forum/viewtopic.php?f=67&t=14756
EOF
fi

# override fstab to mount boot partition with uuid
cat > ./root/etc/fstab <<EOF
# Static information about the filesystems.
# See fstab(5) for details.

# <file system>                             <dir>       <type>  <options>  <dump>   <pass>
UUID=${ROOT_UUID}   /           ext4    defaults        0       0
UUID=${BOOT_UUID}                              /boot       vfat    defaults        0       0
EOF

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
  ./root/root/.local/share/bash \
  ./root/root/.ssh

chown root:root \
  ./root/root/.ssh

chmod 0700 \
  ./root/root/.ssh

# umount partitions and remove old files
# umount ${BOOT} ${ROOT}
# rm --recursive --force ./root