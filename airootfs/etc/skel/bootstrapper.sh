#!/bin/bash

set -e
command -v whiptail >/dev/null 2>&1 || { echo "whiptail required for this script" >&2 ; exit 1 ; }

################################################################################
# Dialog function
################################################################################
bootstrapper_dialog() {
  DIALOG_RESULT=$(whiptail --clear --backtitle "Arch bootstrapper" "$@" 3>&1 1>&2 2>&3)
  DIALOG_CODE=$?
}

################################################################################
# Welcome
################################################################################
clear
bootstrapper_dialog --title "Welcome" --msgbox "\nWelcome to Jeremy's Arch Linux bootstrapper." 10 60

################################################################################
# UEFI / BIOS detection
################################################################################
efivar -l >/dev/null 2>&1

if [[ $? -eq 0 ]]; then
  UEFI_BIOS_text="UEFI detected."
  UEFI_radio="on"
  BIOS_radio="off"
else
  UEFI_BIOS_text="BIOS detected."
  UEFI_radio="off"
  BIOS_radio="on"
fi

bootstrapper_dialog --title "UEFI or BIOS" --radiolist "${UEFI_BIOS_text}\nPress <Enter> to accept." 10 40 2 1 UEFI "$UEFI_radio" 2 BIOS "$BIOS_radio"
[[ $DIALOG_RESULT -eq 1 ]] && UEFI=1 || UEFI=0

################################################################################
# Prompts
################################################################################
bootstrapper_dialog --title "Hostname" --inputbox "\nPlease enter a name for this host.\n" 10 60
hostname="$DIALOG_RESULT"

################################################################################
# Password prompts
################################################################################
bootstrapper_dialog --title "Disk encryption" --passwordbox "\nEnternter a strong passphrase for the disk encryption.\nLeave blank if you don't want encryption.\n" 10 60
encryption_passphrase="$DIALOG_RESULT"

bootstrapper_dialog --title "Root password" --passwordbox "\nEnter a strong password for the root user.\n" 10 60
root_password="$DIALOG_RESULT"

################################################################################
# Warning
################################################################################
bootstrapper_dialog --title "WARNING" --yesno "\nThis script will NUKE /dev/sda from orbit.\nPress <Enter> to continue or <Esc> to cancel.\n" 10 60
clear
if [[ $DIALOG_CODE -eq 1 ]]; then
  bootstrapper_dialog --title "Cancelled" --msgbox "\nScript was cancelled at your request." 10 60
  exit 0
fi

bootstrapper_dialog --title "Full or Quick Wipe" --radiolist "Quick Zap or Full Shred?\nPress <Enter> to accept." 10 40 2 1 FULLWIPE "Full" 2 QUICKWIPE "Quick"
[[ $DIALOG_RESULT -eq 1 ]] && FULLWIPE=1 || FULLWIPE=0

################################################################################
# Reset the screen Nuke and set up disk partitions
################################################################################
if [[ $FULLWIPE -eq 1 ]]; then
  bootstrapper_dialog --title "Full Wipe Iterations" --inputbox "\nPlease the number of iterations.\n" 10 60
  iterations="$DIALOG_RESULT"
  reset
  shred --verbose --random-source=/dev/urandom --iterations=$iterations /dev/sda
else
  reset
  echo "Zapping disk"
  sgdisk --zap-all /dev/sda
  [[ $UEFI -eq 0 ]] && printf "r\ng\nw\ny\n" | gdisk /dev/sda
fi

# Hope the kernel can read the new partition table. Partprobe usually fails...
blockdev --rereadpt /dev/sda

echo "Creating /dev/sda1"
if [[ $UEFI -eq 1 ]]; then
  printf "n\n1\n\n+1G\nef00\nw\ny\n" | gdisk /dev/sda
  yes | mkfs.fat -F32 /dev/sda1
else
  printf "n\np\n1\n\n+200M\nw\n" | fdisk /dev/sda
  mkfs.ext4 /dev/sda1
fi

echo "Creating /dev/sda2"
if [[ $UEFI -eq 1 ]]; then
  printf "n\n2\n\n\n8e00\nw\ny\n"| gdisk /dev/sda
else
  printf "n\np\n2\n\n\nt\n2\n8e\nw\n" | fdisk /dev/sda
fi

if [[ ! -z $encryption_passphrase ]]; then
  echo "Setting up encryption"
  printf "%s" "$encryption_passphrase" | cryptsetup luksFormat /dev/sda2 -
  printf "%s" "$encryption_passphrase" | cryptsetup open --type luks /dev/sda2 lvm -
  cryptdevice_boot_param="cryptdevice=/dev/sda2:vg1 "
  encrypt_mkinitcpio_hook="encrypt "
  physical_volume="/dev/mapper/lvm"
else
  physical_volume="/dev/sda2"
fi

echo "Setting up LVM"
pvcreate --force $physical_volume
vgcreate vg1 $physical_volume
lvcreate -L 20G vg1 -n lvroot
lvcreate -L 4G -n swap vg1
lvcreate -l +100%FREE vg1 -n lvhome


echo "Creating ext4 file systems on top of logical volumes"
mkfs.ext4 /dev/mapper/vg1-lvroot
mkfs.ext4 /dev/mapper/vg1-lvhome

mkswap /dev/mapper/vg1-swap
swapon /dev/mapper/vg1-swap

################################################################################
# Install Arch
################################################################################
mount /dev/vg1/lvroot /mnt
mkdir /mnt/{boot,home}
mount /dev/sda1 /mnt/boot
mount /dev/vg1/lvhome /mnt/home

echo "Copying files from live cd"
time cp -ax / /mnt
cp -vaT /run/archiso/bootmnt/arch/boot/"$(uname -m)"/vmlinuz /mnt/boot/vmlinuz-linux

genfstab -U -p /mnt >> /mnt/etc/fstab
# Importing archlinux keys, ususally done by pacstrap
pacman-key --init
pacman-key --populate archlinux
# make journal available since it will be in RAM - TODO should be configurable
# in options
sed -i 's/Storage=volatile/#Storage=auto/' /etc/systemd/journald.conf
# Disable and remove the services created by archiso
systemctl disable pacman-init.service choose-mirror.service

################################################################################
# Configure base system
################################################################################
arch-chroot /mnt /bin/bash <<EOF
echo "Setting hostname"
echo $hostname > /etc/hostname
sed -i '/localhost/s/$'"/ $hostname/" /etc/hosts
echo "Generating initramfs"
sed -i "s/^HOOKS.*/HOOKS=\"base udev autodetect modconf block keyboard ${encrypt_mkinitcpio_hook}lvm2 filesystems fsck\"/" /etc/mkinitcpio.conf
mkinitcpio -p linux
echo "Setting root password"
echo "root:${root_password}" | chpasswd
EOF

################################################################################
# Install boot loader
################################################################################
if [[ $UEFI -eq 1 ]]; then
arch-chroot /mnt /bin/bash <<EOF
echo "Installing Gummiboot boot loader"
pacman --noconfirm -S gummiboot
gummiboot install
cat << GRUB > /boot/loader/entries/arch.conf
title          Arch Linux
linux          /vmlinuz-linux
initrd         /initramfs-linux.img
options        ${cryptdevice_boot_param}root=/dev/mapper/vg1-lvroot rw
GRUB
EOF
else
arch-chroot /mnt /bin/bash <<EOF
  echo "Installing Grub boot loader"
  grub-install --recheck /dev/sda
  sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT.*|GRUB_CMDLINE_LINUX_DEFAULT=\"quiet ${cryptdevice_boot_param}root=/dev/mapper/vg1-lvroot\"|" /etc/default/grub
  grub-mkconfig -o /boot/grub/grub.cfg
  # cleanup
  rm -r /etc/systemd/system/{choose-mirror.service,pacman-init.service,etc-pacman.d-gnupg.mount,getty@tty1.service.d}
  rm /etc/systemd/scripts/choose-mirror
  # Remove special scripts of the Live environment
  rm /root/{.automated_script.sh,.zlogin}
  rm /etc/mkinitcpio-archiso.conf
  rm -r /etc/initcpio
EOF
fi


################################################################################
# End
################################################################################
printf "The script has completed bootstrapping Arch Linux.\n\nTake a minute to scroll up and check for errors (using shift+pgup).\nIf it looks good you can reboot.\n"
