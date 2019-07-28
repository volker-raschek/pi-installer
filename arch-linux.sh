#!/bin/bash

# Error handling
# If any error occur, stop and exit immediately the bash.
set -e

# DEVICE
# Specifies the USB device on which the system is to be installed.
DEVICE=/dev/sdb

# BOOT/ROOT
# Specifies the ROOT and BOOT partitions. It is important not to boot from the
# ROOT partition, as the RaspberryPi3b+ can only boot from fat32 and therefore
# the use of an ext4 or btrfs file system for the ROOT partition would not be
# possible.
BOOT="${DEVICE}1"
ROOT="${DEVICE}2"

# Hostname/FQDN
PI_HOSTNAME="hades"
PI_FQDN="hades.hellenthal.cryptic.systems"

# TARBALL
# Defines the HTTP source of the Arch Linux Archive and its signature file that
# is required to verify the archive as well as its file name as it is to be
# named locally on the file system later.
TARBALL=ArchLinuxARM-rpi-latest.tar.gz
TARBALL_SIG="${TARBALL}.sig"
TARBALL_SOURCE=http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz
# TARBALL_SOURCE=http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-3-latest.tar.gz
TARBALL_SOURCE_SIG="${TARBALL_SOURCE}.sig"
TARBALL_SIG_KEY="68B3537F39A313B3E574D06777193F152BDBE6A6"

# LOCALE
# Defines the locale include language
LOCALE=("LANG=de_DE.UTF-8")
LOCALE_GEN=("de_DE.UTF-8 UTF-8" "en_US.UTF-8 UTF-8")

# TIMEZONE
TIMEZONE=Europe/Berlin

# I2C_BUS
# If I2C_BUS is true, it's would be started at boot.
I2C_BUS="false"

# WIRE_BUS
# If WIRE_BUS is true, it's would be started at boot.
WIRE_BUS="false"

# WPA_SUPPLICANT_CONF
# If the host system contains a wpa_supplicant conf, this is stored on the new
# system. The wpa_supplicant service for the WLAN interface wlan0 is activated
# and systemd-networkd is set up.
WPA_SUPPLICANT_CONF="/etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf"

#########################################################################################

# download tarball
if [ ! -f ${TARBALL} ]; then
  curl --location ${TARBALL_SOURCE} --output ${TARBALL}
fi

# download tarballs signature
if [ ! -f ${TARBALL_SIG} ]; then
  curl --location ${TARBALL_SOURCE_SIG} --output ${TARBALL_SIG}
fi

# download gpg signing keys and verify tarball
gpg --recv-keys ${TARBALL_SIG_KEY}
gpg --verify ${TARBALL_SIG} ${TARBALL}

# delete partitions on sd-card if anyone exists
for P in $(parted --script ${DEVICE} print | awk '/^ / {print $1}'); do
  parted --script ${DEVICE} rm ${P}
done

# partitioning sd-card
parted --script ${DEVICE} mkpart primary fat32 1MiB 100MiB
parted --script ${DEVICE} mkpart primary ext4 100Mib 100%
parted --script ${DEVICE} set 1 boot on

# create file systems
mkfs.vfat ${BOOT}
mkfs.ext4 ${ROOT} -L root

# read partition UUIDs
BOOT_UUID=$(blkid --match-tag UUID --output value ${BOOT})
ROOT_UUID=$(blkid --match-tag UUID --output value ${ROOT})

# create directory to mount boot partition
if [ ! -d boot ]; then
  mkdir boot
fi

# create directory to mount root partition
if [ ! -d root ]; then
  mkdir root
fi

# mount boot and root partition
mount ${BOOT} ./boot
mount ${ROOT} ./root

# extract tarball on root partition
tar --extract --gunzip --same-permissions --directory="./root" --file ${TARBALL}

# write all memory cached file states on disks
sync

# move bootloader into boot partition
mv ./root/boot/* ./boot

# replace boot partition name with uuid
CMD=$(cat ./boot/cmdline.txt)
cat > ./boot/cmdline.txt <<EOF
root=UUID=${ROOT_UUID} $(echo ${CMD} | cut -d ' ' -f 2-)
EOF

# enable i2c-bus
if [ ${I2C_BUS} == "true" ]; then
  echo "dtparam=i2c_arm=on" >> ./boot/config.txt
fi

# enable wire-bus
if [ ${WIRE_BUS} == "true" ]; then
  echo "dtoverlay=w1-gpio" >> ./boot/config.txt
fi

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
  sed -i "s/#${L}/${L}/" ./root/etc/locale.gen
done

# Copy all configuration files into new system
cp --no-dereference --preserve=all --recursive ./fs/. ./root

# set timezone
ln --symbolic --force --relative ./root/usr/share/zoneinfo/Europe/Berlin ./root/etc/localtime

# enable wpa_supplicant service
ln --symbolic --force --relative ./root/usr/lib/systemd/system/wpa_supplicant@.service ./root/etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service

# configure SSH daemon
sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" ./root/etc/ssh/sshd_config
sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin without-password/" ./root/etc/ssh/sshd_config
sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" ./root/etc/ssh/sshd_config

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
export GIT_PS1_SHOWDIRTYSTATE=" "                                         # Enable, if git shows in prompt staged (+) or unstaged(*) states
export GIT_PS1_SHOWSTASHSTATE=" "                                         # Enable, if git shows in prompt stashed ($) states
export GIT_PS1_SHOWUNTRACKEDFILES=" "                                     # Enable, if git shows in prompt untracked (%) states
export GIT_PS1_SHOWUPSTREAM=" "                                           # Enable, if git shows in prompt behind(<), ahead(>) or diverges(<>) from upstream
export PS1='\u@\h:\w\$ '                                                  # Bash prompt with git
export VISUAL="vim"                                                       # default editor (full-screen)

# General Aliases
alias ..='cd ..'
alias ...='cd ../..'
alias cps='cp --sparse=never'                                             # copy paste files without sparse
alias duha='du -h --apparent-size'                                        # Show real file size (sparse size)
alias ghistory='history | grep'                                           # Shortcut to grep in history
alias gpg-dane='gpg --auto-key-locate dane --trust-model always -ear'     # This is for a pipe to encrypt a file
alias ipt='sudo iptables -L -n -v --line-numbers'                         # Show all iptable rules
alias ports='ss -atun'                                                    # List all open ports from localhost

# Aliases for pacman
alias iap='pacman --query --info'                                         # Pacman: Information-About-Package
alias lao='pacman --query --deps --unrequired'                            # Pacman: List-All-Orphans
alias uap='pacman --sync --refresh --sysupgrade'                          # Pacman: Update-All-Packages
alias uld='pacman --sync --refresh'                                       # Pacman: Update-Local-Database
alias rao='pacman --remove --nosave --recursive \
           $(pacman --query --unrequired --deps --quiet) '                # Pacman: Remove-All-Orphans Packages
alias rsp='pacman --remove --recursive --nosave'                          # Pacman: Remove-Single-Package
EOF

# create XDG-Specificantion-Based Directories
mkdir -p ./root/root/.cache/less \
         ./root/root/.config \
         ./root/root/.config/gnupg \
         ./root/root/.config/less \
         ./root/root/.local/share \
         ./root/root/.local/share/bash


# set permissions for gnupg homedir
chmod 700 ./root/root/.config/gnupg
chown root:root ./root/root/.config/gnupg

# download gpg public keys
gpg --homedir ./root/root/.config/gnupg --auto-key-locate dane --verbose --locate-key markus.pesch@cryptic.systems

# checkout after installation scripts
mkdir ./root/root/workspace
git clone https://github.com/volker-raschek/pi-installer.git ./root/root/workspace/pi-installer

# kill gpg-agent and dirmngr
kill $(ps aux | grep dirmngr | awk '{print $2}')
sudo kill $(ps aux | grep gpg-agent | awk '{print $2}')

# umount partitions and remove old files
umount ${BOOT} ${ROOT}
rm -Rf ./boot ./root ${TARBALL} ${TARBALL_SIG}
