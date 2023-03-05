# Arch Linux ARM USB Boot on Raspberry Pi 4B

## Index

1. [Requirements](#requirements)
2. [Flash latest EEPROM](#flash-latest-eeprom)
3. [Change Raspberry Boot Order](#change-raspberry-boot-order)
4. [Install Arch Linux on USB device](#install-arch-linux-on-usb-device)
   1. [Format USB device](#format-usb-device)
   2. [(Optional) Migrate to hybrid MBR with GPT](#optional-migrate-to-hybrid-mbr-with-gpt)
   3. [Create Filesystem and copy files](#create-filesystem-and-copy-files)
   4. [Update USB Boot Partitions](#update-usb-boot-partitions)
5. [Final Configurations](#final-configurations)
6. [Resources](#resources)

## Requirements

- Raspberry Pi 4B
- SD card with RaspbianOS
- USB device intended to use as boot device

## Flash latest EEPROM

After booting the raspberry with the sd card, update the system:

```shell
sudo apt update
sudo apt full-upgrade
```

Then we can update the latest firmware:

```shell
sudo rpi-eeprom-update -d -a
```

Restart to apply the changes.

## Change Raspberry Boot Order

After the first reboot run:

```shell
sudo raspi-config
```

Then choose `Advanced Options -> Boot Order -> USB Boot`.

Restart to apply the changes.

## Install Arch Linux on USB device

### Format USB Device

After the second reboot, follow the following instructions to install Arch Linux
according to the Arch Linux
[Documentation](https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-4):

Replace `sdX` in the following instructions with the device name for the USB
device as it appears on your computer.

Start `fdisk` to partition the SD card:

```shell
fdisk /dev/sdX
```

At the `fdisk` prompt, delete old partitions and create a new one:

1. Type `o`. This will clear out any partitions on the drive.
2. Type `p` to list partitions. There should be no partitions left.
3. Type `n`, then `p` for primary, `1` for the first partition on the drive,
   press `ENTER` to accept the default first sector, then type `+200M` for the
   last sector.
4. Type `t`, then `c` to set the first partition to type `W95 FAT32 (LBA)`.
5. Type `n`, then `p` for primary, `2` for the second partition on the drive,
   and then press `ENTER` twice to accept the default first and last sector.
6. Write the partition table and exit by typing `w`.

### (Optional) Migrate to hybrid MBR with GPT

**Note:** This step is not necessary for most USB devices. Use this if your
device has more than 2TB of capacity and you need to have a partition with more
than 2TB of space.

At the `gdisk` prompt, enter recovery mode to create hybrid MBR:

1. Type `r` to use recovery options.
2. Type `h` to make hybrid MBR.
3. Type `1` to select the first partition.
4. Type `n` to not format the first partition to EFI.
5. Type `n` to not set bootable flag.
6. Type `n` to not protect any other partition.
7. Type `w` to write changes.
8. Type `y` to confirm changes and exit.

At the `gdisk` prompt, recreate the second partition:

1. Type `d` to delete a partition.
2. Type `2` to select the second parition.
3. Type `n` to add a new partition.
4. Type `ENTER` to select the default partition number.
5. Type `ENTER` to select the default first sector.
6. Type `ENTER` to select the default last sector.
7. Type `ENTER` to select the default partition type (Linux Filesystem).
8. Type `w` to write changes.
9. Type `y` to confirm changes and exit.

### Create Filesystem and copy files

Create and mount the FAT filesystem:

```shell
mkfs.vfat /dev/sdX1
mkdir boot
mount /dev/sdX1 boot
```

Create and mount the ext4 filesystem:

```shell
mkfs.ext4 /dev/sdX2
mkdir root
mount /dev/sdX2 root
```

Download and extract the root filesystem (as root, not via sudo):

```shell
wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-4-latest.tar.gz
bsdtar -xpf ArchLinuxARM-rpi-4-latest.tar.gz -C root
sync
```

Move boot files to the first partition:

```shell
mv root/boot/* boot
```

## Update USB Boot Partitions

### fstab

First, adjust the `fstab` of the new system by replacing the defined system with
the USB system:

```shell
sudo vim root/etc/fstab
```

Change the device `/dev/mmcblk1p1` to your boot device `/dev/sdX1`.

### cmdline.txt

Then we need to set the new root device to be used:

```shell
sudo vim boot/cmdline.txt
```

Set the `root` parameter to your root device `/dev/sdX2`.

### Add initramfs module pcie_brcmstb

Depending on the USB device requires initramfs additionally the module
`pcie_brcmstb`. This is noticeable by EEPROM not being able to find the
firmware. An error message similar to the following appears: `Firmware not
found`.

https://archlinuxarm.org/forum/viewtopic.php?f=67&t=14756

Adding the initramfs module `pcie_brcmstb`.

```shell
sed --in-place --regexp-extended 's/^MODULES=\(\)/MODULES=(pcie_brcmstb)/' ./root/etc/mkinitcpio.conf
```

Generate new initramfs for all defined linus kernels:

```shell
mkinitcpio -P
```

### Unmount

Unmount the two partitions:

```shell
umount boot root
```

You can now boot from the newly created USB device without the need for the SD
card.

## Final Configurations

Connect the USB device into the Raspberry Pi, connect ethernet, and apply 5V
power. Use the serial console or SSH to the IP address given to the board by
your router. Login as the default user `alarm` with the password `alarm`. The
default `root` password is `root`.

Initialize the pacman keyring and populate the Arch Linux ARM package signing keys:

```shell
pacman-key --init
pacman-key --populate archlinuxarm
```

## Resources

1. How To Set Up a Raspberry Pi 4 with Archlinux 64-bit (AArch64) and Full Disk
   Encryption (+SSH unlock), USB Boot (No SD-Card) and btrfs:
   [Documentation](https://gist.github.com/XSystem252/d274cd0af836a72ff42d590d59647928)
2. Setting up a SSH Server:
   [Documentation](https://www.raspberrypi.org/documentation/computers/remote-access.html#setting-up-a-ssh-server)
3. Running Raspbian from USB Devices : Made Easy
   [Documentation](https://www.raspberrypi.org/forums/viewtopic.php?f=29&t=196778)
