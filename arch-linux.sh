#!/bin/bash

set -e

# BASENAME_BIN
# Absolute path to the basename binary.
BASENAME_BIN=${BASENAME_BIN:-$(which basename)}

# BLKID_BIN
# Absolute path to the blkid binary.
BLKID_BIN=${BLKID_BIN:-$(which blkid)}

# BSDTAR_BIN
# Absolute path to the bsdtar binary.
BSDTAR_BIN=${BSDTAR_BIN:-$(which bsdtar)}

# CAT_BIN
# Absolute path to the cat binary.
CAT_BIN=${CAT_BIN:-$(which cat)}

# CHMOD_BIN
# Absolute path to the chmod binary.
CHMOD_BIN=${CHMOD_BIN:-$(which chmod)}

# CHOWN_BIN
# Absolute path to the chown binary.
CHOWN_BIN=${CHOWN_BIN:-$(which chown)}

# CURL_BIN
# Absolute path to the curk binary.
CURL_BIN=${CURL_BIN:-$(which curl)}

# FSCK_EXT4_BIN
# Absolute path to the fsck.ext4 binary.
FSCK_EXT4_BIN=${FSCK_EXT4_BIN:-$(which fsck.ext4)}

# FSCK_VFAT_BIN
# Absolute path to the fsck.vfat binary.
FSCK_VFAT_BIN=${FSCK_VFAT_BIN:-$(which fsck.vfat)}

# MKDIR_BIN
# Absolute path to the mkdir binary.
MKDIR_BIN=${MKDIR_BIN:-$(which mkdir)}

# MKFS_EXT4_BIN
# Absolute path to the mkfs.ext4 binary.
MKFS_EXT4_BIN=${MKFS_EXT4_BIN:-$(which mkfs.ext4)}

# MKFS_VFAT_BIN
# Absolute path to the mkfs.vfat binary.
MKFS_VFAT_BIN=${MKFS_VFAT_BIN:-$(which mkfs.vfat)}

# MOUNT_BIN
# Absolute path to the mount binary.
MOUNT_BIN=${MOUNT_BIN:-$(which mount)}

# PARTED_BIN
# Absolute path to the parted binary.
PARTED_BIN=${PARTED_BIN:-$(which parted)}

# SED_BIN
# Absolute path to the sed binary.
SED_BIN=${SED_BIN:-$(which sed)}

# SYNC_BIN
# Absolute path to the sync binary.
SYNC_BIN=${SYNC_BIN:-$(which sync)}

# UMOUNT_BIN
# Absolute path to the mount binary.
UMOUNT_BIN=${UMOUNT_BIN:-$(which umount)}

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
  if [ ! -f $(${BASENAME_BIN} ${SOURCE}) ]; then
    ${CURL_BIN} --location ${SOURCE} --output $(${BASENAME_BIN} ${SOURCE})
  fi
done

# # download gpg signing keys and verify tarball
# for SIG_KEY in ${SIG_KEYS}; do
#   gpg --recv-keys ${SIG_KEY}
#   gpg --verify $(${BASENAME_BIN} ${SOURCES[1]}) $(${BASENAME_BIN} ${SOURCES[0]})
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
${UMOUNT_BIN} -r ${ROOT}

# delete partitions
for P in $(${PARTED_BIN} --script ${BOOT_DEVICE} print | awk '/^ / {print $1}'); do
  ${PARTED_BIN} --script ${BOOT_DEVICE} rm ${P}
done

for P in $(${PARTED_BIN} --script ${ROOT_DEVICE} print | awk '/^ / {print $1}'); do
  ${PARTED_BIN} --script ${ROOT_DEVICE} rm ${P}
done

# partitioning
if [ "${BOOT_DEVICE}" == "${ROOT_DEVICE}" ]; then
  ${PARTED_BIN} --script ${BOOT_DEVICE} mkpart primary fat32 1MiB 2GiB
  ${PARTED_BIN} --script ${ROOT_DEVICE} mkpart primary ext4 2Gib 100%
  ${PARTED_BIN} --script ${BOOT_DEVICE} set 1 boot on
else
  ${PARTED_BIN} --script ${BOOT_DEVICE} mkpart primary fat32 0% 100%
  ${PARTED_BIN} --script ${ROOT_DEVICE} mkpart primary ext4 0% 100%
  ${PARTED_BIN} --script ${BOOT_DEVICE} set 1 boot on
fi

# create file systems
${MKFS_VFAT_BIN} ${BOOT}
${MKFS_EXT4_BIN} ${ROOT} -L root

# check filesystem
${FSCK_VFAT_BIN} -vy ${BOOT}
${FSCK_EXT4_BIN} -vy ${ROOT}

# read partition UUIDs
BOOT_UUID=$(${BLKID_BIN} --match-tag UUID --output value ${BOOT})
ROOT_UUID=$(${BLKID_BIN} --match-tag UUID --output value ${ROOT})

# mount file systems
${MKDIR_BIN} ./root || true
${MOUNT_BIN} ${ROOT} ./root
${MKDIR_BIN} ./root/boot || true
${MOUNT_BIN} ${BOOT} ./root/boot

# extract tar
# tar --extract --gzip --same-permissions --file $(${BASENAME_BIN} ${SOURCES[0]}) --directory="./root"
${BSDTAR_BIN} --extract --preserve-permissions --file $(${BASENAME_BIN} ${SOURCES[0]}) --directory="./root"

# write cached files on disk
${SYNC_BIN} --file-system ${BOOT_DEVICE}
${SYNC_BIN} --file-system ${ROOT_DEVICE}

# NOTE: Enable initramfs module pci_brcmstb if BOOT_ON_USB_SSD is true.
if [ ${BOOT_ON_USB_SSD} == "TRUE" ]; then
  ${SED_BIN} --in-place --regexp-extended 's/^MODULES=\(\)/MODULES=(pcie_brcmstb)/' ./root/etc/mkinitcpio.conf
  ${CAT_BIN} > /dev/stdout <<EOF
WARNING: ArchLinux ARM will not boot without manual intervention!

You enabled BOOT_ON_USB_SSD. The initramfs module pcie_brcmstb is
not part of the current initramfs. This can lead to boot failures
until the initramfs has been successfully generates with the module
manually.

https://archlinuxarm.org/forum/viewtopic.php?f=67&t=14756
EOF
fi

# override fstab to mount boot partition with uuid
${CAT_BIN} > ./root/etc/fstab <<EOF
# Static information about the filesystems.
# See fstab(5) for details.

# <file system>                             <dir>       <type>  <options>  <dump>   <pass>
UUID=${ROOT_UUID}   /           ext4    defaults        0       0
UUID=${BOOT_UUID}                              /boot       vfat    defaults        0       0
EOF

# set hosts
${CAT_BIN} > ./root/etc/hosts <<EOF
127.0.0.1       localdomain.localhost localhost
::1             localdomain.localhost localhost
EOF

# set hostname
${CAT_BIN} > ./root/etc/hostname <<EOF
${PI_HOSTNAME}
EOF

# default bash_profile for login-shells
${CAT_BIN} > ./root/root/.bash_profile <<EOF
[[ -f ~/.bashrc ]] && . ~/.bashrc
EOF

# create XDG-Specificantion-Based Directories
${MKDIR_BIN} --parents \
  ./root/etc/pacman.d/gnupg \
  ./root/root/.cache/less \
  ./root/root/.config \
  ./root/root/.config/gnupg \
  ./root/root/.config/less \
  ./root/root/.local/share \
  ./root/root/.local/share/bash \
  ./root/root/.ssh

${CHOWN_BIN} root:root \
  ./root/root/.ssh

${CHMOD_BIN} 0700 \
  ./root/root/.ssh

# umount partitions
# ${UMOUNT_BIN} -r ${ROOT}