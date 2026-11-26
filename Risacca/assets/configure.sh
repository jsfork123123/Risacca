#!/bin/sh
set -eu
media=/media/risacca
offline_pkg() { "$media/pkg-static" -R "$media/config" "$@"; }
offline_pkg update -f
offline_pkg install -U -y -r Risacca pkg
set -- $(cat "$media/packages.txt")
offline_pkg install -U -y -r Risacca "$@"
sysrc dbus_enable=YES lightdm_enable=YES devmatch_enable=YES hcsecd_enable=YES
sysrc -f /boot/loader.conf ng_ubt_load=YES
if ! grep -Eq '^[^#[:space:]]+[[:space:]]+/proc[[:space:]]+procfs' /etc/fstab; then
    printf 'proc\t/proc\tprocfs\trw\t0\t0\n' >> /etc/fstab
fi
mkdir -p /proc
pw usershow -a | awk -F: '$3 >= 1000 && $3 < 65534 && $7 !~ /nologin$/ {print $1}' |
    while read -r name; do pw groupmod video -m "$name"; done

base=/usr/local
xdg=$base/etc/xdg
channels=$xdg/xfce4/xfconf/xfce-perchannel-xml
install -d "$channels" "$xdg/xfce4/panel" "$xdg/autostart" "$base/share/risacca" "$base/share/applications"
install -m 444 "$media/assets/panel.xml" "$xdg/xfce4/panel/default.xml"
install -m 444 "$media/assets/panel.xml" "$channels/xfce4-panel.xml"
install -m 444 "$media/assets/xsettings.xml" "$channels/xsettings.xml"
install -m 444 "$media/assets/marea.svg" "$base/share/risacca/"
install -m 555 "$media/assets/wallpaper.sh" "$base/share/risacca/"
install -m 444 "$media/assets/risacca-wallpaper.desktop" "$xdg/autostart/"
install -m 444 "$media/assets"/app-*.desktop "$base/share/applications/"
install -d "$base/etc/lightdm/lightdm.conf.d"
printf '%s\n' '[Seat:*]' 'greeter-session=lightdm-gtk-greeter' 'user-session=xfce' > "$base/etc/lightdm/lightdm.conf.d/60-risacca.conf"
install -m 444 "$media/pacchetti.txt" "$base/share/risacca/"
echo 'Desktop Risacca installato.'
