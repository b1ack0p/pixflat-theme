# pixflat-theme
RaspberryPiOS PiXflat GTK Theme for LXDE/Xfce/GNOME

- Run ```sudo gtk-update-icon-cache /usr/share/icons/PiXflat``` to refresh system for icon theme changes.

- you may need this also ```sudo apt install gtk2-engines```


#LightDM user image on logon screen:
- uncomment ```Hide user greeter image = false``` in ```/etc/lightdm/lightdm.conf```
- install ```sudo apt install lightdm-gtk-greeter-settings```
- in LightDM GTK Greeter Settings app choose desired user-greeter image (image should be in directory where system can reach, not in ```/home/$user directory```)


#Same background on LightDM greeter screen with desktop wallpaper:
- install ```sudo apt install accountsservice```
- copy wallpapers you wish to use to ```/usr/share/backgrounds/```
- select ```Use user wallpaper if available``` in LightDM GTK Greeter Settings app

#Original files:
- Non-modified PiXflat theme can be found in: http://archive.raspberrypi.org/debian/pool/main/p/pixflat-theme/
- Non-modified PiX theme can be found in: http://archive.raspberrypi.org/debian/pool/main/p/pix-theme/
- Non-modified PiXflat icons: http://archive.raspberrypi.org/debian/pool/main/p/pixflat-icons/
- Non-modified PiX icons: http://archive.raspberrypi.org/debian/pool/main/r/rpd-icons/
- Piboto font : https://archive.raspberrypi.org/debian/pool/main/f/fonts-piboto/
- Gnome icon theme (3.12.0-3): https://packages.debian.org/bullseye/all/gnome-icon-theme/download
- gtk2-engines-pixflat: http://archive.raspberrypi.org/debian/pool/main/g/gtk2-engines-pixflat/
- gtk2-engines-clearlookspix: http://archive.raspberrypi.org/debian/pool/main/g/gtk2-engines-clearlookspix/
- gtk2-engines-pixbuf: http://archive.raspberrypi.org/debian/pool/main/g/gtk+2.0/
- default wallpapers: https://archive.raspberrypi.org/debian/pool/main/r/rpd-wallpaper/
- default wallpapers (4k): https://archive.raspberrypi.org/debian/pool/main/r/rpd-wallpaper-4k/
- Mowi-24 xfwm4 theme: https://www.xfce-look.org/p/1700122/
