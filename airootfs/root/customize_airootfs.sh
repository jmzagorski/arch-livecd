#!/bin/bash

#admin tasks

set -e -u

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
echo LANG="en_US.UTF-8" >> /etc/locale.conf
locale-gen
hwclock --systohc --utc

ln -sf /usr/share/zoneinfo/US/Eastern /etc/localtime

usermod -s /usr/bin/bash root
cp -aT /etc/skel/ /root/

# TODO put in bootstrapper as configurable
# ignore all the key actions
sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

# virtual box tasks TODO separate to own file
#echo "vboxguest" >> /etc/modules-load.d/virtualbox.conf
#echo "vboxsf" >> /etc/modules-load.d/virtualbox.conf
#echo "vboxvideo" >> /etc/modules-load.d/virtualbox.conf

#none graphical login
systemctl set-default multi-user.target
