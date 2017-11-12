#! /bin/bash

# PREREQUISTES FOR ARCHISO
# checklist for custom iso:
#    - @ least 20 GB of Free Space
#    - Only doing Arch Linux 64 bit only
#    - sudo pacmna -Scc # clear pacman cache
#    - configure every as root
#    - disable auto update
# sudo pacman -S archiso
# sudo mkdir /home/username/livecd
# sudo cp -r /usr/share/archiso/configs/releng/* /home/username/livecd
# cd livecd
# edit build.sh and remove i686 since this is only 64 bit, make other meta data changes
# edit packages.both. look at current apps with pacman -Q
# remove pxe from build.sh and mmkinitcpio, usually not needed
# copy of pacman.conf, make sure multilib is added for 64 bit
# if running live cd and want user logged in change
#   /airootfs/etc/systemd/system/getty@ttyt1.service.d/autologin.conf # change to user
# add customizations to customize_airootfs.sh (user, permission, change usermod)
#   change to: usermod -s /usr/bin/bash root
#   useradd -m -p "" -g users -G "adm,audio,floppy,log,network,rfkill,scanner,storage,optical,power,wheel" -s /bin/bash username
#   comment out chmod 700 /root
#   chown -R username:users /home/username
# add NetworkManager.service to first systemctl enable if desired
# sudo mkdir ~/livecd/airootfs/etc/skel # for any file transfers
# after install enable and start vboxservice.start for guest services
# after install enable and start systemd-netowrkd.service.start for guest services
# sudo mkdir airootfs/etc/sudoers.d # to prevent password on sudo
#  sudo vim airootfs/etc/sudoers.d/g_wheel
#  %wheel ALL=(ALL) NOPASSW: ALL

encrypt=
swap=
hostname=

_usage () {
  echo "usage ${0} [options]"
  echo
  echo " General options:"
  echo "    -s <swap_space>      Sets the swap space (e.g 2GB)"
  echo "    -o <host_name>     Set the host name"
  echo "    -e                 Enable encryption"
  echo "    -h                 This help message"
  exit ${1}
}

partition() {
  # o - clear the in memory partition table
  # n - new partition
  # p - primary partition
  # 1 - partition number 1
  # default - start at beginning of disk
  # 100MB boot partition
  # n new partition
  # p primary partition
  # partiton number 22
  # default, start immediatly after preceding partition
  # default, extend partition to end of disk
  # a make a partition bootable
  # bootable partition is partition 1 -- /dev/sda1
  # print the in-memory table
  # write the partition table
  # quit
  # thanks to http://superuser.com/questions/332252/creating-and-formating-a-partition-using-a-bash-script
  echo "Partioning disk into ext4 bootable and primary"
  timedatectl set-ntp true
  echo -e "o\nn\np\n1\n\n+100M\nn\np\n2\n\n\na\n1\np\nw\nq" | fdisk /dev/sda
  mkfs.ext4 /dev/sda1
}

encrypt() {
  echo "Encrypting"
  cryptsetup -y -v luksFormat /dev/sda2
  cryptsetup luksOpen /dev/sda2 lvm
}

make_lvm() {
  if [[ ${encrypt} ]]; then
    echo "Creating lvm on encrypted drive"
    pvcreate /dev/mapper/lvm
    vgcreate vgrp /dev/mapper/lvm
  else
    echo "Creating lvm"
    pvcreate /dev/sda2
    vgcreate vgrp /dev/sda2
  fi

  if [[ ${swap} ]]; then
    echo "Creating swap"
    lvcreate -L ${swap} -n swap vgrp
    mkswap /dev/mapper/vgrp-swap
    swapon /dev/mapper/vgrp-swap
  fi

  lvcreate -l 100%FREE -n root vgrp
  mkfs.ext4 /dev/mapper/vgrp-root
  mount /dev/mapper/vgrp-root /mnt

  mkdir /mnt/boot
  mount /dev/sda1 /mnt/boot
  echo "Copying files from live cd"
  # copy everything from live environment, usually do pacstrap for this
  time cp -ax / /mnt
  # copy kernal image
  cp -vaT /run/archiso/bootmnt/arch/boot/$(uname -m)/vmlinuz /mnt/boot/vmlinuz-linux
  arch-chroot /mnt /root/install_arch2.sh
}


#pacman -S grub-bios

# get partition 2 UUID for crypt
# uuid=lsblk -o UUID /dev/sda2 | head -n 2
# add lvm command to grub

# sed -i '0,/GRUB_CMDLINE_LINUX=""/s//GRUB_CMDLINE_LINUX="lvm resume=\/dev\/mapper\/vgrp-swap root=\/dev\/mapper\/vgrp-root"/' /etc/default/grub

# add hooks for lvm from prior grub config
# sed -i 's/^HOOKES=\(.*\)block/\0 lvm2 resume/' /etc/mkinitcpio.conf


#if [ -z "$2" ]; then
#  echo "Adding hostname"
#  echo "$2" > /etc/hostname
#  sed -i '$i 127.0.1.1	'"$2"'	localdomain' /etc/hosts
#else
#  echo "Missing hostname param. Skipping"
#fi

#echo "Setting US Eastern locales"
#sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/local.gen
#echo LANG="en_US.UTF-8" >> /etc/locale.conf
#local-gen
#ln -s /usr/share/zoneinfo/US/Eastern /etc/localtime
#hwclock --systohc --utc

unmount() {
  echo "Cleaning up..."
  umount /mnt/boot -R
  umount /mnt -R
}

while getopts 's:o:eh' arg; do
  case "${arg}" in
    s) swap="${OPTARG}" ;;
    o) hostname="${OPTARG}" ;;
    e) encrypt="${OPTARG}" ;;
    h) _usage 0 ;;
    *)
      echo "Invalid argument '${arg}'"
      _usage 1
      ;;
  esac
done

#if [[ ${EUID} -ne 0 ]]; then
#    echo "This script must be run as root."
#    _usage 1
#fi

#echo "Checking internet connection..."
#ping youtube.com -c 1 -W 5

#if [ "$?" -ne 0 ]; then
#  echo "You must be connected to internet to download arch"
#  _usage 1
#fi

partition

if [[ ${encrypt} ]]; then
  encrypt
fi

make_lvm
unmount
