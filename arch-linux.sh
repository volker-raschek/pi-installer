#!/bin/bash

set -e

# NOTE:
# Starting with raspberry pi 3+, the boot partition can be on the same device as
# the root partition, because this model can boot from external devices such as
# the sdcard. For older models the boot partition must be on a sdcard. The
# variables below defines the device for the boot and root partition. If your
# raspberry pi model is equal or greater than model 3+, use the same device to
# create both partitions on it.
BOOT_DEVICE=/dev/sdc
ROOT_DEVICE=/dev/sdf

# Hostname/FQDN
PI_HOSTNAME="poseidon"
PI_FQDN="poseidon.trier.cryptic.systems"

# Arch Linux Image
TARBALL=ArchLinuxARM-rpi-latest.tar.gz
TARBALL_SIG="${TARBALL}.sig"
TARBALL_SOURCE=http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz
# TARBALL_SOURCE=http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-3-latest.tar.gz
TARBALL_SOURCE_SIG="${TARBALL_SOURCE}.sig"
TARBALL_SIG_KEY="68B3537F39A313B3E574D06777193F152BDBE6A6"

# Locale
LOCALE=("LANG=de_DE.UTF-8")
LOCALE_GEN=("de_DE.UTF-8 UTF-8" "en_US.UTF-8 UTF-8")

# Keyboad language
VCONSOLE="de-latin1"

# Timezone
TIMEZONE=Europe/Berlin

# Enable bus
ENABLE_I2C="true"
ENABLE_WIRE="true"

# DNSSEC
# Possible values:
# - yes
# - allow-downgrade
# - no
DNSSEC="no"

#########################################################################################

# download tar
if [ ! -f ${TARBALL} ]; then
  curl --location ${TARBALL_SOURCE} --output ${TARBALL}
fi

if [ ! -f ${TARBALL_SIG} ]; then
  curl --location ${TARBALL_SOURCE_SIG} --output ${TARBALL_SIG}
fi

# download gpg signing keys and verify tarball
gpg --recv-keys ${TARBALL_SIG_KEY}
gpg --verify ${TARBALL_SIG} ${TARBALL}

# define BOOT and ROOT_PARTITIONS
if [ "${BOOT_DEVICE}" == "${ROOT_DEVICE}" ]; then
  BOOT="${BOOT_DEVICE}1"
  ROOT="${ROOT_DEVICE}2"
else
  BOOT="${BOOT_DEVICE}1"
  ROOT="${ROOT_DEVICE}1"
fi

# delete partitions
for P in $(parted --script ${BOOT_DEVICE} print | awk '/^ / {print $1}'); do
  parted --script ${BOOT_DEVICE} rm ${P}
done

for P in $(parted --script ${ROOT_DEVICE} print | awk '/^ / {print $1}'); do
  parted --script ${ROOT_DEVICE} rm ${P}
done

# partitioning
if [ "${BOOT_DEVICE}" == "${ROOT_DEVICE}" ]; then
  parted --script ${BOOT_DEVICE} mkpart primary fat32 1MiB 100MiB
  parted --script ${ROOT_DEVICE} mkpart primary ext4 100Mib 100%
  parted --script ${BOOT_DEVICE} set 1 boot on
else
  parted --script ${BOOT_DEVICE} mkpart primary fat32 0% 100%
  parted --script ${ROOT_DEVICE} mkpart primary ext4 0% 100%
  parted --script ${BOOT_DEVICE} set 1 boot on
fi

# create file systems
mkfs.vfat ${BOOT}
mkfs.ext4 ${ROOT} -L root

# read partition UUIDs
BOOT_UUID=$(blkid --match-tag UUID --output value ${BOOT})
ROOT_UUID=$(blkid --match-tag UUID --output value ${ROOT})

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

# write cached files on disk
sync --file-system ${BOOT_DEVICE}
sync --file-system ${ROOT_DEVICE}

# move bootloader
mv ./root/boot/* ./boot

# override partition name with partition uuid to find root partition
CMD=$(cat ./boot/cmdline.txt)
cat > ./boot/cmdline.txt <<EOF
root=UUID=${ROOT_UUID} $(echo ${CMD} | cut -d ' ' -f 2-)
EOF

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

# DNSSEC
sed --in-place "s/#DNSSEC=no/DNSSEC=${DNSSEC}/g" ./root/etc/systemd/resolved.conf

# enable i2c bus interface
if [ "${ENABLE_I2C}" == "true" ]; then
 echo "dtparam=i2c_arm=on" >> ./boot/config.txt
 echo "i2c-dev" >> ./root/etc/modules-load.d/raspberrypi.conf
 echo "i2c-bcm2708" >> ./root/etc/modules-load.d/raspberrypi.conf
fi

# enable 1-wire interface
if [ "${ENABLE_WIRE}" == "true" ]; then
 echo "dtoverlay=w1-gpio" >> ./boot/config.txt
fi


# install ssh pub key
mkdir --parents ./root/root/.ssh
cat > ./root/root/.ssh/authorized_keys <<EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPOydCxv9/tAV7AdS2HsUIEu547Z5qUJnWYwiO7rI9YL
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJUTcUBb+55jRY9TkpLgm8K/8nJfEXyjEX8zljdCCRpi
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVGxeVfkycwzP7UkLujGzDjC+9lPML45V7+bBmkKyD0
EOF

chown root:root --recursive ./root/root/.ssh/authorized_keys
chmod 640 ./root/root/.ssh/authorized_keys
chmod 750 ./root/root/.ssh

# configure SSH daemon
sed --in-place "s/#PasswordAuthentication yes/PasswordAuthentication no/" ./root/etc/ssh/sshd_config
sed --in-place "s/#PermitRootLogin prohibit-password/PermitRootLogin without-password/" ./root/etc/ssh/sshd_config
sed --in-place "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" ./root/etc/ssh/sshd_config
sed --in-place "s/#UseDNS no/UseDNS no/" ./root/etc/ssh/sshd_config

# set hosts
cat > ./root/etc/hosts <<EOF
127.0.0.1       localdomain.localhost localhost
::1             localdomain.localhost localhost
127.0.1.1       ${PI_FQDN} ${PI_HOSTNAME}
EOF

# set hostname
cat > ./root/etc/hostname <<EOF
${PI_HOSTNAME}
EOF

# default bash_profile for login-shells
cat > ./root/root/.bash_profile <<EOF
[[ -f ~/.bashrc ]] && . ~/.bashrc
EOF

# default bashrc used for sub-shells
cat > ./root/root/.bashrc <<"EOF"
#  ~/.bashrc
#

# If not running interactively, don't do anything
 [[ $- != *i* ]] && return

# Bash settings
shopt -s globstar                                                         # activate globstar option
shopt -s histappend                                                       # activate append history

# XDG Base Directory
export XDG_CONFIG_HOME="${HOME}/.config"                                  # FreeDesktop - config directory for programms
export XDG_CACHE_HOME="${HOME}/.cache"                                    # FreeDesktop - cache directory for programms
export XDG_DATA_HOME="${HOME}/.local/share"                               # FreeDesktop - home directory of programm data

# Sources
[ -f "${XDG_DATA_HOME}/bash/git" ] && source "${XDG_DATA_HOME}/bash/git"  # git bash-completion and prompt functions

# XDG Base Directory Configs
export GNUPGHOME="${XDG_CONFIG_HOME}/gnupg"                               # gpg (home dir)
export HISTCONTROL="ignoreboth"                                           # Don't put duplicate lines or starting with spaces in the history
export HISTSIZE="1000"                                                    # Max lines in bash history # Append 2000 lines after closing sessions
export HISTFILE="${XDG_DATA_HOME}/bash/history"                           # Location of bash history file
export HISTFILESIZE="2000"                                                # Max lines in bash history
export LESSHISTFILE="${XDG_CACHE_HOME}/less/history"                      # less history (home dir)
export LESSKEY="${XDG_CONFIG_HOME}/less/lesskey"                          # less

# Programm Settings
export EDITOR="vim"                                                       # default editor (no full-screen)
export PS1='\u@\h:\w\$ '                                                  # Bash prompt with git
export VISUAL="vim"                                                       # default editor (full-screen)

# General Aliases
alias ..='cd ..'
alias ...='cd ../..'
alias ghistory='history | grep'                                           # Shortcut to grep in history
alias ports='ss -atun'                                                    # List all open ports from localhost

# Aliases for pacman
alias piap='pacman --query --info'                                         # Pacman: Information-About-Package
alias plao='pacman --query --deps --unrequired'                            # Pacman: List-All-Orphans
alias plip='pacman --query --quiet --explicit'                             # Pacman: List-Information-Package
alias puap='pacman --sync --refresh --sysupgrade'                          # Pacman: Update-All-Packages
alias puld='pacman --sync --refresh'                                       # Pacman: Update-Local-Database
alias prao='pacman --remove --nosave --recursive \
           $(pacman --query --unrequired --deps --quiet)'                  # Pacman: Remove-All-Orphans Packages
alias prsp='pacman --remove --recursive --nosave'                          # Pacman: Remove-Single-Package
EOF

# create XDG-Specificantion-Based Directories
mkdir --parents \
  ./root/root/.cache/less \
  ./root/root/.config \
  ./root/root/.config/gnupg \
  ./root/root/.config/less \
  ./root/root/.local/share \
  ./root/root/.local/share/bash


# set permissions for gnupg homedir
chmod 700 ./root/root/.config/gnupg
chown root:root ./root/root/.config/gnupg

# download gpg public keys
gpg --homedir ./root/root/.config/gnupg --recv-keys 9B146D11A9ED6CA7E279EB1A852BCC170D81A982

# checkout after installation scripts
mkdir ./root/root/workspace
git clone https://github.com/volker-raschek/pi-installer.git ./root/root/workspace/pi-installer

# kill gpg-agent and dirmngr
kill $(ps aux | grep dirmngr | awk '{print $2}') || true
kill $(ps aux | grep gpg-agent | awk '{print $2}') || true

# umount partitions and remove old files
umount ${BOOT} ${ROOT}
rm --recursive --force ./boot ./root ${TARBALL} ${TARBALL_SIG}
