#!/bin/sh
set -eu
target=${1:?Volume di destinazione mancante}
[ "$target" != / ] && [ -x "$target/bin/sh" ] || exit 1
mkdir -p "$target/media/risacca"
mount -t nullfs -o ro /risacca "$target/media/risacca"
trap 'umount "$target/media/risacca"' EXIT
chroot "$target" /bin/sh /media/risacca/assets/configure.sh
