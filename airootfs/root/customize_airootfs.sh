#!/bin/bash

set -e -u

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
echo LANG="en_US.UTF-8" >> /etc/locale.conf
locale-gen
hwclock --systohc --utc

ln -sf /usr/share/zoneinfo/US/Eastern /etc/localtime

usermod -s /usr/bin/bash root
cp -aT /etc/skel/ /root/
useradd -m -p "" -g users -G "adm,audio,floppy,log,network,rfkill,scanner,storage,optical,power,wheel" -s /bin/bash jeremy
#chmod 700 /root

#mkdir --parents /home/jeremy/builds/ttf-font-awesome
#mkdir --parents /home/jeremy/builds/i3blocks
#git clone https://aur.archlinux.org/ttf-font-awesome /home/jeremy/builds/ttf-font-awesome
#git clone https://aur.archlinux.org/i3blocks /home/jeremy/builds/i3blocks

chown -R jeremy:users /home/jeremy

sed -i 's/#\(PermitRootLogin \).\+/\1yes/' /etc/ssh/sshd_config
sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist
sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf

sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

sed -i '0,/GRUB_CMDLINE_LINUX=""/s//GRUB_CMDLINE_LINUX="lvm resume=\/dev\/mapper\/vgrp-swap root=\/dev\/mapper\/vgrp-root"/' /etc/default/grub

#echo "vboxguest" >> /etc/modules-load.d/virtualbox.conf
#echo "vboxsf" >> /etc/modules-load.d/virtualbox.conf
#echo "vboxvideo" >> /etc/modules-load.d/virtualbox.conf

systemctl enable pacman-init.service choose-mirror.service
systemctl set-default multi-user.target
