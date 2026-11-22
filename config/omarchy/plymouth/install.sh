#!/bin/bash
# Installs the two pieces that need root: the Catppuccin Mocha Dark cursor and
# the "bruno" boot screen (Plymouth). Run it in a terminal; it asks for sudo.
# Undo the boot screen with: omarchy plymouth set by theme ristretto
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

echo "→ Cursor Catppuccin Mocha Dark (AUR)"
yay -S --needed --noconfirm catppuccin-cursors-mocha

cursor=catppuccin-mocha-dark-cursors
gsettings set org.gnome.desktop.interface cursor-theme "$cursor" || true
mkdir -p "$HOME/.icons/default"
printf '[Icon Theme]\nInherits=%s\n' "$cursor" > "$HOME/.icons/default/index.theme"
hyprctl setcursor "$cursor" 24 >/dev/null || true

echo "→ Pantalla de arranque 'bruno'"
sudo install -d -o root -g root -m 0755 /usr/share/plymouth/themes/bruno
sudo install -o root -g root -m 0644 "$here"/bruno/* /usr/share/plymouth/themes/bruno/
sudo plymouth-set-default-theme bruno
if command -v limine-mkinitcpio >/dev/null; then
  sudo limine-mkinitcpio
else
  sudo mkinitcpio -P
fi

echo
echo "Listo. El cursor ya cambió; la pantalla de arranque la vas a ver al reiniciar."
