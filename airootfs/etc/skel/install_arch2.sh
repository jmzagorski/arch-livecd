#! /bin/bash

install_arch() {
  genfstab -U -p /mnt >> /mnt/etc/fstab
  # make journal available since it will be in RAM
  sed -i 's/Storage=volatile/#Storage=auto/' /etc/systemd/journald.conf
  # Disable and remove the services created by archiso
  systemctl disable pacman-init.service choose-mirror.service
  rm -r /etc/systemd/system/{choose-mirror.service,pacman-init.service,etc-pacman.d-gnupg.mount,getty@tty1.service.d}
  rm /etc/systemd/scripts/choose-mirror
  # Remove special scripts of the Live environment
  rm /etc/systemd/system/getty@tty1.service.d/autologin.conf
  rm /root/{.automated_script.sh,.zlogin}
  rm /etc/mkinitcpio-archiso.conf
  rm -r /etc/initcpio
  # Importing archlinux keys, ususally done by pacstrap
  pacman-key --init
  pacman-key --populate archlinux
}

configure() {
  echo "Configuring grub"
  sed -i 's/^HOOKS=\(.*\)block/\0 lvm2 resume/' /etc/mkinitcpio.conf
  mkinitcpio -p linux
  grub-install /dev/sda
  grub-mkconfig -o /boot/grub/grub.cfg
}

install_arch
configure
