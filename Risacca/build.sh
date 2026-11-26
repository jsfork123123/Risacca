#!/bin/sh
set -eu

fail() { echo "$*" >&2; exit 1; }
[ "$(uname -s)-$(uname -m)" = FreeBSD-amd64 ] || fail 'Serve FreeBSD 15.1-RELEASE amd64.'
case "$(freebsd-version -u)" in 15.1-RELEASE*) ;; *) fail 'Versione utente FreeBSD non compatibile.' ;; esac
case "$(uname -r)" in 15.1-RELEASE*) ;; *) fail 'Avviare il kernel FreeBSD 15.1-RELEASE.' ;; esac
[ "$(id -u)" -eq 0 ] || fail 'Eseguire come root in una macchina di build FreeBSD.'
for tool in git pkg-static makefs mkimg etdump; do
    command -v "$tool" >/dev/null || fail "Manca il comando $tool (vedi LEGGIMI.md)."
done
project=$(dirname "$(realpath "$0")")
cd "$project"
mkdir -p out cache
iso="$project/out/Risacca-15.1-amd64.iso"
[ ! -e "$iso" ] || fail "Esiste già $iso. Spostare il risultato prima di ripetere la build."
stage=$(mktemp -d "$project/cache/build.XXXXXX")
# The upstream release tools split some paths on whitespace.
case "$stage" in *[[:space:]]*) fail 'Usare un percorso senza spazi.' ;; esac
tree=$stage/tree
media=$tree/risacca
mkdir -p "$tree"
base=FreeBSD-15.1-RELEASE-amd64-dvd1.iso
digest=027504262c65e096d78bd345d74905a8a7216bbb3c6155d55634ae8328f76c5d
if [ ! -f "cache/$base" ]; then
    fetch -o "$stage/base.download" "https://download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/15.1/$base"
    [ "$(sha256 -q "$stage/base.download")" = "$digest" ] || fail 'Checksum DVD non valido.'
    mv "$stage/base.download" "cache/$base"
fi
[ "$(sha256 -q "cache/$base")" = "$digest" ] || fail 'Il DVD in cache ha un checksum diverso da quello ufficiale.'

tag=release/15.1.0
git clone --depth 1 --filter=blob:none --sparse --branch "$tag" \
    https://github.com/freebsd/freebsd-src.git "$stage/src"
git -C "$stage/src" sparse-checkout set release tools/boot
[ "$(git -C "$stage/src" rev-parse "refs/tags/$tag")" = 017261f1aac302491c7789bbd19c95e222d7faee ] || fail 'Il tag Git non corrisponde alla release prevista.'
tar -C "$tree" -xpf "$project/cache/$base"
[ -s "$tree/boot/cdboot" ] && [ -s "$tree/boot/loader.efi" ] || fail 'File di avvio mancanti.'
auto="$tree/usr/libexec/bsdinstall/auto"
hook="$tree/usr/libexec/bsdinstall/local.post-configure"
[ ! -e "$hook" ] || fail 'Il DVD ha già un hook locale.'
grep -Eq '^[[:space:]]*\[.*local\.post-configure.*&& sh .*local\.post-configure' "$auto" || fail 'Hook installatore non riconosciuto.'
# bsdinstall normally ignores failures in this optional hook. Surface them
# through the same error handler it uses for the base installation.
sed -i '' '/&& sh .*local\.post-configure/s/$/ || error "Installazione desktop Risacca fallita"/' "$auto"
install -m 555 install-desktop.sh "$hook"
mkdir -p "$media/repo" "$media/config"
cp -R assets "$media/"
install -m 444 packages.txt "$media/packages.txt"
install -m 555 "$(command -v pkg-static)" "$media/pkg-static"
git -C "$stage/src" rev-parse HEAD > "$media/freebsd-src.commit"
echo 'Risacca: preparazione del catalogo offline e delle dipendenze.'
pkg-static update -f
xargs pkg-static fetch -U -y -d -o "$media/repo" < packages.txt
pkg-static repo "$media/repo"
# Resolve the complete installation against the new catalogue and an empty
# package database before spending time generating the image.
mkdir -p "$stage/check-db" "$stage/check-repos"
echo "Risacca: { url: \"file://$media/repo\", enabled: yes }" > "$stage/check-repos/risacca.conf"
check_pkg() { pkg-static -o PKG_DBDIR="$stage/check-db" -R "$stage/check-repos" "$@"; }
check_pkg update -f
set -- $(cat packages.txt)
check_pkg install -n -U -r Risacca "$@"
check_pkg rquery -r Risacca '%n-%v' | sort > "$media/pacchetti.txt"
echo 'Risacca: { url: "file:///media/risacca/repo", enabled: yes }' > "$media/config/risacca.conf"
image="$stage/Risacca.iso"
# Keep the official media label used by the DVD installer and its package repo.
label=$(awk '$2 == "/" && $1 ~ /^\/dev\/iso9660\// { sub(".*/","",$1); print $1; exit }' "$tree/etc/fstab")
[ -n "$label" ] || fail 'Etichetta del DVD mancante.'
sh "$stage/src/release/amd64/mkisoimages.sh" -b "$label" "$image" "$tree"
[ "$(stat -f %z "$image")" -ge 5000000000 ] || fail 'ISO sotto 5 GB.'
etdump --format shell "$image" > "$stage/boot-catalog.txt"
grep -Eq 'et_platform=.?efi' "$stage/boot-catalog.txt" || fail 'Voce di avvio EFI mancante.'
grep -Eq 'et_platform=.?default' "$stage/boot-catalog.txt" || fail 'Voce di avvio BIOS mancante.'
tar -tf "$image" > "$stage/contenuto.txt"
grep -Eq '(^|/)risacca/pacchetti.txt$' "$stage/contenuto.txt" || fail 'Catalogo pacchetti mancante.'
mv "$image" "$iso"
(cd out && sha256 Risacca-15.1-amd64.iso > Risacca-15.1-amd64.iso.sha256)
echo "ISO: $iso ($(stat -f %z "$iso") byte)"
echo "File intermedi e inventario: $stage"
