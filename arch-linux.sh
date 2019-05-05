#!/bin/bash

set -e

# Device, define device for the new arch installation
DEVICE=/dev/sdb

# boot and root partitions
BOOT="${DEVICE}1"
ROOT="${DEVICE}2"

PI_HOSTNAME="dummy"
PI_FQDN="dummy.trier.cryptic.systems"

# Arch Linux Image
TARBALL=ArchLinuxARM-rpi-latest.tar.gz
TARBALL_SIG="${TARBALL}.sig"
TARBALL_SOURCE=http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz
# TARBALL_SOURCE=http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-3-latest.tar.gz
TARBALL_SOURCE_SIG="${TARBALL_SOURCE}.sig"
TARBALL_SIG_KEY="68B3537F39A313B3E574D06777193F152BDBE6A6"

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

# delete partitions on sd-card
for p in $(parted --script $DEVICE print | awk '/^ / {print $1}'); do
  parted --script $DEVICE rm $p
done

# partitioning sd-card
parted --script $DEVICE mkpart primary fat32 1MiB 100MiB
parted --script $DEVICE mkpart primary ext4 100Mib 100%

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
sync

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
UUID=${BOOT_UUID}                              /boot       vfat    defaults        0       0
EOF

# enable 1-wire interface
# cat >> ./boot/config.txt <<EOF
# dtoverlay=w1-gpio
# EOF

# install ssh pub key
mkdir ./root/root/.ssh -p
cat > ./root/root/.ssh/authorized_keys <<EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPOydCxv9/tAV7AdS2HsUIEu547Z5qUJnWYwiO7rI9YL
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJUTcUBb+55jRY9TkpLgm8K/8nJfEXyjEX8zljdCCRpi
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVGxeVfkycwzP7UkLujGzDjC+9lPML45V7+bBmkKyD0
EOF

chown root:root -R ./root/root/.ssh/authorized_keys
chmod 640 ./root/root/.ssh/authorized_keys
chmod 750 ./root/root/.ssh

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
alias lss='smbtree -b -N'                                                 # List all samba shares as tree
alias ports='ss -atun'                                                    # List all open ports from localhost
alias pyg-json=''
alias network-scan='sudo nmap -sP'                                        # Scan all Hosts in a network, exp. 192.168.178.0/24
alias port-scan='sudo nmap -sS -O -v'                                     # Scan ports from a victim
alias wanip='dig +short myip.opendns.com @resolver1.opendns.com A'        # List your own IPv4 WAN Address

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
gpg --homedir ./root/root/.config/gnupg --recv-keys 9B146D11A9ED6CA7E279EB1A852BCC170D81A982

# checkout after installation scripts
mkdir ./root/root/workspace
git clone https://github.com/volker-raschek/pi-installer.git ./root/root/workspace/pi-installer

# kill gpg-agent and dirmngr
kill $(ps aux | grep dirmngr | awk '{print $2}')
sudo kill $(ps aux | grep gpg-agent | awk '{print $2}')

# umount partitions and remove old files
umount ${BOOT} ${ROOT}
rm -Rf ./boot ./root ${TARBALL} ${TARBALL_SIG}
