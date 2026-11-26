#!/bin/sh
# Set the initial image once. Later choices belong to the desktop user.
state=${XDG_CONFIG_HOME:-"$HOME/.config"}/risacca
[ ! -f "$state/wallpaper-set" ] || exit 0
image=/usr/local/share/risacca/marea.svg
tries=0
while [ "$tries" -lt 20 ]; do
    pgrep -x -U "$(id -u)" xfdesktop >/dev/null && break
    tries=$((tries + 1))
    sleep 1
done
props=$(xfconf-query -c xfce4-desktop -l 2>/dev/null | awk '/^\/backdrop\/.*\/last-image$/')
if [ -z "$props" ]; then
    props=$(xrandr --query | awk '$2 == "connected" {print "/backdrop/screen0/monitor"$1"/workspace0/last-image"}')
fi
[ -n "$props" ] || exit 0
printf '%s\n' "$props" | while IFS= read -r prop; do
    xfconf-query -c xfce4-desktop -p "$prop" -s "$image" 2>/dev/null ||
        xfconf-query -c xfce4-desktop -p "$prop" -n -t string -s "$image" || exit 1
done || exit 1
mkdir -p "$state" && touch "$state/wallpaper-set"
