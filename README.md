# Arch Live CD

### Setup from an existing Arch System using archiso


1. Follow the setup step on https://wiki.archlinux.org/index.php/Archiso and copy the releng profile
    - `pacman -S archiso`
    - `cp -r /usr/share/archiso/configs/releng/ ~/archlive`
  
2. From https://wiki.archlinux.org/index.php/USB_flash_installation_media mount and write the ISO to a USB
    - `sudo mount /dev/sdX /mnt/usb`
    - `dd bs=4M if=path/to/archlinux.iso of=/dev/sdX status=progress oflag=sync`
  
3. Reboot your computer, selecting to boot from USB
    - `sudo reboot now`
    - Select USB as boot option
    
4. When welcome screen is shown select "Boot Arch Linux". 

5. Once you are in the console run `sh ./bootstrapper.sh` and go through the prompts
