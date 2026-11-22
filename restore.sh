#!/bin/bash
# Applies this repo to the current computer: plugins, config, toggles, theme
# and background. Everything it replaces is first copied to *.bak.<timestamp>;
# nothing is deleted.
set -euo pipefail
cd "$(dirname "$0")"

stamp=$(date +%s)
state="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
plugins_dir="$HOME/.config/omarchy/plugins"

backup() {
  [[ -e $1 ]] && cp -a "$1" "$1.bak.$stamp"
  return 0
}

echo "→ Plugins"
mkdir -p "$plugins_dir"
for dir in plugins/*/; do
  name=$(basename "$dir")
  backup "$plugins_dir/$name"
  mkdir -p "$plugins_dir/$name"
  rsync -a "$dir" "$plugins_dir/$name/"
done

# Superwhisper ships its bar plugin with the app; link it when the app is here.
if [[ -d /opt/superwhisper/assets/omarchy-plugin/superwhisper-panel && ! -e $plugins_dir/superwhisper-panel ]]; then
  ln -s /opt/superwhisper/assets/omarchy-plugin/superwhisper-panel "$plugins_dir/superwhisper-panel"
fi

echo "→ Config"
source ./files.sh
for f in "${config_files[@]}"; do
  backup "$HOME/.config/$f"
  mkdir -p "$(dirname "$HOME/.config/$f")"
  cp "config/$f" "$HOME/.config/$f"
done

echo "→ Toggles"
backup "$state/toggles"
mkdir -p "$state/toggles"
# Mirror the saved toggles exactly (a toggle turned off here is removed there
# too); the previous folder is in the backup above.
rsync -a --delete state/toggles/ "$state/toggles/"

if [[ -f state/settings/weather.json ]]; then
  echo "→ Weather location"
  backup "$state/settings/weather.json"
  mkdir -p "$state/settings"
  cp state/settings/weather.json "$state/settings/weather.json"
fi

hyprctl reload >/dev/null 2>&1 || true

echo "→ Theme"
theme=$(tr '[:upper:] ' '[:lower:]-' < state/theme)
omarchy theme set "$theme" || echo "  No pude aplicar el tema '$theme'."
background="$state/current/theme/backgrounds/$(cat state/background)"
if [[ -f $background ]]; then
  omarchy theme bg set "$background" || true
fi

echo "→ Shell"
omarchy restart shell

if ! command -v cava >/dev/null; then
  echo
  echo "Falta cava para que el aura reaccione a la música: omarchy pkg add cava"
fi
echo
echo "Listo. Lo que había antes quedó en archivos *.bak.$stamp."
